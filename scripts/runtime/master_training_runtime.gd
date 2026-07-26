class_name MasterTrainingRuntime
extends Node

const ADAPTATION_WINDOW_MSEC := 2600

@onready var weapon_mastery_runtime: WeaponMasteryRuntime = get_node("../WeaponMasteryRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var ledger := MasterTrainingLedger.new()
var _master_ids: Array[StringName] = []
var _selected_profile_index := 0
var _selected_master_index := 0
var _active_trials: Dictionary = {}
var _connected_fighters: Dictionary = {}
var _recent_swap_deadline: Dictionary = {}
var _panel: ColorRect
var _title_label: Label
var _body_label: Label
var _footer_label: Label
var _refresh_timer := 0.0
var _feedback := ""

func _ready() -> void:
	ledger.load_from_disk()
	_master_ids = MasterTrainingCatalog.available_masters()
	_register_key_action(&"training_toggle", KEY_T)
	_register_key_action(&"training_profile", KEY_Y)
	_register_key_action(&"training_master", KEY_U)
	_register_key_action(&"training_start", KEY_I)
	_create_panel()

func _process(delta: float) -> void:
	_discover_fighters()
	_process_inputs()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.18
		_update_panel()

func _process_inputs() -> void:
	if Input.is_action_just_pressed("training_toggle"):
		_panel.visible = not _panel.visible
		_update_panel()
	if Input.is_action_just_pressed("training_profile"):
		_selected_profile_index = wrapi(_selected_profile_index + 1, 0, 2)
		_update_panel()
	if Input.is_action_just_pressed("training_master"):
		_selected_master_index = wrapi(_selected_master_index + 1, 0, _master_ids.size())
		_update_panel()
	if Input.is_action_just_pressed("training_start"):
		_start_selected_trial()

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is WeaponKitFighterController):
			continue
		var fighter := node as WeaponKitFighterController
		var instance_id := fighter.get_instance_id()
		_apply_unlocked_variants(fighter)
		if _connected_fighters.has(instance_id):
			continue
		_connected_fighters[instance_id] = fighter
		fighter.technique_started.connect(_on_technique_started)
		fighter.technique_experienced.connect(_on_technique_experienced)
		fighter.parry_performed.connect(_on_parry_performed)
		fighter.weapon_swapped.connect(_on_weapon_swapped)
		fighter.training_variant_applied.connect(_on_training_variant_applied)

func _start_selected_trial() -> void:
	var profile_id := _selected_profile_id()
	var master_id := _selected_master_id()
	var master := MasterTrainingCatalog.master(master_id)
	var variant_id := StringName(master.get("variant_id", &""))
	if ledger.is_unlocked(profile_id, variant_id):
		_feedback = "%s já foi liberada." % String(master.get("reward_name", "VARIANTE"))
		return
	var weapon_id := _eligible_weapon(profile_id, master)
	if weapon_id == &"":
		_feedback = "Domínio insuficiente. Alcance o estágio %s em uma arma compatível." % String(master.get("required_stage", &"trained")).to_upper()
		return
	_active_trials[profile_id] = {
		"master_id": master_id,
		"weapon_id": weapon_id,
		"metrics": {"uses": 0, "hits": 0, "parries": 0, "swaps": 0, "adaptive_hits": 0}
	}
	_feedback = "Prova iniciada: %s." % String(master.get("trial_name", "PROVA"))
	_update_panel()

func _eligible_weapon(profile_id: String, master: Dictionary) -> StringName:
	var required_stage := StringName(master.get("required_stage", &"trained"))
	var weapon_ids: Array = master.get("weapon_ids", [])
	var selected := &""
	var best_xp := -1.0
	for weapon_value in weapon_ids:
		var weapon_id := StringName(weapon_value)
		var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
		var stage_id := StringName(progress.get("stage_id", &"unfamiliar"))
		if not MasterTrainingCatalog.stage_meets(stage_id, required_stage):
			continue
		var xp := float(progress.get("xp", 0.0))
		if xp > best_xp:
			best_xp = xp
			selected = weapon_id
	return selected

