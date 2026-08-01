class_name FirstPlayableComboRuntime
extends Node

const COMBO_WINDOW := 0.82
const FLOW_WINDOW := 2.40
const CLIMAX_REACTION_WINDOW := 0.48
const MAX_BUFFERED_INPUTS := 3
const MAX_CODE_LENGTH := 4
const FLOW_FOR_CLIMAX := 60.0
const ACTION_TAI: StringName = &"first_playable_tai"
const ACTION_JI: StringName = &"first_playable_ji"
const ACTION_FU: StringName = &"first_playable_fu"

const ELEMENTAL_RECIPES := {
	"tai>ji>tai": {"element": &"fire", "technique": &"element_fire_burst", "name": "DRAGÃO ESCARLATE"},
	"ji>ji>fu": {"element": &"earth", "technique": &"element_earth_anchor", "name": "RAIZ DO TITÃ"},
	"fu>tai>fu": {"element": &"water", "technique": &"element_water_wave", "name": "MARÉ DA LUA"},
	"tai>fu>tai": {"element": &"air", "technique": &"element_air_gust", "name": "SOPRO CELESTE"},
}

var _root: Node
var _fighter: MasteredWeaponFighterController
var _opponent: MasteredWeaponFighterController
var _queue: Array[Dictionary] = []
var _last_family: StringName = &""
var _repeat_index := 0
var _combo_timer := 0.0

var _code_families: Array[StringName] = []
var _combo_hits := 0
var _flow := 0.0
var _flow_timer := 0.0
var _last_started_family: StringName = &""
var _last_started_technique: StringName = &""
var _last_technique_name := ""

var _climax_active := false
var _climax_timer := 0.0
var _pending_element: StringName = &""
var _pending_element_technique: StringName = &""
var _pending_form_name := ""

var _readout: Label
var _combo_label_node: Label
var _technique_label_node: Label
var _code_label_node: Label
var _flow_label_node: Label
var _resonance_label_node: Label
var _climax_panel: PanelContainer
var _climax_title: Label
var _climax_hint: Label

func _ready() -> void:
	process_priority = -20
	_root = get_parent()
	_install_bindings()
	_build_readout()
	_build_flow_hud()
	_build_climax_overlay()

func _exit_tree() -> void:
	_restore_legacy_bindings()

func _physics_process(delta: float) -> void:
	_resolve_fighters()
	_update_input_combo_timer(delta)
	_update_flow_timer(delta)
	_update_climax(delta)

	if not _combat_active():
		_queue.clear()
		return

	if _climax_active:
		# O atacante fica comprometido com a forma; o defensor segue livre.
		if is_instance_valid(_fighter):
			_fighter.velocity.x *= 0.82
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

func _resolve_fighters() -> void:
	if not is_instance_valid(_root):
		return
	if not is_instance_valid(_fighter):
		var candidate: Variant = _root.get("player_one")
		if candidate is MasteredWeaponFighterController:
			_fighter = candidate as MasteredWeaponFighterController
	if not is_instance_valid(_opponent):
		var candidate: Variant = _root.get("player_two")
		if candidate is MasteredWeaponFighterController:
			_opponent = candidate as MasteredWeaponFighterController
			if not _opponent.impact_resolved.is_connected(_on_opponent_impact_resolved):
				_opponent.impact_resolved.connect(_on_opponent_impact_resolved)

func _update_input_combo_timer(delta: float) -> void:
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_last_family = &""
		_repeat_index = 0

func _update_flow_timer(delta: float) -> void:
	_flow_timer = maxf(0.0, _flow_timer - delta)
	if _flow_timer <= 0.0 and not _code_families.is_empty() and not _climax_active:
		_break_martial_code("CÓDIGO PERDIDO")
	elif _code_families.is_empty() and not _climax_active:
		_flow = maxf(0.0, _flow - delta * 7.0)
		_update_flow_hud()

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
	_set_readout(_input_combo_label(family, _repeat_index))

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
		var family := StringName(token["family"])
		var technique := TechniqueCatalog.get_technique(technique_id)
		_last_started_family = family
		_last_started_technique = technique_id
		_last_technique_name = technique.display_name.to_upper()
		_set_readout("%s  •  %s" % [_family_label(family), _last_technique_name])
		_update_flow_hud()
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
			return _fighter.build.technique_for("ji", 0)
		&"fu":
			if back or step == 1:
				return &"fu_reversal"
			if step == 2:
				return _fighter.build.technique_for("tai", 0)
			return _fighter.build.technique_for("fu", 0)
	return &""

