class_name WeaponMasteryRuntime
extends Node

const ADAPTATION_WINDOW_MSEC := 2600

@onready var intelligence_runtime: PrototypeIntelligenceRuntime = get_node("../PrototypeIntelligenceRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var ledger := WeaponMasteryLedger.new()
var _connected_fighters: Dictionary = {}
var _last_technique_weapon: Dictionary = {}
var _last_weapon_technique: Dictionary = {}
var _recent_swap_deadline: Dictionary = {}
var _status_label: Label
var _status_timer := 0.0
var _saved_path := ""

func _ready() -> void:
	ledger.load_from_disk()
	_register_key_action(&"p1_swap", KEY_V)
	_register_key_action(&"p2_swap", KEY_KP_7)
	_create_status_label()
	if not intelligence_runtime.round_report_ready.is_connected(_on_round_report_ready):
		intelligence_runtime.round_report_ready.connect(_on_round_report_ready)

func _process(delta: float) -> void:
	_discover_fighters()
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.18
		_update_status_label()

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is WeaponKitFighterController):
			continue
		var fighter := node as WeaponKitFighterController
		var instance_id := fighter.get_instance_id()
		if _connected_fighters.has(instance_id):
			continue
		_connected_fighters[instance_id] = fighter
		fighter.technique_started.connect(_on_technique_started)
		fighter.technique_experienced.connect(_on_technique_experienced)
		fighter.parry_performed.connect(_on_parry_performed)
		fighter.weapon_swapped.connect(_on_weapon_swapped)
		fighter.weapon_disarmed.connect(_on_weapon_disarmed)

func _on_technique_started(fighter: FighterController, technique_id: StringName) -> void:
	var weapon_id := fighter.equipped_weapon_id
	if not WeaponKitCatalog.is_technique_for_weapon(weapon_id, technique_id):
		return
	var fighter_id := fighter.get_instance_id()
	_last_technique_weapon[fighter_id] = weapon_id
	_last_weapon_technique[fighter_id] = technique_id
	ledger.record_event(_profile_id(fighter), weapon_id, &"uses", 1.0)

func _on_technique_experienced(
	_defender: FighterController,
	attacker: FighterController,
	technique_id: StringName,
	outcome_id: StringName
) -> void:
	if not is_instance_valid(attacker):
		return
	var attacker_id := attacker.get_instance_id()
	if StringName(_last_weapon_technique.get(attacker_id, &"")) != technique_id:
		return
	var weapon_id: StringName = _last_technique_weapon.get(attacker_id, attacker.equipped_weapon_id)
	var profile_id := _profile_id(attacker)
	match outcome_id:
		&"hit":
			ledger.record_event(profile_id, weapon_id, &"hits", 4.0)
		&"blocked":
			ledger.record_event(profile_id, weapon_id, &"blocked_contacts", 2.0)
		&"parried":
			ledger.record_event(profile_id, weapon_id, &"parried_contacts", 0.8)
		&"evaded":
			ledger.record_event(profile_id, weapon_id, &"evaded_contacts", 0.4)

	var deadline := int(_recent_swap_deadline.get(attacker_id, 0))
	if deadline > Time.get_ticks_msec() and outcome_id in [&"hit", &"blocked"]:
		ledger.record_event(profile_id, weapon_id, &"adaptive_hits", 5.0)
		_recent_swap_deadline.erase(attacker_id)

func _on_parry_performed(fighter: FighterController) -> void:
	ledger.record_event(_profile_id(fighter), fighter.equipped_weapon_id, &"parries", 3.0)

func _on_weapon_swapped(
	fighter: WeaponKitFighterController,
	_from_weapon_id: StringName,
	to_weapon_id: StringName,
	_slot_id: int
) -> void:
	ledger.record_event(_profile_id(fighter), to_weapon_id, &"swaps", 1.0)
	_recent_swap_deadline[fighter.get_instance_id()] = Time.get_ticks_msec() + ADAPTATION_WINDOW_MSEC

func _on_weapon_disarmed(fighter: FighterController, weapon_id: StringName) -> void:
	ledger.record_event(_profile_id(fighter), weapon_id, &"disarms_suffered", 0.0)

func _on_round_report_ready(_report: Dictionary, _telemetry_path: String) -> void:
	_saved_path = ledger.save_to_disk()
	_update_status_label()

func _profile_id(fighter: FighterController) -> String:
	return "p%d" % fighter.player_index

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 430.0
	_status_label.offset_top = 174.0
	_status_label.offset_right = 1000.0
	_status_label.offset_bottom = 224.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.46, 0.96))
	hud.add_child(_status_label)
	_update_status_label()

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var fighters: Array[WeaponKitFighterController] = []
	for node in get_tree().get_nodes_in_group("fighters"):
		if node is WeaponKitFighterController:
			fighters.append(node as WeaponKitFighterController)
	fighters.sort_custom(_sort_fighters)

	var summaries: Array[String] = []
	for fighter in fighters:
		var progress := ledger.progress_for(_profile_id(fighter), fighter.equipped_weapon_id)
		summaries.append("P%d %s • %s • %d XP" % [
			fighter.player_index,
			fighter.active_weapon_slot_label(),
			String(progress.get("stage_label", "DESCONHECIDA")),
			roundi(float(progress.get("xp", 0.0)))
		])
	var suffix := ""
	if _saved_path != "":
		suffix = " • %s" % _saved_path.get_file()
	_status_label.text = "V/NUM7 TROCA • %s%s" % ["   |   ".join(summaries), suffix]

func _sort_fighters(a: WeaponKitFighterController, b: WeaponKitFighterController) -> bool:
	return a.player_index < b.player_index

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	ledger.save_to_disk()