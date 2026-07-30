class_name FirstPlayableArenaDressing
extends Node2D

@onready var arena: FirstPlayableArena = get_node("../Arena")

var _elapsed := 0.0
var _surfaces: Array[Dictionary] = [
	{"rect": Rect2(180, 560, 280, 28), "route": &"tai"},
	{"rect": Rect2(570, 390, 250, 24), "route": &"tai"},
	{"rect": Rect2(930, 270, 230, 24), "route": &"tai"},
	{"rect": Rect2(2150, 285, 310, 24), "route": &"tai"},
	{"rect": Rect2(2530, 470, 250, 24), "route": &"tai"},
	{"rect": Rect2(440, 710, 420, 26), "route": &"ji"},
	{"rect": Rect2(930, 650, 380, 26), "route": &"ji"},
	{"rect": Rect2(1540, 735, 470, 26), "route": &"ji"},
	{"rect": Rect2(60, 690, 230, 24), "route": &"fu"},
	{"rect": Rect2(1160, 490, 250, 24), "route": &"fu"},
	{"rect": Rect2(1740, 505, 300, 24), "route": &"fu"},
	{"rect": Rect2(2250, 650, 270, 24), "route": &"fu"},
	{"rect": Rect2(2050, 790, 180, 22), "route": &"fu"},
	{"rect": Rect2(2320, 565, 165, 22), "route": &"tai"},
	{"rect": Rect2(2540, 350, 170, 22), "route": &"fu"}
]
var _walls: Array[Rect2] = [
	Rect2(830, 560, 25, 176),
	Rect2(1305, 545, 25, 190),
	Rect2(2005, 575, 25, 186)
]

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func presentation_signature() -> Dictionary:
	return {
		"arena_id": &"triple_path_first_playable",
		"ground_layers": 3,
		"static_platform_overlays": _surfaces.size(),
		"wall_overlays": _walls.size(),
		"moving_platform_overlays": 2,
		"spawn_shrines": 2,
		"route_beacons": 3,
		"ruin_columns": 10,
		"procedural_only": true,
		"collision_changes": false
	}

func _draw() -> void:
	_draw_ground_foundation()
	_draw_platform_surfaces()
	_draw_walls()
	_draw_ruined_arches()
	_draw_spawn_shrines()
	_draw_route_beacons()
	_draw_moving_platforms()
	_draw_moss_and_debris()

func _draw_ground_foundation() -> void:
	var ground := Rect2(-180, 850, 3160, 120)
	draw_rect(ground, Color(0.105, 0.115, 0.135, 0.98))
	draw_rect(Rect2(ground.position, Vector2(ground.size.x, 12)), Color(0.34, 0.37, 0.42, 0.94))
	draw_rect(Rect2(ground.position + Vector2(0, 12), Vector2(ground.size.x, 8)), Color(0.08, 0.09, 0.11, 0.95))
	for index in range(40):
		var x := -150.0 + index * 79.0
		var width := 48.0 + float((index * 17) % 29)
		draw_line(Vector2(x, 872), Vector2(x + width, 884 + (index % 3) * 8), Color(0.30, 0.31, 0.34, 0.42), 2.0)
	for index in range(18):
		var x := -100.0 + index * 174.0
		draw_line(Vector2(x, 850), Vector2(x + 28, 871), Color(0.04, 0.05, 0.06, 0.65), 3.0)

func _draw_platform_surfaces() -> void:
	for surface in _surfaces:
		var rect: Rect2 = surface["rect"]
		var route_id: StringName = surface["route"]
		var route_color := _route_color(route_id)
		var stone := Color(0.19, 0.20, 0.23, 0.98)
		draw_rect(rect, stone)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), route_color)
		draw_line(rect.position + Vector2(0, 7), rect.position + Vector2(rect.size.x, 7), route_color.lightened(0.28), 2.0)
		var blocks := maxi(2, int(rect.size.x / 54.0))
		for block in range(1, blocks):
			var block_x := rect.position.x + rect.size.x * float(block) / float(blocks)
			draw_line(Vector2(block_x, rect.position.y + 8), Vector2(block_x - 5, rect.end.y), Color(0.06, 0.07, 0.08, 0.72), 2.0)
		for chip in range(3):
			var chip_x := rect.position.x + 24.0 + fposmod(float(chip * 73 + int(rect.position.x)), maxf(30.0, rect.size.x - 48.0))
			draw_line(Vector2(chip_x, rect.position.y + 3), Vector2(chip_x + 13, rect.position.y + 10), Color(route_color, 0.44), 2.0)

func _draw_walls() -> void:
	for wall_index in range(_walls.size()):
		var rect := _walls[wall_index]
		draw_rect(rect, Color(0.16, 0.15, 0.15, 1.0))
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), Color(0.44, 0.34, 0.25, 0.72))
		for row in range(5):
			var y := rect.position.y + 16.0 + row * 31.0
			draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y + (row % 2) * 4), Color(0.06, 0.055, 0.055, 0.8), 2.0)
		var vine_color := Color(0.20, 0.38, 0.26, 0.78)
		var sway := sin(_elapsed * 0.8 + wall_index) * 4.0
		draw_polyline(PackedVector2Array([
			Vector2(rect.position.x + 8, rect.position.y),
			Vector2(rect.position.x + 13 + sway, rect.position.y + rect.size.y * 0.34),
			Vector2(rect.position.x + 7 - sway, rect.position.y + rect.size.y * 0.72)
		]), vine_color, 3.0)

