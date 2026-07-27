class_name FighterVisualOverlay
extends Node2D

var _fighter: FighterController
var _sprite_presenter: ProvisionalSpritePresenter
var _time := 0.0

func _ready() -> void:
	_fighter = get_parent() as FighterController
	_sprite_presenter = get_node_or_null("../SpritePresenter") as ProvisionalSpritePresenter
	z_index = 5

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_fighter):
		return
	var technique := _fighter._current_technique
	var path_id := &"neutral"
	if is_instance_valid(technique):
		path_id = StringName(technique.path)
	var path_color := CombatVisualCatalog.path_color(path_id)
	var weapon_color := CombatVisualCatalog.weapon_color(_fighter.equipped_weapon_id)
	var facing := _fighter.facing
	var attack_strength := TechniqueVisualTimeline.phase_energy(_fighter)
	var character_id := &"kael"
	var state_id := &"idle"
	var frame_index := 0
	if is_instance_valid(_sprite_presenter) and _sprite_presenter.has_active_sprite():
		character_id = _sprite_presenter.character_id()
		state_id = _sprite_presenter.current_state_id()
		frame_index = _sprite_presenter.current_frame_index()
	else:
		_draw_face_expression(path_color)
	var attachment := CharacterAttachmentCatalog.attachment(character_id, state_id, frame_index, facing)
	_draw_weapon_pose(weapon_color, path_id, facing, attack_strength, attachment)
	_draw_path_feedback(path_id, path_color, facing, attack_strength)
	_draw_state_feedback(path_color, facing)

func _draw_face_expression(path_color: Color) -> void:
	var brow_y := -55.0
	var eye_y := -49.0
	var ink := Color(0.035, 0.04, 0.065, 0.96)
	var slant := 0.0
	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		slant = -3.0
	elif _fighter._is_blocking:
		slant = 2.0
	if is_instance_valid(_fighter._grabbed_by):
		slant = 4.0
	draw_line(Vector2(-8.0, brow_y), Vector2(-1.5, brow_y + slant), ink, 2.4)
	draw_line(Vector2(1.5, brow_y + slant), Vector2(8.0, brow_y), ink, 2.4)
	draw_circle(Vector2(-4.3, eye_y), 1.5, path_color)
	draw_circle(Vector2(4.3, eye_y), 1.5, path_color)

func _draw_weapon_pose(
	color: Color,
	path_id: StringName,
	facing: float,
	strength: float,
	attachment: Dictionary
) -> void:
	match _fighter.equipped_weapon_id:
		&"training_staff":
			_draw_staff(color, path_id, facing, strength, attachment)
		&"wind_wraps":
			_draw_wind_wraps(color, path_id, facing, strength, attachment)
		&"seismic_gauntlets", &"breaker_gauntlets":
			_draw_gauntlets(color, path_id, facing, strength, attachment)
		_:
			_draw_unarmed(color, path_id, facing, strength, attachment)

func _draw_staff(color: Color, path_id: StringName, facing: float, strength: float, attachment: Dictionary) -> void:
	var hand: Vector2 = attachment.get("hand", Vector2(11.0 * facing, -21.0))
	var rear_hand: Vector2 = attachment.get("rear_hand", Vector2(-12.0 * facing, -25.0))
	var angle := float(attachment.get("angle", -0.56))
	var reach_scale := float(attachment.get("reach", 1.0))
	match path_id:
		&"tai":
			angle += 0.34
		&"ji":
			angle += 0.72
		&"fu":
			angle -= 0.22 + sin(_time * 8.0) * 0.06
	angle += TechniqueVisualTimeline.weapon_angle_offset(_fighter)
	var direction := Vector2(cos(angle) * facing, sin(angle))
	var tip := hand + direction * (68.0 + strength * 19.0) * reach_scale
	var back := rear_hand - direction * (20.0 + strength * 12.0)
	draw_line(back, tip, Color(0.07, 0.045, 0.03, 0.9), 8.0)
	draw_line(back, tip, color, 4.6)
	draw_circle(hand, 3.0, color.darkened(0.18))
	draw_circle(tip, 3.5, color.lightened(0.25))

func _draw_wind_wraps(color: Color, path_id: StringName, facing: float, strength: float, attachment: Dictionary) -> void:
	var phase := _time * 6.0
	var origin: Vector2 = attachment.get("hand", Vector2(16.0 * facing, -18.0))
	var rear_origin: Vector2 = attachment.get("rear_hand", Vector2(-13.0 * facing, -24.0))
	var reach_scale := float(attachment.get("reach", 1.0))
	var reach := (45.0 + strength * 24.0) * reach_scale
	if path_id == &"tai":
		reach += 16.0
	var ribbon_a := PackedVector2Array([
		origin,
		origin + Vector2(18.0 * facing, -18.0),
		origin + Vector2(reach * facing, sin(phase) * 13.0 - 5.0),
		origin + Vector2((reach + 18.0) * facing, cos(phase) * 8.0)
	])
	var ribbon_b := PackedVector2Array([
		rear_origin,
		rear_origin + Vector2(-15.0 * facing, 20.0),
		rear_origin + Vector2((-42.0 - strength * 10.0) * facing, sin(phase + 1.4) * 15.0)
	])
	draw_polyline(ribbon_a, color, 5.0, true)
	draw_polyline(ribbon_b, Color(color, 0.68), 3.2, true)

