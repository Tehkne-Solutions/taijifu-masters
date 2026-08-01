class_name FirstPlayableComboRuntime
extends Node

const COMBO_WINDOW := 0.82
const MAX_BUFFERED_INPUTS := 3
const ACTION_TAI: StringName = &"first_playable_tai"
const ACTION_JI: StringName = &"first_playable_ji"
const ACTION_FU: StringName = &"first_playable_fu"

var _root: Node
var _fighter: FighterController
var _queue: Array[Dictionary] = []
var _last_family: StringName = &""
var _repeat_index := 0
var _combo_timer := 0.0
var _readout: Label

func _ready() -> void:
	process_priority = -20
	_root = get_parent()
	_install_bindings()
	_build_readout()

func _exit_tree() -> void:
	_restore_legacy_bindings()

func _physics_process(delta: float) -> void:
	_resolve_fighter()
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_last_family = &""
		_repeat_index = 0
		if _queue.is_empty():
			_set_readout("")

	if not _combat_active():
		_queue.clear()
		return

	if Input.is_action_just_pressed(ACTION_TAI):
		_buffer_family(&"tai")
	if Input.is_action_just_pressed(ACTION_JI):
		_buffer_family(&"ji")
	if Input.is_action_just_pressed(ACTION_FU):
		_buffer_family(&"fu")

	_try_consume_buffer()

func _combat_active() -> bool:
	if not is_instance_valid(_root) or not is_instance_valid(_fighter):
		return false
	var state: Variant = _root.get("_state")
	return state != null and int(state) == 2

func _resolve_fighter() -> void:
	if is_instance_valid(_fighter):
		return
	if not is_instance_valid(_root):
		return
	var candidate: Variant = _root.get("player_one")
	if candidate is FighterController:
		_fighter = candidate as FighterController

func _buffer_family(family: StringName) -> void:
	if not is_instance_valid(_fighter):
		return
	if family == _last_family and _combo_timer > 0.0:
		_repeat_index = (_repeat_index + 1) % 3
	else:
		_repeat_index = 0
	_last_family = family
	_combo_timer = COMBO_WINDOW

	var token := {
		"family": family,
		"step": _repeat_index,
		"down": Input.is_action_pressed(&"p1_down"),
		"forward": _forward_pressed(),
		"back": _back_pressed(),
	}
	if _queue.size() >= MAX_BUFFERED_INPUTS:
		_queue.pop_front()
	_queue.append(token)
	_set_readout(_combo_label(family, _repeat_index))

func _try_consume_buffer() -> void:
	if _queue.is_empty() or not is_instance_valid(_fighter):
		return
	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		return
	if _fighter._dodge_timer > 0.0 or _fighter._is_blocking:
		return

	var token: Dictionary = _queue.pop_front()
	var technique_id := _technique_for(token)
	if technique_id == &"":
		return
	if _fighter._begin_technique(technique_id):
		var technique := TechniqueCatalog.get_technique(technique_id)
		_set_readout("%s  •  %s" % [_family_label(StringName(token["family"])), technique.display_name.to_upper()])
	else:
		_set_readout("SEM JANELA / FÔLEGO")

func _technique_for(token: Dictionary) -> StringName:
	var family := StringName(token["family"])
	var step := int(token["step"])
	var down := bool(token["down"])
	var back := bool(token["back"])

	match family:
		&"tai":
			if not _fighter.is_on_floor():
				return _fighter.build.technique_for("tai", 1)
			if step == 0:
				return _fighter.build.technique_for("tai", 0)
			if step == 1:
				return _fighter.build.technique_for("fu", 0)
			return _fighter.build.technique_for("ji", 0)
		&"ji":
			if down or step == 1:
				return &"ji_sweep"
			# Não existe mais "golpe de empurrão" como ação dedicada.
			# O terceiro contato volta a um golpe Ji; o deslocamento vem do
			# horizontal_force/vertical_force da técnica quando ela conecta.
			return _fighter.build.technique_for("ji", 0)
		&"fu":
			if back or step == 1:
				return &"fu_reversal"
			if step == 2:
				return _fighter.build.technique_for("tai", 0)
			return _fighter.build.technique_for("fu", 0)
	return &""

func _forward_pressed() -> bool:
	if not is_instance_valid(_fighter):
		return false
	return Input.is_action_pressed(&"p1_right") if _fighter.facing > 0.0 else Input.is_action_pressed(&"p1_left")

func _back_pressed() -> bool:
	if not is_instance_valid(_fighter):
		return false
	return Input.is_action_pressed(&"p1_left") if _fighter.facing > 0.0 else Input.is_action_pressed(&"p1_right")

func _install_bindings() -> void:
	_bind_key(ACTION_TAI, KEY_F)
	_bind_key(ACTION_JI, KEY_G)
	_bind_key(ACTION_FU, KEY_H)
	_unbind_key(&"p1_attack", KEY_F)
	_unbind_key(&"p1_push", KEY_G)
	_unbind_key(&"p1_echo", KEY_H)

func _restore_legacy_bindings() -> void:
	_bind_key(&"p1_attack", KEY_F)
	_bind_key(&"p1_push", KEY_G)
	_bind_key(&"p1_echo", KEY_H)

func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _unbind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action).duplicate():
		if event is InputEventKey and event.physical_keycode == keycode:
			InputMap.action_erase_event(action, event)

func _build_readout() -> void:
	if not is_instance_valid(_root):
		return
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	_readout = Label.new()
	_readout.name = "ComboReadout"
	_readout.position = Vector2(455, 98)
	_readout.size = Vector2(370, 28)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.add_theme_font_size_override("font_size", 11)
	_readout.add_theme_color_override("font_color", Color(0.96, 0.83, 0.42, 0.96))
	_readout.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(_readout)

func _set_readout(text: String) -> void:
	if is_instance_valid(_readout):
		_readout.text = text

func _combo_label(family: StringName, step: int) -> String:
	var key := "F" if family == &"tai" else ("G" if family == &"ji" else "H")
	return "%s  •  %s x%d" % [_family_label(family), key, step + 1]

func _family_label(family: StringName) -> String:
	match family:
		&"tai": return "TAI"
		&"ji": return "JI"
		_: return "FU"

func presentation_signature() -> Dictionary:
	return {
		"discrete_attack_buttons": true,
		"tai_button": "F",
		"ji_button": "G",
		"fu_button": "H",
		"combo_buffer_seconds": COMBO_WINDOW,
		"repeat_button_sequences": true,
		"direction_modifiers": true,
		"air_attack_modifier": true,
		"low_attack_modifier": true,
		"reversal_modifier": true,
		"legacy_single_attack_unbound": true,
		"dedicated_push_attack": false,
		"knockback_is_hit_consequence": true,
		"clean_hit_full_knockback": true,
		"guard_reduces_damage_and_knockback": true,
		"dodge_negates_hit": true,
		"parry_negates_hit": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