func _draw_ruined_arches() -> void:
	var arch_centers := [Vector2(350, 850), Vector2(1450, 850), Vector2(2670, 850)]
	for arch_index in range(arch_centers.size()):
		var center: Vector2 = arch_centers[arch_index]
		var height := 150.0 if arch_index != 1 else 190.0
		_draw_column(center + Vector2(-76, 0), height, arch_index * 2)
		_draw_column(center + Vector2(76, 0), height * 0.92, arch_index * 2 + 1)
		draw_arc(center + Vector2(0, -height + 14), 78.0, PI, TAU, 30, Color(0.24, 0.23, 0.25, 0.94), 18.0)
		draw_arc(center + Vector2(0, -height + 14), 78.0, PI + 0.18, TAU - 0.22, 26, Color(0.50, 0.43, 0.34, 0.48), 3.0)
	# Quatro colunas quebradas adicionais distribuem profundidade sem colisão.
	_draw_column(Vector2(1020, 850), 92.0, 6)
	_draw_column(Vector2(1850, 850), 110.0, 7)
	_draw_column(Vector2(2220, 850), 78.0, 8)
	_draw_column(Vector2(2860, 850), 120.0, 9)

func _draw_column(base: Vector2, height: float, seed: int) -> void:
	var width := 24.0 + float(seed % 3) * 3.0
	var top_y := base.y - height
	draw_rect(Rect2(base.x - width * 0.5, top_y, width, height), Color(0.18, 0.18, 0.20, 0.96))
	draw_rect(Rect2(base.x - width * 0.72, top_y - 8, width * 1.44, 10), Color(0.29, 0.27, 0.25, 0.95))
	draw_rect(Rect2(base.x - width * 0.72, base.y - 9, width * 1.44, 9), Color(0.11, 0.11, 0.13, 0.98))
	for crack in range(3):
		var y := top_y + 24.0 + crack * height * 0.22
		var direction := -1.0 if (seed + crack) % 2 == 0 else 1.0
		draw_line(Vector2(base.x, y), Vector2(base.x + direction * width * 0.48, y + 13), Color(0.04, 0.04, 0.05, 0.78), 2.0)

func _draw_spawn_shrines() -> void:
	var shrines := [
		{"position": Vector2(245, 850), "color": Color(0.18, 0.60, 1.0, 0.82)},
		{"position": Vector2(2520, 850), "color": Color(1.0, 0.28, 0.12, 0.82)}
	]
	for shrine in shrines:
		var position: Vector2 = shrine["position"]
		var color: Color = shrine["color"]
		draw_rect(Rect2(position + Vector2(-42, -12), Vector2(84, 12)), Color(0.12, 0.11, 0.13, 0.96))
		draw_arc(position + Vector2(0, -14), 32.0, PI, TAU, 24, Color(color, 0.35), 5.0)
		draw_circle(position + Vector2(0, -20), 8.0 + sin(_elapsed * 2.4) * 1.5, Color(color, 0.30))

func _draw_route_beacons() -> void:
	var beacons := [
		{"position": Vector2(720, 347), "route": &"tai"},
		{"position": Vector2(1240, 710), "route": &"ji"},
		{"position": Vector2(1950, 507), "route": &"fu"}
	]
	for beacon in beacons:
		var position: Vector2 = beacon["position"]
		var color := _route_color(StringName(beacon["route"]))
		var pulse := 13.0 + sin(_elapsed * 2.2 + position.x * 0.01) * 2.5
		draw_line(position, position + Vector2(0, 48), Color(0.36, 0.30, 0.24, 0.88), 4.0)
		draw_circle(position, pulse, Color(color, 0.18))
		draw_arc(position, pulse + 5.0, 0.0, TAU, 20, Color(color, 0.72), 2.0)

func _draw_moving_platforms() -> void:
	if is_instance_valid(arena._moving_platform):
		_draw_moving_surface(arena._moving_platform.position, Vector2(150, 22), &"fu")
	if is_instance_valid(arena._vertical_platform):
		_draw_moving_surface(arena._vertical_platform.position, Vector2(135, 22), &"tai")

func _draw_moving_surface(center: Vector2, size: Vector2, route_id: StringName) -> void:
	var rect := Rect2(center - size * 0.5, size)
	var color := _route_color(route_id)
	draw_rect(rect, Color(0.17, 0.17, 0.21, 0.98))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), color)
	draw_line(rect.position + Vector2(12, 14), rect.end - Vector2(12, 6), Color(color, 0.42), 2.0)

func _draw_moss_and_debris() -> void:
	for index in range(34):
		var x := 70.0 + index * 81.0
		var y := 846.0 - float((index * 13) % 9)
		var moss := Color(0.18, 0.34, 0.22, 0.55)
		draw_line(Vector2(x, y), Vector2(x + 12 + index % 8, y - 7 - index % 5), moss, 3.0)
	for index in range(16):
		var x := 110.0 + index * 168.0
		var size := 4.0 + float(index % 4)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - size, 846), Vector2(x + size, 846), Vector2(x + size * 0.35, 838 - size)
		]), Color(0.24, 0.22, 0.20, 0.82))

func _route_color(route_id: StringName) -> Color:
	match route_id:
		&"tai":
			return Color(0.20, 0.62, 0.96, 0.88)
		&"ji":
			return Color(0.92, 0.30, 0.16, 0.88)
		_:
			return Color(0.58, 0.32, 0.88, 0.88)
