extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scenes/main.tscn",
	"res://scenes/fighter/fighter.tscn",
	"res://assets/characters/kael/kael_animated_sheet.svg",
	"res://assets/characters/nara/nara_animated_sheet.svg",
	"res://assets/characters/lyra/lyra_animated_sheet.svg",
	"res://assets/characters/rin/rin_animated_sheet.svg",
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
	_validate_technique_profiles(failures)
	_validate_cosmetic_ledger(failures)
	var presets := BuildProfile.available_prototype_presets()
	if presets.size() != 6:
		failures.append("O protótipo deveria expor seis builds, mas encontrou %d" % presets.size())
	for preset_id in presets:
		var profile := BuildProfile.prototype_preset(preset_id)
		if not CharacterVisualCatalog.has_character(profile.character_id):
			failures.append("Build %s referencia personagem inválido: %s" % [String(preset_id), String(profile.character_id)])
		if profile.character_name.strip_edges() == "":
			failures.append("Build %s não possui nome de personagem" % String(preset_id))
	await _validate_fighters(presets, failures)
	await _validate_main_scene(failures)
	if failures.is_empty():
		print("TAIJIFU CI: cosméticos, expressões, resultados, técnicas e cena principal válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

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
			var loadout := CosmeticSocketCatalog.default_loadout(expected)
			cosmetics.apply_loadout(loadout)
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
		"CosmeticLoadoutRuntime", "MatchOutcomeRuntime", "RosterHudRuntime"
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
	instance.queue_free()
	await process_frame
