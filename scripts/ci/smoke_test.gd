extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scenes/main.tscn", "res://scenes/fighter/fighter.tscn",
	"res://assets/characters/kael/kael_animated_sheet.svg",
	"res://assets/characters/nara/nara_animated_sheet.svg",
	"res://assets/characters/lyra/lyra_animated_sheet.svg",
	"res://assets/characters/rin/rin_animated_sheet.svg",
	"res://scripts/preparation/battle_loadout_catalog.gd",
	"res://scripts/preparation/battle_loadout_ledger.gd",
	"res://scripts/preparation/preparation_avatar_preview.gd",
	"res://scripts/runtime/battle_preparation_runtime.gd",
	"res://scripts/runtime/arena_entrance_runtime.gd",
	"res://scripts/visual/character_visual_catalog.gd",
	"res://scripts/visual/character_attachment_catalog.gd",
	"res://scripts/visual/technique_attachment_catalog.gd",
	"res://scripts/visual/technique_visual_timeline.gd",
	"res://scripts/visual/weapon_trail_runtime.gd",
	"res://scripts/visual/cosmetic_socket_catalog.gd",
	"res://scripts/visual/cosmetic_loadout_ledger.gd",
	"res://scripts/visual/cosmetic_socket_presenter.gd",
	"res://scripts/visual/fighter_expression_overlay.gd",
	"res://scripts/visual/fighter_outcome_runtime.gd",
	"res://scripts/visual/regional_hit_flash.gd",
	"res://scripts/visual/provisional_sprite_presenter.gd",
	"res://scripts/visual/fighter_visual_overlay.gd",
	"res://scripts/runtime/attachment_editor_runtime.gd",
	"res://scripts/runtime/cosmetic_loadout_runtime.gd",
	"res://scripts/runtime/match_outcome_runtime.gd",
	"res://scripts/runtime/asset_inspector_runtime.gd",
	"res://scripts/runtime/roster_hud_runtime.gd",
	"res://scripts/runtime/impact_director.gd",
	"res://scripts/fighter/mastered_weapon_fighter_controller.gd"
]

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(path):
			failures.append("Recurso ausente ou não importável: %s" % path)
	for character_id in CharacterVisualCatalog.character_ids():
		failures.append_array(CharacterVisualCatalog.validate_character(character_id))
	failures.append_array(CharacterAttachmentCatalog.validate())
	failures.append_array(TechniqueAttachmentCatalog.validate())
	failures.append_array(TechniqueVisualTimeline.validate())
	failures.append_array(CosmeticSocketCatalog.validate())
	failures.append_array(BattleLoadoutCatalog.validate())
	_validate_technique_profiles(failures)
	_validate_cosmetic_ledger(failures)
	_validate_battle_loadouts(failures)
	await _validate_preparation_preview(failures)
	var presets := BuildProfile.available_prototype_presets()
	if presets.size() != 6:
		failures.append("O protótipo deveria expor seis builds, mas encontrou %d" % presets.size())
	for preset_id in presets:
		var profile := BuildProfile.prototype_preset(preset_id)
		if not CharacterVisualCatalog.has_character(profile.character_id):
			failures.append("Build %s referencia personagem inválido" % String(preset_id))
		if profile.character_name.strip_edges() == "":
			failures.append("Build %s não possui nome de personagem" % String(preset_id))
	await _validate_fighters(presets, failures)
	await _validate_main_scene(failures)
	if failures.is_empty():
		print("TAIJIFU CI: prontidão, gamepads, prévia cosmética, entrada, loadouts e combate válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_battle_loadouts(failures: Array[String]) -> void:
	if BattleLoadoutCatalog.FIELD_ORDER.size() != 10:
		failures.append("Preparação deveria possuir dez categorias")
	var unlocked: Array = [&"han_three_currents", &"orra_inverted_foundation", &"lyenne_crossing_wing"]
	var staff_variants := BattleLoadoutCatalog.variants_for_weapon(&"training_staff", unlocked)
	if &"han_three_currents" not in staff_variants or &"orra_inverted_foundation" in staff_variants:
		failures.append("Filtro de variantes por arma está incorreto")
	var source := BattleLoadoutCatalog.loadout_from_preset(&"rin_challenger")
	source["primary_weapon_id"] = &"breaker_gauntlets"
	source["secondary_weapon_id"] = &"training_staff"
	source["element_id"] = &"water"
	source["head"] = &"moon_halo"
	var sanitized := BattleLoadoutCatalog.sanitize(source, unlocked)
	if StringName(sanitized.get("character_id", &"")) != &"rin":
		failures.append("Loadout não preservou personagem")
	if StringName(sanitized.get("primary_weapon_id", &"")) != &"breaker_gauntlets":
		failures.append("Loadout não preservou arma principal")
	var ledger := BattleLoadoutLedger.new()
	ledger.set_loadout(1, sanitized, unlocked)
	var restored := ledger.loadout_for(1, unlocked)
	if StringName(restored.get("element_id", &"")) != &"water":
		failures.append("Ledger de preparação não restaurou elemento")

func _validate_preparation_preview(failures: Array[String]) -> void:
	var preview := PreparationAvatarPreview.new()
	root.add_child(preview)
	var loadout := BattleLoadoutCatalog.loadout_from_preset(&"rin_challenger")
	loadout["head"] = &"moon_halo"
	loadout["back"] = &"tide_ribbons"
	loadout["chest"] = &"tide_amulet"
	loadout["pet"] = &"cloud_wisp"
	preview.apply_loadout(loadout)
	await process_frame
	if StringName(preview.current_loadout().get("character_id", &"")) != &"rin":
		failures.append("Prévia não recebeu o personagem do loadout")
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		if preview.displayed_item(socket_id) == &"none":
			failures.append("Prévia não exibiu o socket %s" % String(socket_id))
	preview.queue_free()
	await process_frame

func _validate_technique_profiles(failures: Array[String]) -> void:
	var base := CharacterAttachmentCatalog.attachment(&"kael", &"attack", 1, 1.0)
	for technique_id in TechniqueAttachmentCatalog.technique_ids():
		var profile := TechniqueAttachmentCatalog.trail_profile(technique_id)
		if not profile.has("enabled"):
			failures.append("Trilha sem estado enabled para %s" % String(technique_id))
		for stage in TechniqueAttachmentCatalog.PREVIEW_STAGES:
			var phase_id := stage
			var progress := 0.6
			if stage in [&"active_early", &"active_late"]:
				phase_id = &"active"
				progress = 0.25 if stage == &"active_early" else 0.75
			var resolved := TechniqueAttachmentCatalog.resolve(base, technique_id, phase_id, progress, 1.0)
			if not (resolved.get("hand", null) is Vector2):
				failures.append("Técnica %s/%s não resolveu mão" % [String(technique_id), String(stage)])
			if float(resolved.get("reach", 0.0)) <= 0.0:
				failures.append("Técnica %s/%s resolveu alcance inválido" % [String(technique_id), String(stage)])

func _validate_cosmetic_ledger(failures: Array[String]) -> void:
	var ledger := CosmeticLoadoutLedger.new()
	var default_loadout := ledger.loadout_for("ci_profile", &"kael")
	if default_loadout.size() != CosmeticSocketCatalog.SOCKET_IDS.size():
		failures.append("Loadout cosmético padrão incompleto")
	ledger.set_loadout("ci_profile", {"head": "invalid", "back": "flow_scarf", "chest": "jade_amulet", "pet": "fox_spirit"})
	var sanitized := ledger.loadout_for("ci_profile", &"kael")
	if StringName(sanitized.get("head", "")) != &"none":
		failures.append("Ledger cosmético não sanitizou item inválido")

func _validate_fighters(presets: Array[StringName], failures: Array[String]) -> void:
	var fighter_scene := load("res://scenes/fighter/fighter.tscn") as PackedScene
	if not is_instance_valid(fighter_scene):
		failures.append("Não foi possível carregar scenes/fighter/fighter.tscn")
		return
	for preset_id in presets:
		var fighter := fighter_scene.instantiate() as MasteredWeaponFighterController
		if not is_instance_valid(fighter):
			failures.append("Não foi possível instanciar lutador para %s" % String(preset_id))
			continue
		fighter.build_preset = preset_id
		root.add_child(fighter)
		await process_frame
		await process_frame
		var presenter := fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
		var flash := fighter.get_node_or_null("RegionalHitFlash") as RegionalHitFlash
		var trail := fighter.get_node_or_null("WeaponTrail") as WeaponTrailRuntime
		var overlay := fighter.get_node_or_null("VisualOverlay") as FighterVisualOverlay
		var outcome := fighter.get_node_or_null("OutcomeRuntime") as FighterOutcomeRuntime
		var cosmetics := fighter.get_node_or_null("CosmeticSockets") as CosmeticSocketPresenter
		var expression := fighter.get_node_or_null("ExpressionOverlay") as FighterExpressionOverlay
		var expected := BuildProfile.prototype_preset(preset_id).character_id
		if not is_instance_valid(presenter) or not presenter.has_active_sprite():
			failures.append("Presenter inativo para %s" % String(preset_id))
		elif presenter.character_id() != expected:
			failures.append("Presenter de %s resolveu personagem incorreto" % String(preset_id))
		if not is_instance_valid(flash):
			failures.append("Flash regional ausente para %s" % String(preset_id))
		else:
			flash.preview_hit(&"head", &"hit", 0.8)
			if not flash.is_flash_active():
				failures.append("Flash regional não respondeu para %s" % String(preset_id))
		if not is_instance_valid(trail) or not is_instance_valid(overlay):
			failures.append("Trilha ou overlay ausente para %s" % String(preset_id))
		else:
			trail.add_test_point(Vector2.ZERO)
			trail.add_test_point(Vector2(10, 0))
			if trail.point_count() != 2:
				failures.append("Trilha não armazenou pontos para %s" % String(preset_id))
		if not is_instance_valid(outcome) or not is_instance_valid(cosmetics) or not is_instance_valid(expression):
			failures.append("Apresentação final incompleta para %s" % String(preset_id))
		else:
			cosmetics.apply_loadout(CosmeticSocketCatalog.default_loadout(expected))
			if cosmetics.current_loadout().size() != 4:
				failures.append("Cosméticos não aceitaram quatro sockets para %s" % String(preset_id))
			expression.preview_expression(&"victory")
			if expression.current_expression_id() != &"victory":
				failures.append("Expressão não respondeu para %s" % String(preset_id))
			expression.clear_expression_preview()
			outcome.preview_outcome(&"fall", 0.21)
			if absf(float(outcome.visual_transform().get("rotation", 0.0))) <= 0.01:
				failures.append("Queda não gerou rotação para %s" % String(preset_id))
			outcome.reset_outcome()
		_validate_phase_frames(fighter, failures, preset_id)
		_validate_attachment(expected, presenter, failures)
		fighter.queue_free()
		await process_frame

func _validate_phase_frames(fighter: MasteredWeaponFighterController, failures: Array[String], preset_id: StringName) -> void:
	fighter._current_technique = TechniqueCatalog.get_technique(&"staff_long_thrust")
	fighter._attack_phase = FighterController.AttackPhase.STARTUP
	fighter._attack_phase_timer = fighter._current_technique.startup_seconds()
	if TechniqueVisualTimeline.frame_for_fighter(fighter) != 0:
		failures.append("Startup não resolveu quadro 0 para %s" % String(preset_id))
	fighter._attack_phase = FighterController.AttackPhase.ACTIVE
	fighter._attack_phase_timer = fighter._current_technique.active_seconds() * 0.75
	if TechniqueVisualTimeline.frame_for_fighter(fighter) != 1:
		failures.append("Início ativo não resolveu quadro 1 para %s" % String(preset_id))
	fighter._attack_phase_timer = fighter._current_technique.active_seconds() * 0.20
	if TechniqueVisualTimeline.frame_for_fighter(fighter) != 2:
		failures.append("Fim ativo não resolveu quadro 2 para %s" % String(preset_id))
	fighter._attack_phase = FighterController.AttackPhase.RECOVERY
	fighter._attack_phase_timer = fighter._current_technique.recovery_seconds()
	if TechniqueVisualTimeline.frame_for_fighter(fighter) != 3:
		failures.append("Recovery não resolveu quadro 3 para %s" % String(preset_id))
	fighter._attack_phase = FighterController.AttackPhase.NONE
	fighter._attack_phase_timer = 0.0
	fighter._current_technique = null

func _validate_attachment(character_id: StringName, presenter: ProvisionalSpritePresenter, failures: Array[String]) -> void:
	var attachment := CharacterAttachmentCatalog.attachment(character_id, presenter.current_state_id(), presenter.current_frame_index(), 1.0)
	if not (attachment.get("hand", null) is Vector2):
		failures.append("Encaixe de mão inválido para %s" % String(character_id))
	if not (attachment.get("rear_hand", null) is Vector2):
		failures.append("Encaixe de apoio inválido para %s" % String(character_id))

func _validate_main_scene(failures: Array[String]) -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(main_scene):
		failures.append("Não foi possível carregar scenes/main.tscn")
		return
	var instance := main_scene.instantiate()
	if not is_instance_valid(instance):
		failures.append("Não foi possível instanciar scenes/main.tscn")
		return
	root.add_child(instance)
	await process_frame
	await process_frame
	for node_path in [
		"ImpactDirector", "DojoTrainingRuntime", "AssetInspectorRuntime", "AttachmentEditorRuntime",
		"CosmeticLoadoutRuntime", "MatchOutcomeRuntime", "RosterHudRuntime", "BattlePreparationRuntime",
		"ArenaEntranceRuntime"
	]:
		if not is_instance_valid(instance.get_node_or_null(node_path)):
			failures.append("%s não foi integrado à cena principal" % node_path)
	var editor := instance.get_node_or_null("AttachmentEditorRuntime") as AttachmentEditorRuntime
	if is_instance_valid(editor):
		var key := TechniqueAttachmentCatalog.override_key(&"kael", &"staff_long_thrust", &"startup")
		editor.set_override_for_test(key, {"hand_x": 3.0, "reach": 1.1})
		var loaded := editor.override_for(&"kael", &"staff_long_thrust", &"startup", 0.5)
		if float(loaded.get("hand_x", 0.0)) != 3.0 or editor.override_count() < 1:
			failures.append("Editor não aplicou override em memória")
	var preparation := instance.get_node_or_null("BattlePreparationRuntime") as BattlePreparationRuntime
	var entrance := instance.get_node_or_null("ArenaEntranceRuntime") as ArenaEntranceRuntime
	if is_instance_valid(preparation):
		if not preparation.registered_gamepad_actions_valid():
			failures.append("Preparação não registrou ações para os dois gamepads")
		var test_loadout := BattleLoadoutCatalog.loadout_from_preset(&"rin_challenger")
		test_loadout["element_id"] = &"water"
		test_loadout["primary_weapon_id"] = &"breaker_gauntlets"
		test_loadout["secondary_weapon_id"] = &"training_staff"
		test_loadout["head"] = &"moon_halo"
		preparation.set_loadout_for_test(1, test_loadout)
		preparation.set_ready_for_test(1, true)
		preparation.set_ready_for_test(2, true)
		if not preparation.all_players_ready():
			failures.append("Prontidão individual não confirmou os dois jogadores")
		instance.call("_start_battle")
		await process_frame
		await process_frame
		var fighter: WeaponKitFighterController = instance.get("player_one") as WeaponKitFighterController
		if not is_instance_valid(fighter):
			failures.append("Preparação não iniciou o P1")
		else:
			if fighter.build.character_id != &"rin" or fighter.build.element_id != &"water":
				failures.append("Loadout não aplicou personagem ou elemento ao P1")
			if fighter.primary_weapon_id != &"breaker_gauntlets" or fighter.secondary_weapon_id != &"training_staff":
				failures.append("Loadout não aplicou kit de armas ao P1")
			if fighter.is_physics_processing():
				failures.append("P1 não foi congelado durante a entrada")
		if is_instance_valid(entrance):
			if not entrance.is_active():
				failures.append("Entrada não iniciou após a prontidão")
			entrance.preview_progress(0.5)
			entrance.skip_for_test()
			await process_frame
			await process_frame
			if entrance.is_active():
				failures.append("Entrada não encerrou após skip")
			if is_instance_valid(fighter) and not fighter.is_physics_processing():
				failures.append("P1 não recuperou a física após LUTEM")
	if not _has_joypad_event(&"p1_attack", 0) or not _has_joypad_event(&"p2_attack", 1):
		failures.append("Combate não registrou gamepads separados para P1 e P2")
	instance.queue_free()
	await process_frame

func _has_joypad_event(action_id: StringName, device: int) -> bool:
	if not InputMap.has_action(action_id):
		return false
	for event in InputMap.action_get_events(action_id):
		if event is InputEventJoypadButton and event.device == device:
			return true
		if event is InputEventJoypadMotion and event.device == device:
			return true
	return false
