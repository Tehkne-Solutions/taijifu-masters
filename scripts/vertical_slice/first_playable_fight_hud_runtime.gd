class_name FirstPlayableFightHudRuntime
extends Node

## P0.2 fight-first HUD authority.
## Reframes the existing First Playable controls without changing combat logic:
## dominant health, thin secondary resources, isolated timer, compact difficulty,
## and the martial-code strip inside the top fight HUD instead of a dashboard.
## Tehkné Solutions

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const TOP_RESERVED_HEIGHT := 100.0
const HEALTH_HEIGHT := 16.0
const SECONDARY_HEIGHT := 5.0
const TIMER_FONT_SIZE := 34
const NAME_FONT_SIZE := 18
const MARTIAL_STRIP_RECT := Rect2(390.0, 74.0, 500.0, 24.0)
const P1_NAME_RECT := Rect2(24.0, 7.0, 410.0, 29.0)
const P2_NAME_RECT := Rect2(846.0, 7.0, 410.0, 29.0)
const P1_HEALTH_RECT := Rect2(24.0, 39.0, 410.0, HEALTH_HEIGHT)
const P2_HEALTH_RECT := Rect2(846.0, 39.0, 410.0, HEALTH_HEIGHT)
const P1_POSTURE_RECT := Rect2(24.0, 61.0, 410.0, SECONDARY_HEIGHT)
const P2_POSTURE_RECT := Rect2(846.0, 61.0, 410.0, SECONDARY_HEIGHT)
const P1_STAMINA_RECT := Rect2(24.0, 71.0, 410.0, SECONDARY_HEIGHT)
const P2_STAMINA_RECT := Rect2(846.0, 71.0, 410.0, SECONDARY_HEIGHT)
const TIMER_RECT := Rect2(520.0, 3.0, 240.0, 48.0)
const STATE_RECT := Rect2(520.0, 48.0, 240.0, 22.0)

var _match: FirstPlayableController
var _hud: CanvasLayer
var _layout_applied := false
var _martial_strip_bound := false

func _ready() -> void:
	process_priority = 160
	_match = get_parent() as FirstPlayableController
	call_deferred("_resolve_surfaces")

func _process(_delta: float) -> void:
	_resolve_surfaces()
	if not _layout_applied:
		_apply_layout()
	_bind_martial_strip()
	_update_semantics()

func _resolve_surfaces() -> void:
	if not is_instance_valid(_match):
		_match = get_parent() as FirstPlayableController
	if is_instance_valid(_match) and not is_instance_valid(_hud):
		_hud = _match.get_node_or_null("HUD") as CanvasLayer

func _apply_layout() -> void:
	if not is_instance_valid(_hud):
		return
	var top := _hud.get_node_or_null("TopShade") as ColorRect
	if top != null:
		top.position = Vector2.ZERO
		top.size = Vector2(1280.0, TOP_RESERVED_HEIGHT)
		top.color = Color(POLICY.INK, 0.68)

	var bottom := _hud.get_node_or_null("BottomShade") as CanvasItem
	if bottom != null:
		bottom.visible = false
	var controls := _hud.get_node_or_null("Controls") as CanvasItem
	if controls != null:
		controls.visible = false
	var difficulty := _hud.get_node_or_null("DifficultyInfo") as CanvasItem
	if difficulty != null:
		difficulty.visible = false

	_set_control_rect("PlayerOne", P1_NAME_RECT)
	_set_control_rect("PlayerTwo", P2_NAME_RECT)
	_set_control_rect("P1Health", P1_HEALTH_RECT)
	_set_control_rect("P2Health", P2_HEALTH_RECT)
	_set_control_rect("P1Posture", P1_POSTURE_RECT)
	_set_control_rect("P2Posture", P2_POSTURE_RECT)
	_set_control_rect("P1Stamina", P1_STAMINA_RECT)
	_set_control_rect("P2Stamina", P2_STAMINA_RECT)
	_set_control_rect("CenterInfo", TIMER_RECT)
	_set_control_rect("StateInfo", STATE_RECT)

	var p1 := _hud.get_node_or_null("PlayerOne") as Label
	if p1 != null:
		p1.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
		p1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var p2 := _hud.get_node_or_null("PlayerTwo") as Label
	if p2 != null:
		p2.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
		p2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var timer := _hud.get_node_or_null("CenterInfo") as Label
	if timer != null:
		timer.add_theme_font_size_override("font_size", TIMER_FONT_SIZE)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var state := _hud.get_node_or_null("StateInfo") as Label
	if state != null:
		state.add_theme_font_size_override("font_size", 10)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.add_theme_color_override("font_color", Color(POLICY.BONE, 0.76))

	_layout_applied = true
	print("P0_2_FIGHT_HUD_LAYOUT=PASS top_reserved_px=%.0f timer=isolated controls=persistent_false" % TOP_RESERVED_HEIGHT)