func _draw_gauntlets(color: Color, path_id: StringName, facing: float, strength: float, attachment: Dictionary) -> void:
	var hand: Vector2 = attachment.get("hand", Vector2(24.0 * facing, -15.0))
	var rear_hand: Vector2 = attachment.get("rear_hand", Vector2(-14.0 * facing, -24.0))
	var extension := Vector2((strength * 13.0 + 6.0) * facing, 0.0)
	if _fighter._attack_phase == FighterController.AttackPhase.RECOVERY:
		extension *= 0.25
	var lead := hand + extension
	var radius := 9.0 if path_id != &"ji" else 12.0
	if _fighter._attack_phase == FighterController.AttackPhase.ACTIVE:
		radius += 3.0
	draw_circle(lead, radius + 3.0, Color(0.04, 0.045, 0.06, 0.9))
	draw_circle(lead, radius, color)
	draw_circle(rear_hand, radius * 0.82, color.darkened(0.12))
	if path_id == &"ji":
		draw_rect(Rect2(lead.x - 9.0, lead.y + 8.0, 18.0, 6.0), color.lightened(0.18))

func _draw_unarmed(color: Color, path_id: StringName, facing: float, strength: float, attachment: Dictionary) -> void:
	var hand: Vector2 = attachment.get("hand", Vector2(24.0 * facing, -15.0))
	var rear_hand: Vector2 = attachment.get("rear_hand", Vector2(-18.0 * facing, -21.0))
	var lead := hand + Vector2((strength * 10.0) * facing, 0.0)
	draw_circle(lead, 5.5, color)
	if path_id == &"fu":
		draw_circle(rear_hand, 4.0, Color(color, 0.72))

func _draw_path_feedback(path_id: StringName, color: Color, facing: float, strength: float) -> void:
	if _fighter._attack_phase == FighterController.AttackPhase.NONE or path_id == &"neutral":
		return
	var effect_color := Color(color, 0.28 + strength * 0.52)
	match path_id:
		&"tai":
			for index in range(3):
				var y := -42.0 + index * 18.0
				draw_line(Vector2(-44.0 * facing, y), Vector2((-10.0 + strength * 18.0) * facing, y - 4.0), effect_color, 2.0 + index)
			draw_colored_polygon(PackedVector2Array([
				Vector2(18.0 * facing, -34.0),
				Vector2((55.0 + strength * 22.0) * facing, -18.0),
				Vector2(18.0 * facing, -2.0)
			]), Color(color, 0.18 + strength * 0.18))
		&"ji":
			var ground_y := 35.0
			for offset in [-24.0, -8.0, 10.0, 25.0]:
				draw_line(Vector2(offset, ground_y), Vector2(offset + facing * 8.0, ground_y - 8.0 - absf(offset) * 0.08), effect_color, 3.0)
			draw_arc(Vector2(18.0 * facing, -8.0), 28.0 + strength * 10.0, -1.2, 1.2, 12, effect_color, 6.0)
		&"fu":
			var pulse := 4.0 + sin(_time * 10.0) * 3.0
			draw_arc(Vector2.ZERO, 34.0 + pulse, -2.5, 1.8, 18, effect_color, 3.5)
			draw_arc(Vector2(8.0 * facing, -18.0), 48.0 - pulse, -0.6, 3.8, 20, Color(color, effect_color.a * 0.62), 2.4)

func _draw_state_feedback(color: Color, facing: float) -> void:
	if _fighter._is_blocking:
		draw_arc(Vector2(17.0 * facing, -18.0), 31.0, -1.25 if facing > 0 else 1.9, 1.25 if facing > 0 else 4.4, 14, Color(color, 0.76), 5.0)
	if _fighter._dodge_timer > 0.0:
		for index in range(3):
			var x := (-22.0 - index * 13.0) * facing
			draw_line(Vector2(x, -42.0), Vector2(x - 18.0 * facing, 24.0), Color(color, 0.42 - index * 0.09), 4.0)
	if is_instance_valid(_fighter._grabbed_target):
		draw_arc(Vector2(20.0 * facing, -18.0), 27.0, -1.4, 1.4, 14, Color(1.0, 0.48, 0.16, 0.86), 5.0)