func _on_technique_started(fighter: FighterController, technique_id: StringName) -> void:
	var profile_id := _profile_id(fighter)
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	var weapon_id := StringName(trial.get("weapon_id", &""))
	if fighter.equipped_weapon_id != weapon_id:
		return
	if not WeaponKitCatalog.is_technique_for_weapon(weapon_id, technique_id):
		return
	_increment_metric(profile_id, &"uses")

func _on_technique_experienced(
	_defender: FighterController,
	attacker: FighterController,
	technique_id: StringName,
	outcome_id: StringName
) -> void:
	if not is_instance_valid(attacker):
		return
	var profile_id := _profile_id(attacker)
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	var weapon_id := StringName(trial.get("weapon_id", &""))
	if attacker.equipped_weapon_id != weapon_id:
		return
	if not WeaponKitCatalog.is_technique_for_weapon(weapon_id, technique_id):
		return
	if outcome_id == &"hit":
		_increment_metric(profile_id, &"hits")
		var deadline := int(_recent_swap_deadline.get(attacker.get_instance_id(), 0))
		if deadline > Time.get_ticks_msec():
			_increment_metric(profile_id, &"adaptive_hits")
			_recent_swap_deadline.erase(attacker.get_instance_id())

func _on_parry_performed(fighter: FighterController) -> void:
	var profile_id := _profile_id(fighter)
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	if fighter.equipped_weapon_id == StringName(trial.get("weapon_id", &"")):
		_increment_metric(profile_id, &"parries")

func _on_weapon_swapped(
	fighter: WeaponKitFighterController,
	_from_weapon_id: StringName,
	to_weapon_id: StringName,
	_slot_id: int
) -> void:
	var profile_id := _profile_id(fighter)
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	if to_weapon_id != StringName(trial.get("weapon_id", &"")):
		return
	_increment_metric(profile_id, &"swaps")
	_recent_swap_deadline[fighter.get_instance_id()] = Time.get_ticks_msec() + ADAPTATION_WINDOW_MSEC

func _increment_metric(profile_id: String, metric_id: StringName) -> void:
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	var metrics: Dictionary = trial.get("metrics", {})
	var key := String(metric_id)
	metrics[key] = int(metrics.get(key, 0)) + 1
	trial["metrics"] = metrics
	_active_trials[profile_id] = trial
	_check_completion(profile_id)

func _check_completion(profile_id: String) -> void:
	var trial := _trial(profile_id)
	if trial.is_empty():
		return
	var master_id := StringName(trial.get("master_id", &""))
	var master := MasterTrainingCatalog.master(master_id)
	var requirements: Dictionary = master.get("requirements", {})
	var metrics: Dictionary = trial.get("metrics", {})
	for key in requirements.keys():
		if int(metrics.get(String(key), 0)) < int(requirements[key]):
			return
	var variant_id := StringName(master.get("variant_id", &""))
	ledger.unlock_variant(profile_id, master_id, variant_id)
	ledger.save_to_disk()
	_active_trials.erase(profile_id)
	_feedback = "%s concluiu %s e liberou %s." % [profile_id.to_upper(), String(master.get("trial_name", "PROVA")), String(master.get("reward_name", "VARIANTE"))]
	_apply_all_variants()

func _apply_all_variants() -> void:
	for fighter_value in _connected_fighters.values():
		if is_instance_valid(fighter_value):
			_apply_unlocked_variants(fighter_value as WeaponKitFighterController)

func _apply_unlocked_variants(fighter: WeaponKitFighterController) -> void:
	var unlocked := ledger.unlocked_variants(_profile_id(fighter))
	fighter.set_unlocked_variants(MasterTrainingCatalog.variant_mapping(unlocked))

func _on_training_variant_applied(
	fighter: WeaponKitFighterController,
	_variant_id: StringName,
	_display_name: String
) -> void:
	_feedback = "P%d executou %s." % [fighter.player_index, _display_name.to_upper()]

