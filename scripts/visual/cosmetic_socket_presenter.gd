class_name CosmeticSocketPresenter
extends Node2D

var _fighter: FighterController
var _sprite_presenter: ProvisionalSpritePresenter
var _outcome: FighterOutcomeRuntime
var _loadout: Dictionary = {}
var _time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 7
	_fighter = get_parent() as FighterController
	_sprite_presenter = get_node_or_null("../SpritePresenter") as ProvisionalSpritePresenter
	_outcome = get_node_or_null("../OutcomeRuntime") as FighterOutcomeRuntime
	var character_id := _character_id()
	_loadout = CosmeticSocketCatalog.default_loadout(character_id)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func apply_loadout(loadout: Dictionary) -> void:
	_loadout = loadout.duplicate(true)
	queue_redraw()

func current_loadout() -> Dictionary:
	return _loadout.duplicate(true)

func current_item(socket_id: StringName) -> StringName:
	return StringName(_loadout.get(String(socket_id), "none"))

func loadout_summary() -> String:
	var parts: Array[String] = []
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		parts.append("%s: %s" % [
			CosmeticSocketCatalog.socket_label(socket_id),
			CosmeticSocketCatalog.item_label(current_item(socket_id))
		])
	return " • ".join(parts)

func _draw() -> void:
	if not is_instance_valid(_fighter):
		return
	var character_id := _character_id()
	var state_id := _state_id()
	var frame_index := _frame_index()
	var facing := _fighter.facing
	var visual := _outcome_visual()
	var visual_offset: Vector2 = visual.get("offset", Vector2.ZERO)
	var visual_rotation := float(visual.get("rotation", 0.0))
	var visual_scale: Vector2 = visual.get("scale", Vector2.ONE)
	var visual_alpha := float(visual.get("alpha", 1.0))

	draw_set_transform(visual_offset, visual_rotation, visual_scale)
	_draw_back_item(
		current_item(&"back"),
		CosmeticSocketCatalog.socket_position(character_id, &"back", state_id, frame_index, facing),
		facing,
		visual_alpha
	)
	_draw_head_item(
		current_item(&"head"),
		CosmeticSocketCatalog.socket_position(character_id, &"head", state_id, frame_index, facing),
		facing,
		visual_alpha
	)
	_draw_chest_item(
		current_item(&"chest"),
		CosmeticSocketCatalog.socket_position(character_id, &"chest", state_id, frame_index, facing),
		visual_alpha
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var pet_position := CosmeticSocketCatalog.socket_position(character_id, &"pet", state_id, frame_index, facing)
	if is_instance_valid(_outcome):
		pet_position = _outcome.transform_local_point(pet_position)
	_draw_pet(current_item(&"pet"), pet_position, facing, visual_alpha)

func _draw_head_item(item_id: StringName, position: Vector2, facing: float, alpha: float) -> void:
	match item_id:
		&"wind_circlet":
			draw_arc(position, 11.0, PI + 0.25, TAU - 0.25, 14, Color(0.45, 0.90, 1.0, alpha), 3.0)
			draw_circle(position + Vector2(0.0, -9.0), 2.4, Color(0.82, 0.98, 1.0, alpha))
		&"stone_crown":
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(-11.0, 2.0), position + Vector2(-9.0, -8.0),
				position + Vector2(-3.0, -3.0), position + Vector2(0.0, -11.0),
				position + Vector2(4.0, -3.0), position + Vector2(10.0, -8.0),
				position + Vector2(11.0, 2.0)
			]), Color(0.62, 0.54, 0.42, alpha))
		&"ember_horns":
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([
					position + Vector2(side * 5.0, 0.0),
					position + Vector2(side * 12.0, -10.0),
					position + Vector2(side * 9.0, 2.0)
				]), Color(1.0, 0.34, 0.12, alpha))
		&"moon_halo":
			draw_arc(position + Vector2(0.0, -7.0), 12.0, 0.0, TAU, 22, Color(0.83, 0.72, 1.0, alpha * 0.82), 3.0)
			draw_arc(position + Vector2(3.0 * facing, -7.0), 9.0, 0.0, TAU, 20, Color(0.06, 0.08, 0.16, alpha), 3.5)

