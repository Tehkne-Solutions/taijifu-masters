class_name FirstPlayableArenaDressing
extends Node2D

const CANONICAL_ROOT := "res://assets/pack_03_stages/mountain_dojo_night"
const CANONICAL_FILES := [
	CANONICAL_ROOT + "/background.png",
	CANONICAL_ROOT + "/midground.png",
	CANONICAL_ROOT + "/foreground.png"
]

@onready var arena: FirstPlayableArena = get_node("../Arena")

var _elapsed := 0.0
var _canonical_presentation := false
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
	_canonical_presentation = _canonical_assets_ready()
	if _canonical_presentation:
		# C45: canonical stage art owns presentation. Collision stays in FirstPlayableArena;
		# legacy colored overlays/shrines/beacons must not paint over Mountain Dojo Night.
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false
		print("V2_PRESENTATION_LEGACY_DRESSING=RETIRED")
		return
	print("V2_PRESENTATION_LEGACY_DRESSING=FALLBACK")
	queue_redraw()

func _canonical_assets_ready() -> bool:
	for path in CANONICAL_FILES:
		if not ResourceLoader.exists(path, "Texture2D"):
			return false
	return true

func _process(delta: float) -> void:
	if _canonical_presentation:
		return
	_elapsed += delta
	queue_redraw()

func presentation_signature() -> Dictionary:
	return {
		"arena_id": &"mountain_dojo_night" if _canonical_presentation else &"triple_path_first_playable",
		"canonical_presentation": _canonical_presentation,
		"legacy_dressing_visible": not _canonical_presentation,
		"static_platform_overlays": 0 if _canonical_presentation else _surfaces.size(),
		"wall_overlays": 0 if _canonical_presentation else _walls.size(),
		"moving_platform_overlays": 0 if _canonical_presentation else 2,
		"spawn_shrines": 0 if _canonical_presentation else 2,
		"route_beacons": 0 if _canonical_presentation else 3,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	if _canonical_presentation:
		return
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

func _draw_walls() -> void:
	for rect in _walls:
		draw_rect(rect, Color(0.16, 0.15, 0.15, 1.0))
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), Color(0.44, 0.34, 0.25, 0.72))

func _draw_ruined_arches() -> void:
	var arch_centers := [Vector2(350, 850), Vector2(1450, 850), Vector2(2670, 850)]
	for arch_index in range(arch_centers.size()):
		var center: Vector2 = arch_centers[arch_index]
		var height := 150.0 if arch_index != 1 else 190.0
		_draw_column(center + Vector2(-76, 0), height, arch_index * 2)
		_draw_column(center + Vector2(76, 0), height * 0.92, arch_index * 2 + 1)
		draw_arc(center + Vector2(0, -height + 14), 78.0, PI, TAU, 30, Color(0.24, 0.23, 0.25, 0.94), 18.0)

func _draw_column(base: Vector2, height: float, seed: int) -> void:
	var width := 24.0 + float(seed % 3) * 3.0
	var top_y := base.y - height
	draw_rect(Rect2(base.x - width * 0.5, top_y, width, height), Color(0.18, 0.18, 0.20, 0.96))

func _draw_spawn_shrines() -> void:
	var shrines := [
		{"position": Vector2(245, 850), "color": Color(0.18, 0.60, 1.0, 0.82)},
		{"position": Vector2(2520, 850), "color": Color(1.0, 0.28, 0.12, 0.82)}
	]
	for shrine in shrines:
		var position: Vector2 = shrine["position"]
		var color: Color = shrine["color"]
		draw_rect(Rect2(position + Vector2(-42, -12), Vector2(84, 12)), Color(0.12, 0.11, 0.13, 0.96))
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
		draw_circle(position, pulse, Color(color, 0.18))

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

func _draw_moss_and_debris() -> void:
	for index in range(34):
		var x := 70.0 + index * 81.0
		var y := 846.0 - float((index * 13) % 9)
		draw_line(Vector2(x, y), Vector2(x + 12 + index % 8, y - 7 - index % 5), Color(0.18, 0.34, 0.22, 0.55), 3.0)

func _route_color(route_id: StringName) -> Color:
	match route_id:
		&"tai": return Color(0.20, 0.62, 0.96, 0.88)
		&"ji": return Color(0.92, 0.30, 0.16, 0.88)
		_: return Color(0.58, 0.32, 0.88, 0.88)

# Tehkné Solutions