func _bind_martial_strip() -> void:
	if _martial_strip_bound or not is_instance_valid(_match):
		return
	var runtime := _match.get_node_or_null("FirstPlayableMartialHudRuntime")
	if runtime == null:
		return
	var strip := runtime.get_node_or_null("MartialHudLayer/MartialCodeStrip") as Label
	if strip == null:
		return
	strip.position = MARTIAL_STRIP_RECT.position
	strip.size = MARTIAL_STRIP_RECT.size
	strip.add_theme_font_size_override("font_size", 10)
	strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_martial_strip_bound = true
	print("P0_2_FIGHT_HUD_MARTIAL_STRIP=PASS integrated_top=true")

func _update_semantics() -> void:
	if not is_instance_valid(_match) or not is_instance_valid(_hud):
		return
	if not is_instance_valid(_match.player_one) or not is_instance_valid(_match.player_two):
		return
	var p1 := _hud.get_node_or_null("PlayerOne") as Label
	var p2 := _hud.get_node_or_null("PlayerTwo") as Label
	if p1 != null:
		p1.text = "P1  •  %s" % _match.player_one.build.character_name.to_upper()
	if p2 != null:
		p2.text = "CPU  •  %s" % _match.player_two.build.character_name.to_upper()

	if int(_match.get("_state")) != FirstPlayableController.MatchState.BATTLE:
		return
	var timer := _hud.get_node_or_null("CenterInfo") as Label
	if timer != null:
		timer.text = "%02d" % ceili(float(_match.get("_time_remaining")))
	var state := _hud.get_node_or_null("StateInfo") as Label
	if state != null:
		var difficulty_label := ""
		if is_instance_valid(_match.difficulty_controller):
			difficulty_label = _match.difficulty_controller.current_label().to_upper()
		state.text = "IA  •  %s" % difficulty_label

func _set_control_rect(path: String, rect: Rect2) -> void:
	var control := _hud.get_node_or_null(path) as Control
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size

func surface_signature() -> Dictionary:
	var strip_rect := Rect2()
	var strip_visible := false
	if is_instance_valid(_match):
		var runtime := _match.get_node_or_null("FirstPlayableMartialHudRuntime")
		if runtime != null:
			var strip := runtime.get_node_or_null("MartialHudLayer/MartialCodeStrip") as Label
			if strip != null:
				strip_rect = Rect2(strip.position, strip.size)
				strip_visible = strip.visible
	return {
		"layout_applied": _layout_applied,
		"top_reserved_height": TOP_RESERVED_HEIGHT,
		"timer_rect": _rect_array(TIMER_RECT),
		"state_rect": _rect_array(STATE_RECT),
		"p1_health_rect": _rect_array(P1_HEALTH_RECT),
		"p2_health_rect": _rect_array(P2_HEALTH_RECT),
		"martial_strip_rect": _rect_array(strip_rect),
		"martial_strip_visible": strip_visible,
		"persistent_controls_visible": _visible("Controls"),
		"persistent_difficulty_visible": _visible("DifficultyInfo"),
		"bottom_shade_visible": _visible("BottomShade"),
		"signature": "Tehkné Solutions",
	}

func presentation_signature() -> Dictionary:
	return {
		"runtime": "first_playable_fight_hud_runtime_v1",
		"fight_first_hierarchy": true,
		"health_primary": true,
		"posture_secondary": true,
		"stamina_secondary": true,
		"timer_isolated": true,
		"difficulty_secondary": true,
		"fighter_names_single_line": true,
		"martial_strip_integrated_top": true,
		"persistent_keyboard_help": false,
		"bottom_dashboard": false,
		"top_reserved_height": TOP_RESERVED_HEIGHT,
		"logic_changes": false,
		"damage_changes": false,
		"frame_data_changes": false,
		"signature": "Tehkné Solutions",
	}

func _visible(path: String) -> bool:
	if not is_instance_valid(_hud):
		return false
	var item := _hud.get_node_or_null(path) as CanvasItem
	return item != null and item.visible

func _rect_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

# Tehkné Solutions