func _draw_back_item(item_id: StringName, position: Vector2, facing: float, alpha: float) -> void:
	var sway := sin(_time * 5.0) * 4.0
	match item_id:
		&"flow_scarf":
			draw_polyline(PackedVector2Array([
				position,
				position + Vector2(-18.0 * facing, 4.0),
				position + Vector2((-34.0 - sway) * facing, 15.0),
				position + Vector2((-48.0 - sway) * facing, 9.0)
			]), Color(0.48, 0.88, 1.0, alpha * 0.84), 5.0, true)
		&"guardian_banner":
			draw_line(position, position + Vector2(0.0, 42.0), Color(0.27, 0.21, 0.16, alpha), 4.0)
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(0.0, 3.0), position + Vector2(-21.0 * facing, 8.0),
				position + Vector2(-18.0 * facing, 31.0), position + Vector2(0.0, 25.0)
			]), Color(0.72, 0.48, 0.20, alpha * 0.86))
		&"ember_mantle":
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(0.0, -3.0), position + Vector2(-18.0 * facing, 3.0),
				position + Vector2((-28.0 - sway) * facing, 35.0), position + Vector2(-4.0 * facing, 27.0)
			]), Color(0.88, 0.20, 0.10, alpha * 0.74))
		&"tide_ribbons":
			for index in range(2):
				var y_offset := float(index) * 8.0
				draw_polyline(PackedVector2Array([
					position + Vector2(0.0, y_offset),
					position + Vector2(-18.0 * facing, 7.0 + y_offset),
					position + Vector2((-38.0 - sway) * facing, 2.0 + y_offset)
				]), Color(0.32, 0.70 + index * 0.08, 1.0, alpha * (0.72 - index * 0.12)), 3.5, true)

func _draw_chest_item(item_id: StringName, position: Vector2, alpha: float) -> void:
	var color := Color(0.30, 0.86, 0.58, alpha)
	match item_id:
		&"ember_amulet": color = Color(1.0, 0.30, 0.10, alpha)
		&"tide_amulet": color = Color(0.24, 0.72, 1.0, alpha)
		&"earth_amulet": color = Color(0.68, 0.52, 0.28, alpha)
		&"none": return
	var pulse := 1.0 + sin(_time * 6.0) * 0.12
	draw_line(position + Vector2(0.0, -8.0), position, Color(0.84, 0.78, 0.62, alpha * 0.72), 1.5)
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(0.0, -5.0) * pulse,
		position + Vector2(5.0, 0.0) * pulse,
		position + Vector2(0.0, 7.0) * pulse,
		position + Vector2(-5.0, 0.0) * pulse
	]), color)

func _draw_pet(item_id: StringName, position: Vector2, facing: float, alpha: float) -> void:
	if item_id == &"none":
		return
	var bob := sin(_time * 4.0 + float(_fighter.player_index)) * 5.0
	position.y += bob
	match item_id:
		&"cloud_wisp":
			for offset in [Vector2(-6.0, 1.0), Vector2.ZERO, Vector2(7.0, 2.0)]:
				draw_circle(position + offset, 7.0, Color(0.68, 0.92, 1.0, alpha * 0.80))
			draw_circle(position + Vector2(2.0 * facing, -2.0), 2.0, Color(0.20, 0.38, 0.54, alpha))
		&"fox_spirit":
			draw_circle(position, 8.0, Color(0.94, 0.64, 0.28, alpha * 0.88))
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(-7.0, -5.0), position + Vector2(-4.0, -14.0), position + Vector2(0.0, -6.0)
			]), Color(1.0, 0.78, 0.42, alpha))
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(7.0, -5.0), position + Vector2(4.0, -14.0), position + Vector2(0.0, -6.0)
			]), Color(1.0, 0.78, 0.42, alpha))
			draw_arc(position + Vector2(-8.0 * facing, 5.0), 11.0, -1.2, 1.2, 12, Color(0.94, 0.64, 0.28, alpha), 4.0)
		&"stone_sprite":
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(-8.0, 5.0), position + Vector2(-6.0, -7.0),
				position + Vector2(0.0, -11.0), position + Vector2(8.0, -4.0),
				position + Vector2(7.0, 7.0)
			]), Color(0.58, 0.54, 0.48, alpha))
			draw_circle(position + Vector2(-3.0, -2.0), 1.5, Color(0.96, 0.78, 0.28, alpha))
			draw_circle(position + Vector2(3.0, -2.0), 1.5, Color(0.96, 0.78, 0.28, alpha))
		&"flame_salamander":
			draw_ellipse(position, Vector2(10.0, 5.5), Color(1.0, 0.32, 0.10, alpha * 0.90))
			draw_circle(position + Vector2(8.0 * facing, -1.0), 4.5, Color(1.0, 0.54, 0.18, alpha))
			draw_polyline(PackedVector2Array([
				position + Vector2(-8.0 * facing, 1.0),
				position + Vector2(-15.0 * facing, -3.0),
				position + Vector2(-20.0 * facing, 2.0)
			]), Color(1.0, 0.25, 0.08, alpha), 3.0, true)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _character_id() -> StringName:
	if is_instance_valid(_sprite_presenter):
		return _sprite_presenter.character_id()
	if is_instance_valid(_fighter) and is_instance_valid(_fighter.build):
		return _fighter.build.character_id
	return &"kael"

func _state_id() -> StringName:
	if is_instance_valid(_sprite_presenter):
		return _sprite_presenter.current_state_id()
	return &"idle"

func _frame_index() -> int:
	if is_instance_valid(_sprite_presenter):
		return _sprite_presenter.current_frame_index()
	return 0

func _outcome_visual() -> Dictionary:
	if is_instance_valid(_outcome):
		return _outcome.visual_transform()
	return {"offset": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "alpha": 1.0}
