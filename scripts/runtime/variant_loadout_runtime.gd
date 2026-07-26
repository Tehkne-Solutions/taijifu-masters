class_name VariantLoadoutRuntime
extends Node

@onready var hud: CanvasLayer = get_node("../HUD")
@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

var ledger: MasterTrainingLedger
var _connected_fighters: Dictionary = {}
var _status_label: Label
var _refresh_timer := 0.0
var _feedback := ""

func _ready() -> void:
	ledger = master_training_runtime.ledger
	_register_key_action(&"p1_variant_prev", KEY_Z)
	_register_key_action(&"p1_variant_next", KEY_X)
	_register_key_action(&"p2_variant_prev", KEY_KP_8)
	_register_key_action(&"p2_variant_next", KEY_KP_9)
	_create_status_label()

func _process(delta: float) -> void:
	_discover_fighters()
	_process_selection_inputs()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.18
		_apply_selections()
		_update_status_label()

func _process_selection_inputs() -> void:
	var changed := false
	if Input.is_action_just_pressed(&"p1_variant_prev"):
		ledger.cycle_selected_variant("p1", -1)
		changed = true
	elif Input.is_action_just_pressed(&"p1_variant_next"):
		ledger.cycle_selected_variant("p1", 1)
		changed = true

	if Input.is_action_just_pressed(&"p2_variant_prev"):
		ledger.cycle_selected_variant("p2", -1)
		changed = true
	elif Input.is_action_just_pressed(&"p2_variant_next"):
		ledger.cycle_selected_variant("p2", 1)
		changed = true

	if changed:
		ledger.save_to_disk()
		_feedback = "VARIANTE DE BATALHA ATUALIZADA"
		_apply_selections()
		_update_status_label()

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is WeaponKitFighterController):
			continue
		var fighter := node as WeaponKitFighterController
		_connected_fighters[fighter.get_instance_id()] = fighter

func _apply_selections() -> void:
	for fighter_value in _connected_fighters.values():
		if not is_instance_valid(fighter_value):
			continue
		var fighter := fighter_value as WeaponKitFighterController
		var profile_id := "p%d" % fighter.player_index
		var unlocked := ledger.unlocked_variants(profile_id)
		fighter.set_unlocked_variants(MasterTrainingCatalog.variant_mapping(unlocked))
		fighter.set_selected_training_variant(ledger.selected_variant(profile_id))

func selected_variant_for_profile(profile_id: String) -> StringName:
	return ledger.selected_variant(profile_id)

func selected_variant_label(profile_id: String) -> String:
	return MasterTrainingCatalog.variant_label(ledger.selected_variant(profile_id))

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 315.0
	_status_label.offset_top = 226.0
	_status_label.offset_right = 965.0
	_status_label.offset_bottom = 274.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0, 0.96))
	hud.add_child(_status_label)
	_update_status_label()

func _update_status_label() -> void:
	if not is_instance_valid(_status_label) or ledger == null:
		return
	var p1_variant := ledger.selected_variant("p1")
	var p2_variant := ledger.selected_variant("p2")
	var p1_count := ledger.unlocked_variants("p1").size()
	var p2_count := ledger.unlocked_variants("p2").size()
	var suffix := "" if _feedback == "" else "\n%s" % _feedback
	_status_label.text = "Z/X P1: %s (%d)   |   NUM8/NUM9 P2: %s (%d)%s" % [
		MasterTrainingCatalog.variant_label(p1_variant),
		p1_count,
		MasterTrainingCatalog.variant_label(p2_variant),
		p2_count,
		suffix
	]

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
	if ledger != null:
		ledger.save_to_disk()
