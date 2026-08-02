class_name PreparationAvatarPreview
extends Control

var _loadout: Dictionary = {}
var _character_id: StringName = &"kael"
var _texture: Texture2D
var _frame_index := 0
var _frame_timer := 0.0
var _time := 0.0
var _player_index := 1

func _ready() -> void:
	custom_minimum_size = Vector2(218.0, 218.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_player_index(player_index: int) -> void:
	_player_index = clampi(player_index, 1, 2)

func apply_loadout(loadout: Dictionary) -> void:
	_loadout = loadout.duplicate(true)
	_character_id = StringName(_loadout.get("character_id", &"kael"))
	var path := CharacterVisualCatalog.sheet_path(_character_id)
	_texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_frame_index = 0
	_frame_timer = 0.0
	queue_redraw()

func current_loadout() -> Dictionary:
	return _loadout.duplicate(true)

func displayed_item(socket_id: StringName) -> StringName:
	return StringName(_loadout.get(String(socket_id), &"none"))

func _process(delta: float) -> void:
	_time += delta
	_frame_timer += delta
	var frame_duration := 1.0 / CharacterVisualCatalog.fps_for(_character_id, &"idle")
	while _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index = wrapi(_frame_index + 1, 0, CharacterVisualCatalog.columns(_character_id))
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.57)
	var accent := Color(0.32, 0.72, 1.0, 0.24) if _player_index == 1 else Color(1.0, 0.36, 0.20, 0.24)
	draw_circle(center + Vector2(0.0, 35.0), 74.0, Color(0.025, 0.045, 0.075, 0.92))
	draw_arc(center + Vector2(0.0, 35.0), 72.0, 0.0, TAU, 48, accent, 3.0)
	_draw_ellipse_polygon(center + Vector2(0.0, 79.0), Vector2(48.0, 8.0), Color(0.0, 0.0, 0.0, 0.32))

	var scale_factor := 1.38
	var facing := 1.0 if _player_index == 1 else -1.0
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	var back_position := CosmeticSocketCatalog.socket_position(_character_id, &"back", &"idle", _frame_index, facing)
	_draw_back_item(displayed_item(&"back"), back_position, facing, 1.0)
	if is_instance_valid(_texture):
		var source := Rect2(
			Vector2(_frame_index * CharacterVisualCatalog.FRAME_SIZE.x, 0.0),
			CharacterVisualCatalog.FRAME_SIZE
		)
		draw_texture_rect_region(
			_texture,
			Rect2(Vector2(-64.0, -81.0), CharacterVisualCatalog.FRAME_SIZE),
			source
		)
	else:
		_draw_fallback_body(facing)
	_draw_head_item(
		displayed_item(&"head"),
		CosmeticSocketCatalog.socket_position(_character_id, &"head", &"idle", _frame_index, facing),
		facing,
		1.0
	)
	_draw_chest_item(
		displayed_item(&"chest"),
		CosmeticSocketCatalog.socket_position(_character_id, &"chest", &"idle", _frame_index, facing),
		1.0
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var pet_local := CosmeticSocketCatalog.socket_position(_character_id, &"pet", &"idle", _frame_index, facing)
	var pet_position := center + pet_local * scale_factor
	_draw_pet(displayed_item(&"pet"), pet_position, facing, 1.0)

func _draw_fallback_body(facing: float) -> void:
	var color := Color(0.38, 0.66, 0.92) if _player_index == 1 else Color(0.90, 0.36, 0.22)
	draw_circle(Vector2(0.0, -49.0), 13.0, color)
	draw_rect(Rect2(-14.0, -36.0, 28.0, 46.0), color)
	draw_line(Vector2(-8.0, 5.0), Vector2(-13.0, 34.0), color, 8.0)
	draw_line(Vector2(8.0, 5.0), Vector2(13.0, 34.0), color, 8.0)
	draw_line(Vector2(-12.0, -26.0), Vector2(-27.0 * facing, -4.0), color, 7.0)
	draw_line(Vector2(12.0, -26.0), Vector2(30.0 * facing, -14.0), color, 7.0)

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
	position.y += sin(_time * 4.0 + float(_player_index)) * 5.0
	match item_id:
		&"cloud_wisp":
			for offset in [Vector2(-6.0, 1.0), Vector2.ZERO, Vector2(7.0, 2.0)]:
				draw_circle(position + offset, 7.0, Color(0.68, 0.92, 1.0, alpha * 0.80))
			draw_circle(position + Vector2(2.0 * facing, -2.0), 2.0, Color(0.20, 0.38, 0.54, alpha))
		&"fox_spirit":
			draw_circle(position, 8.0, Color(0.94, 0.64, 0.28, alpha * 0.88))
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([
					position + Vector2(side * 7.0, -5.0),
					position + Vector2(side * 4.0, -14.0),
					position + Vector2(0.0, -6.0)
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
			_draw_ellipse_polygon(position, Vector2(10.0, 5.5), Color(1.0, 0.32, 0.10, alpha * 0.90))
			draw_circle(position + Vector2(8.0 * facing, -1.0), 4.5, Color(1.0, 0.54, 0.18, alpha))
			draw_polyline(PackedVector2Array([
				position + Vector2(-8.0 * facing, 1.0),
				position + Vector2(-15.0 * facing, -3.0),
				position + Vector2(-20.0 * facing, 2.0)
			]), Color(1.0, 0.25, 0.08, alpha), 3.0, true)

func _draw_ellipse_polygon(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