func _on_opponent_impact_resolved(
	_target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	_damage_applied: float,
	_posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if attacker != _fighter or not is_instance_valid(technique):
		return
	if _last_started_family == &"" or technique.technique_id != _last_started_technique:
		return

	match result_id:
		&"hit":
			_register_confirmed_martial_hit(_last_started_family, 34.0)
		&"posture_break":
			_register_confirmed_martial_hit(_last_started_family, 44.0)
		&"blocked":
			_flow = minf(100.0, _flow + 8.0)
			_combo_hits = 0
			_flow_timer = FLOW_WINDOW
			_set_readout("BLOQUEADO  •  FLUXO +8")
			_update_flow_hud()
		&"evaded":
			_break_martial_code("ESQUIVADO  •  CÓDIGO QUEBRADO")
		&"parried":
			_break_martial_code("PARRY  •  FLUXO QUEBRADO")

func _register_confirmed_martial_hit(family: StringName, flow_gain: float) -> void:
	_combo_hits += 1
	_flow = minf(100.0, _flow + flow_gain)
	_flow_timer = FLOW_WINDOW
	_code_families.append(family)
	while _code_families.size() > MAX_CODE_LENGTH:
		_code_families.pop_front()
	_update_flow_hud()
	_check_elemental_recipe()

func _check_elemental_recipe() -> void:
	if _code_families.size() < 3 or _climax_active:
		return
	var key := _last_three_code_key()
	if not ELEMENTAL_RECIPES.has(key):
		return
	if _flow < FLOW_FOR_CLIMAX:
		_set_readout("FORMA RECONHECIDA  •  FLUXO INSUFICIENTE")
		return
	var recipe: Dictionary = ELEMENTAL_RECIPES[key]
	_begin_climax(
		StringName(recipe["element"]),
		StringName(recipe["technique"]),
		String(recipe["name"])
	)

func _begin_climax(element_id: StringName, technique_id: StringName, form_name: String) -> void:
	_climax_active = true
	_climax_timer = CLIMAX_REACTION_WINDOW
	_pending_element = element_id
	_pending_element_technique = technique_id
	_pending_form_name = form_name
	_queue.clear()
	_set_readout("FORMA COMPLETA  •  %s" % form_name)
	_show_climax_overlay(true)
	_update_flow_hud()

func _update_climax(delta: float) -> void:
	if not _climax_active:
		return
	_climax_timer = maxf(0.0, _climax_timer - delta)
	_update_climax_text()
	if _climax_timer > 0.0:
		return
	if not is_instance_valid(_fighter) or _fighter._attack_phase != FighterController.AttackPhase.NONE:
		return

	_last_started_family = &""
	_last_started_technique = &""
	var began := _fighter._begin_technique(_pending_element_technique)
	if began:
		_set_readout("%s  •  INVOCAÇÃO" % _pending_form_name)
	else:
		_set_readout("FORMA DESFEITA  •  SEM FÔLEGO")
	_finish_climax()

func _finish_climax() -> void:
	_climax_active = false
	_pending_element = &""
	_pending_element_technique = &""
	_pending_form_name = ""
	_code_families.clear()
	_combo_hits = 0
	_flow = 0.0
	_flow_timer = 0.0
	_show_climax_overlay(false)
	_update_flow_hud()

func _break_martial_code(reason: String) -> void:
	_code_families.clear()
	_combo_hits = 0
	_flow = 0.0
	_flow_timer = 0.0
	_queue.clear()
	_set_readout(reason)
	_update_flow_hud()

func _last_three_code_key() -> String:
	var start := maxi(0, _code_families.size() - 3)
	var parts: Array[String] = []
	for index in range(start, _code_families.size()):
		parts.append(String(_code_families[index]))
	return ">".join(parts)

func _code_key() -> String:
	var parts: Array[String] = []
	for family in _code_families:
		parts.append(String(family))
	return ">".join(parts)

func _predicted_resonance() -> String:
	if _code_families.is_empty():
		return ""
	var current := _code_key()
	var matches: Array[String] = []
	for recipe_key in ELEMENTAL_RECIPES:
		if String(recipe_key).begins_with(current):
			var recipe: Dictionary = ELEMENTAL_RECIPES[recipe_key]
			matches.append(_element_label(StringName(recipe["element"])))
	if matches.size() == 1:
		return "RESSONÂNCIA: %s" % matches[0]
	if matches.size() > 1:
		return "RESSONÂNCIA: INSTÁVEL"
	return "FORMA ABERTA"

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
	# No First Playable, magia nasce da forma marcial, não de C.
	_unbind_key(&"p1_element", KEY_C)

func _restore_legacy_bindings() -> void:
	_bind_key(&"p1_attack", KEY_F)
	_bind_key(&"p1_push", KEY_G)
	_bind_key(&"p1_echo", KEY_H)
	_bind_key(&"p1_element", KEY_C)

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

func _build_flow_hud() -> void:
	if not is_instance_valid(_root):
		return
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var panel := PanelContainer.new()
	panel.name = "MartialFlowPanel"
	panel.position = Vector2(24, 118)
	panel.size = Vector2(430, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.028, 0.82)
	style.border_color = Color(0.78, 0.62, 0.28, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_combo_label_node = _flow_label("COMBO 0", 16, Color(0.96, 0.83, 0.42))
	_technique_label_node = _flow_label("GOLPE: —", 11, Color(0.92, 0.92, 0.86))
	_code_label_node = _flow_label("CÓDIGO: —", 11, Color(0.62, 0.86, 0.76))
	_flow_label_node = _flow_label("FLUXO: 0%", 11, Color(0.68, 0.86, 1.0))
	_resonance_label_node = _flow_label("", 10, Color(0.98, 0.62, 0.40))
	for label in [_combo_label_node, _technique_label_node, _code_label_node, _flow_label_node, _resonance_label_node]:
		column.add_child(label)
	_update_flow_hud()

func _flow_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _update_flow_hud() -> void:
	if is_instance_valid(_combo_label_node):
		_combo_label_node.text = "COMBO %d" % _combo_hits
	if is_instance_valid(_technique_label_node):
		_technique_label_node.text = "GOLPE: %s" % (_last_technique_name if not _last_technique_name.is_empty() else "—")
	if is_instance_valid(_code_label_node):
		_code_label_node.text = "CÓDIGO: %s" % _formatted_code()
	if is_instance_valid(_flow_label_node):
		_flow_label_node.text = "FLUXO: %d%%" % int(round(_flow))
	if is_instance_valid(_resonance_label_node):
		_resonance_label_node.text = _predicted_resonance()

func _formatted_code() -> String:
	if _code_families.is_empty():
		return "—"
	var parts: Array[String] = []
	for family in _code_families:
		parts.append(_family_label(family))
	return " → ".join(parts)

func _build_climax_overlay() -> void:
	if not is_instance_valid(_root):
		return
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	_climax_panel = PanelContainer.new()
	_climax_panel.name = "ElementalClimaxOverlay"
	_climax_panel.position = Vector2(380, 242)
	_climax_panel.size = Vector2(520, 132)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.022, 0.92)
	style.border_color = Color(0.96, 0.72, 0.22, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 18
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_climax_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(_climax_panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 5)
	_climax_panel.add_child(column)
	_climax_title = _flow_label("FORMA COMPLETA", 22, Color(0.96, 0.83, 0.42))
	_climax_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_climax_title)
	_climax_hint = _flow_label("Q ESQUIVA  •  R GUARDA/PARRY  •  MOVA-SE", 11, Color(0.92, 0.92, 0.86))
	_climax_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_climax_hint)
	_show_climax_overlay(false)