func _trial(profile_id: String) -> Dictionary:
	var value = _active_trials.get(profile_id, {})
	return value if value is Dictionary else {}

func _selected_profile_id() -> String:
	return "p%d" % (_selected_profile_index + 1)

func _selected_master_id() -> StringName:
	return _master_ids[_selected_master_index]

func _profile_id(fighter: FighterController) -> String:
	return "p%d" % fighter.player_index

func _create_panel() -> void:
	_panel = ColorRect.new()
	_panel.offset_left = 205.0
	_panel.offset_top = 185.0
	_panel.offset_right = 1075.0
	_panel.offset_bottom = 570.0
	_panel.color = Color(0.025, 0.032, 0.048, 0.96)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	hud.add_child(_panel)

	_title_label = Label.new()
	_title_label.offset_left = 30.0
	_title_label.offset_top = 18.0
	_title_label.offset_right = 840.0
	_title_label.offset_bottom = 70.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 23)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
	_panel.add_child(_title_label)

	_body_label = Label.new()
	_body_label.offset_left = 42.0
	_body_label.offset_top = 82.0
	_body_label.offset_right = 828.0
	_body_label.offset_bottom = 300.0
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	_panel.add_child(_body_label)

	_footer_label = Label.new()
	_footer_label.offset_left = 30.0
	_footer_label.offset_top = 318.0
	_footer_label.offset_right = 840.0
	_footer_label.offset_bottom = 370.0
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.add_theme_font_size_override("font_size", 13)
	_footer_label.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))
	_panel.add_child(_footer_label)

func _update_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var profile_id := _selected_profile_id()
	var master_id := _selected_master_id()
	var master := MasterTrainingCatalog.master(master_id)
	var weapon_id := _best_mastery_weapon(profile_id, master)
	var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
	var variant_id := StringName(master.get("variant_id", &""))
	var unlocked := ledger.is_unlocked(profile_id, variant_id)
	var trial := _trial(profile_id)
	var requirements: Dictionary = master.get("requirements", {})
	var metrics: Dictionary = trial.get("metrics", {}) if not trial.is_empty() and StringName(trial.get("master_id", &"")) == master_id else {}
	var requirement_lines: Array[String] = []
	for key in requirements.keys():
		requirement_lines.append("%s %d/%d" % [String(key).to_upper(), int(metrics.get(String(key), 0)), int(requirements[key])])
	_title_label.text = "%s • CAMINHO %s" % [String(master.get("name", "MESTRE")), String(master.get("path", "FU"))]
	_body_label.text = "%s\n\nP%d • %s • %s (%d XP)\nRequisito: %s\n\nPROVA: %s\n%s\n\n%s\nRECOMPENSA: %s%s" % [
		String(master.get("description", "")),
		_selected_profile_index + 1,
		WeaponKitCatalog.label_for(weapon_id),
		String(progress.get("stage_label", "DESCONHECIDA")),
		roundi(float(progress.get("xp", 0.0))),
		String(master.get("required_stage", &"trained")).to_upper(),
		String(master.get("trial_name", "PROVA")),
		" • ".join(requirement_lines),
		_feedback,
		String(master.get("reward_name", "VARIANTE")),
		" • LIBERADA" if unlocked else ""
	]
	_footer_label.text = "T FECHA • Y TROCA P1/P2 • U TROCA MESTRE • I INICIA/REINICIA A PROVA"

func _best_mastery_weapon(profile_id: String, master: Dictionary) -> StringName:
	var weapon_ids: Array = master.get("weapon_ids", [])
	var selected := &"unarmed"
	var best_xp := -1.0
	for weapon_value in weapon_ids:
		var weapon_id := StringName(weapon_value)
		var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
		var xp := float(progress.get("xp", 0.0))
		if xp > best_xp:
			best_xp = xp
			selected = weapon_id
	return selected

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	ledger.save_to_disk()
