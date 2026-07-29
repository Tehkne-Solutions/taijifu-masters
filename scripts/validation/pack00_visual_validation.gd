extends Node2D

const WORLD_SIZE := Vector2(7680.0, 3240.0)
const CAMERA_MARGIN := Vector2(320.0, 220.0)
const MIN_ZOOM := 0.56
const EMERGENCY_ZOOM := 0.48
const MAX_ZOOM := 1.05
const PLAYER_COLORS := [
	Color("2f8cff"),
	Color("ff4a3d"),
	Color("ffc83d"),
	Color("45d47a")
]
const SHADOW_TEXTURE := preload("res://assets/pack_00_foundation/visual/contact_shadow.svg")
const CONTRAST_TEXTURE := preload("res://assets/pack_00_foundation/visual/local_contrast_overlay.svg")
const MARKER_TEXTURE := preload("res://assets/pack_00_foundation/visual/player_marker.svg")
const SILHOUETTE_TEXTURE := preload("res://assets/pack_00_foundation/visual/fighter_silhouette.svg")

@onready var camera: Camera2D = $Camera2D
@onready var fighters: Array[Node2D] = [
	$Fighters/P1,
	$Fighters/P2,
	$Fighters/P3,
	$Fighters/P4
]
@onready var metrics: Label = $HUD/Metrics

var _elapsed := 0.0

func _ready() -> void:
	camera.position = WORLD_SIZE * 0.5
	camera.zoom = Vector2.ONE * 0.72
	for index in fighters.size():
		_decorate_fighter(fighters[index], index)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_animate_test_fighters()
	_update_group_camera(delta)
	_update_metrics()
	queue_redraw()

func _decorate_fighter(fighter: Node2D, player_index: int) -> void:
	var color: Color = PLAYER_COLORS[player_index]

	var contrast := Sprite2D.new()
	contrast.name = "LocalContrastOverlay"
	contrast.texture = CONTRAST_TEXTURE
	contrast.position = Vector2(0.0, -48.0)
	contrast.scale = Vector2(1.15, 1.15)
	contrast.modulate = Color(1.0, 1.0, 1.0, 0.82)
	contrast.z_index = -3
	fighter.add_child(contrast)

	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = SHADOW_TEXTURE
	shadow.position = Vector2(0.0, 92.0)
	shadow.scale = Vector2(0.82, 0.72)
	shadow.z_index = -2
	fighter.add_child(shadow)

	var silhouette := Sprite2D.new()
	silhouette.name = "FighterSilhouette"
	silhouette.texture = SILHOUETTE_TEXTURE
	silhouette.position = Vector2(0.0, -18.0)
	silhouette.scale = Vector2(0.62, 0.62)
	silhouette.modulate = color
	silhouette.z_index = 0
	fighter.add_child(silhouette)

	var marker := Sprite2D.new()
	marker.name = "PlayerMarker"
	marker.texture = MARKER_TEXTURE
	marker.position = Vector2(0.0, -154.0)
	marker.scale = Vector2(0.58, 0.58)
	marker.modulate = color
	marker.z_index = 3
	fighter.add_child(marker)

	var label := Label.new()
	label.name = "PlayerLabel"
	label.text = "P%d" % (player_index + 1)
	label.position = Vector2(-31.0, -184.0)
	label.size = Vector2(62.0, 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.z_index = 4
	fighter.add_child(label)

func _animate_test_fighters() -> void:
	var center := WORLD_SIZE * 0.5
	var offsets := [
		Vector2(-760.0 + sin(_elapsed * 0.70) * 260.0, 260.0 + sin(_elapsed * 1.10) * 120.0),
		Vector2(-180.0 + sin(_elapsed * 0.83 + 1.0) * 320.0, -180.0 + cos(_elapsed * 0.91) * 180.0),
		Vector2(420.0 + cos(_elapsed * 0.62) * 360.0, 120.0 + sin(_elapsed * 0.78 + 2.0) * 220.0),
		Vector2(980.0 + sin(_elapsed * 0.55 + 3.0) * 280.0, -320.0 + cos(_elapsed * 0.66) * 160.0)
	]
	for index in fighters.size():
		fighters[index].position = center + offsets[index]
		var shadow := fighters[index].get_node_or_null("ContactShadow") as Sprite2D
		if shadow != null:
			var lift := absf(sin(_elapsed * (0.9 + index * 0.08)))
			shadow.scale = Vector2(0.82 - lift * 0.16, 0.72 - lift * 0.12)
			shadow.modulate.a = 1.0 - lift * 0.28

func _update_group_camera(delta: float) -> void:
	if fighters.is_empty():
		return
	var bounds := Rect2(fighters[0].global_position, Vector2.ZERO)
	for fighter in fighters:
		bounds = bounds.expand(fighter.global_position)
	bounds = bounds.grow_individual(CAMERA_MARGIN.x, CAMERA_MARGIN.y, CAMERA_MARGIN.x, CAMERA_MARGIN.y)
	var viewport_size := get_viewport_rect().size
	var zoom_x := viewport_size.x / maxf(bounds.size.x, 1.0)
	var zoom_y := viewport_size.y / maxf(bounds.size.y, 1.0)
	var desired_zoom := minf(zoom_x, zoom_y)
	var readable_zoom := clampf(desired_zoom, MIN_ZOOM, MAX_ZOOM)
	if desired_zoom < MIN_ZOOM:
		readable_zoom = maxf(desired_zoom, EMERGENCY_ZOOM)
	var target := bounds.get_center()
	target.x = clampf(target.x, viewport_size.x * 0.5 / readable_zoom, WORLD_SIZE.x - viewport_size.x * 0.5 / readable_zoom)
	target.y = clampf(target.y, viewport_size.y * 0.5 / readable_zoom, WORLD_SIZE.y - viewport_size.y * 0.5 / readable_zoom)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.5 * delta))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * readable_zoom, 1.0 - exp(-4.5 * delta))

func _update_metrics() -> void:
	metrics.text = "ARENA 4×3  •  CÂMERA DE GRUPO  •  ZOOM %.2f  •  4/4 VISÍVEIS" % camera.zoom.x

func _draw() -> void:
	_draw_world_layers()
	_draw_platforms()

func _draw_world_layers() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("24364a"))
	for band in 8:
		var y := 180.0 + band * 360.0
		var shade := Color(0.10 + band * 0.008, 0.16 + band * 0.006, 0.20 + band * 0.004, 1.0)
		draw_rect(Rect2(0.0, y, WORLD_SIZE.x, 210.0), shade)
	for column in 5:
		var x := column * 1920.0
		draw_line(Vector2(x, 0.0), Vector2(x, WORLD_SIZE.y), Color(1.0, 0.74, 0.24, 0.22), 5.0)
	for row in 4:
		var y := row * 1080.0
		draw_line(Vector2(0.0, y), Vector2(WORLD_SIZE.x, y), Color(1.0, 0.74, 0.24, 0.18), 5.0)

func _draw_platforms() -> void:
	var platforms := [
		Rect2(2500.0, 2100.0, 2680.0, 150.0),
		Rect2(2920.0, 1580.0, 920.0, 110.0),
		Rect2(4100.0, 1370.0, 1060.0, 110.0),
		Rect2(3440.0, 920.0, 720.0, 90.0),
		Rect2(5300.0, 1840.0, 860.0, 120.0)
	]
	for platform in platforms:
		draw_rect(platform, Color("374936"))
		draw_line(platform.position, platform.position + Vector2(platform.size.x, 0.0), Color("90b36c"), 10.0)