func _show_climax_overlay(visible: bool) -> void:
	if is_instance_valid(_climax_panel):
		_climax_panel.visible = visible
	if visible:
		_update_climax_text()

func _update_climax_text() -> void:
	if not is_instance_valid(_climax_title):
		return
	_climax_title.text = "%s  •  %s" % [_element_label(_pending_element), _pending_form_name]
	if is_instance_valid(_climax_hint):
		_climax_hint.text = "REAJA: Q ESQUIVA  •  R GUARDA/PARRY  •  %.2fs" % _climax_timer

func _set_readout(text: String) -> void:
	if is_instance_valid(_readout):
		_readout.text = text

func _input_combo_label(family: StringName, step: int) -> String:
	var key := "F" if family == &"tai" else ("G" if family == &"ji" else "H")
	return "%s  •  %s x%d" % [_family_label(family), key, step + 1]

func _family_label(family: StringName) -> String:
	match family:
		&"tai": return "TAI"
		&"ji": return "JI"
		_: return "FU"

func _element_label(element_id: StringName) -> String:
	match element_id:
		&"fire": return "FOGO"
		&"water": return "ÁGUA"
		&"earth": return "TERRA"
		&"air": return "AR"
		_: return "NEUTRO"

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
		"guard_reduces_damage_and_knockback": true,
		"dodge_negates_hit": true,
		"parry_negates_hit": true,
		"confirmed_hit_combo_counter": true,
		"martial_code_visible": true,
		"flow_energy_visible": true,
		"technique_name_visible": true,
		"elemental_recipes": ELEMENTAL_RECIPES.size(),
		"dedicated_magic_button": false,
		"climax_reaction_window_seconds": CLIMAX_REACTION_WINDOW,
		"defender_control_during_climax": true,
		"blocked_hit_does_not_advance_recipe": true,
		"evade_or_parry_breaks_code": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
