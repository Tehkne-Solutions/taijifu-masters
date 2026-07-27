class_name FighterExpressionOverlay
extends Node2D

var _fighter: FighterController
var _outcome: FighterOutcomeRuntime
var _hurt_timer := 0.0
var _last_health := -1.0
var _preview_expression: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 9
	_fighter = get_parent() as FighterController
	_outcome = get_node_or_null("../OutcomeRuntime") as FighterOutcomeRuntime
	if is_instance_valid(_fighter):
		_last_health = _fighter.health
		if _fighter.has_signal("combat_state_changed"):
			_fighter.combat_state_changed.connect(_on_combat_state_changed)

func _process(delta: float) -> void:
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	queue_redraw()

func preview_expression(expression_id: StringName) -> void:
	_preview_expression = expression_id
	queue_redraw()

func clear_expression_preview() -> void:
	_preview_expression = &""

func current_expression_id() -> StringName:
	if _preview_expression != &"":
		return _preview_expression
	if is_instance_valid(_outcome) and _outcome.is_outcome_active():
		return _outcome.expression_id()
	if _hurt_timer > 0.0:
		return &"hurt"
	if not is_instance_valid(_fighter):
		return &"neutral"
	if is_instance_valid(_fighter._grabbed_by):
		return &"shock"
	if _fighter._is_blocking:
		return &"focus"
	if _fighter.health <= _fighter.build.max_health() * 0.25:
		return &"exhausted"
	if _fighter._attack_phase != FighterController.AttackPhase.NONE and is_instance_valid(_fighter._current_technique):
		match StringName(_fighter._current_technique.path):
			&"tai": return &"determined"
			&"ji": return &"fierce"
			&"fu": return &"flow"
	return &"neutral"

func _draw() -> void:
	if not is_instance_valid(_fighter):
		return
	var expression_id := current_expression_id()
	var face_center := Vector2(0.0, -48.0)
	var rotation_value := 0.0
	var scale_value := Vector2.ONE
	if is_instance_valid(_outcome):
		var visual := _outcome.visual_transform()
		face_center = _outcome.transform_local_point(face_center)
		rotation_value = float(visual.get("rotation", 0.0))
		scale_value = visual.get("scale", Vector2.ONE)
	draw_set_transform(face_center, rotation_value, scale_value)
	_draw_expression(expression_id)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_expression(expression_id: StringName) -> void:
	var ink := Color(0.045, 0.035, 0.07, 0.98)
	var accent := Color(0.78, 0.94, 1.0, 0.96)
	var brow_slant := 0.0
	var eye_scale := 1.0
	var mouth_curve := 0.0
	match expression_id:
		&"determined":
			brow_slant = -3.0
			eye_scale = 0.82
		&"fierce":
			brow_slant = -4.5
			eye_scale = 0.70
			mouth_curve = -1.5
			accent = Color(1.0, 0.42, 0.22)
		&"flow":
			brow_slant = -1.5
			eye_scale = 0.88
			mouth_curve = 1.0
			accent = Color(0.75, 0.48, 1.0)
		&"focus":
			brow_slant = -2.0
			eye_scale = 0.62
		&"hurt":
			brow_slant = 3.5
			eye_scale = 0.45
			mouth_curve = -3.0
			accent = Color(1.0, 0.34, 0.28)
		&"shock":
			eye_scale = 1.45
			mouth_curve = -4.5
			accent = Color(1.0, 0.82, 0.38)
		&"exhausted":
			brow_slant = 2.5
			eye_scale = 0.48
			mouth_curve = -2.5
			accent = Color(0.58, 0.72, 0.86)
		&"victory":
			brow_slant = -1.0
			eye_scale = 0.55
			mouth_curve = 4.0
			accent = Color(1.0, 0.86, 0.28)
		&"defeat":
			brow_slant = 4.0
			eye_scale = 0.34
			mouth_curve = -4.0
			accent = Color(0.52, 0.55, 0.68)
		_:
			mouth_curve = 1.0

	var facing := _fighter.facing
	draw_line(Vector2(-8.0, -6.0), Vector2(-1.5, -6.0 + brow_slant * facing), ink, 2.4)
	draw_line(Vector2(1.5, -6.0 - brow_slant * facing), Vector2(8.0, -6.0), ink, 2.4)
	if expression_id == &"victory":
		draw_arc(Vector2(-4.3, 0.0), 3.2, 0.15, PI - 0.15, 8, ink, 2.0)
		draw_arc(Vector2(4.3, 0.0), 3.2, 0.15, PI - 0.15, 8, ink, 2.0)
	elif expression_id == &"defeat":
		draw_line(Vector2(-7.0, -1.5), Vector2(-2.0, 2.0), ink, 2.0)
		draw_line(Vector2(-2.0, -1.5), Vector2(-7.0, 2.0), ink, 2.0)
		draw_line(Vector2(2.0, -1.5), Vector2(7.0, 2.0), ink, 2.0)
		draw_line(Vector2(7.0, -1.5), Vector2(2.0, 2.0), ink, 2.0)
	else:
		draw_ellipse(Vector2(-4.3, 0.0), Vector2(2.0, 2.8 * eye_scale), accent)
		draw_ellipse(Vector2(4.3, 0.0), Vector2(2.0, 2.8 * eye_scale), accent)

	if mouth_curve >= 0.0:
		draw_arc(Vector2(0.0, 5.0 - mouth_curve * 0.25), 4.5, 0.12, PI - 0.12, 10, ink, 1.8)
	else:
		draw_arc(Vector2(0.0, 8.0), 4.5 + absf(mouth_curve) * 0.25, PI + 0.12, TAU - 0.12, 10, ink, 1.8)

	if expression_id == &"shock":
		draw_circle(Vector2(0.0, 6.0), 2.4, ink)
		draw_line(Vector2(11.0, -8.0), Vector2(15.0, -13.0), accent, 2.0)
		draw_line(Vector2(12.0, -2.0), Vector2(18.0, -3.0), accent, 2.0)
	elif expression_id == &"exhausted":
		draw_circle(Vector2(10.0, -5.0), 2.0, Color(0.40, 0.75, 1.0, 0.78))
	elif expression_id == &"victory":
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.from_angle(angle)
			draw_line(Vector2(12.0, -10.0) + direction * 3.0, Vector2(12.0, -10.0) + direction * 7.0, accent, 1.8)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(14):
		var angle := TAU * float(index) / 14.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _on_combat_state_changed(_changed_fighter: FighterController) -> void:
	if not is_instance_valid(_fighter):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.01:
		_hurt_timer = 0.30
	_last_health = _fighter.health
