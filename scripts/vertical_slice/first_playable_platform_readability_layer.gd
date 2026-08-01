class_name FirstPlayablePlatformReadabilityLayer
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")

var _arena: FirstPlayableArena

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

func _ready() -> void:
	z_index = 3
	_arena = get_parent().get_node_or_null("Arena") as FirstPlayableArena
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func presentation_signature() -> Dictionary:
	return {
		"platform_readability": &"fighter_first_2_5d",
		"static_platforms": _surfaces.size(),
		"moving_platforms": 2,
		"top_edge_highlight": true,
		"underside_face": true,
		"contact_shadow": true,
		"route_fu_uses_purple": false,
		"route_fu_palette": &"jade_gold",
		"collision_changes": false,
		"physics_changes": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	for surface in _surfaces:
		_draw_surface(surface["rect"], StringName(surface["route"]))
	_draw_moving_platforms()

func _draw_surface(rect: Rect2, route_id: StringName) -> void:
	var route_color := POLICY.route_color(route_id)
	var face_depth := clampf(rect.size.y * 0.72, 12.0, 18.0)

	# Sombra de contato deslocada para separar a plataforma do cenário.
	draw_rect(
		Rect2(rect.position + Vector2(7, rect.size.y + 8), Vector2(rect.size.x - 2, face_depth + 8)),
		POLICY.PLATFORM_SHADOW
	)

	# Face frontal escura cria volume sem alterar a geometria física.
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(0, rect.size.y),
		rect.end,
		rect.end + Vector2(-10, face_depth),
		rect.position + Vector2(10, rect.size.y + face_depth)
	]), POLICY.PLATFORM_FACE)

	# Superfície jogável neutra; rota aparece apenas no edge-light.
	draw_rect(rect, POLICY.PLATFORM_STONE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), route_color)
	draw_line(
		rect.position + Vector2(4, 6),
		Vector2(rect.end.x - 4, rect.position.y + 6),
		route_color.lightened(0.28),
		2.0
	)

	# A rota FU usa jade e um detalhe dourado, nunca violeta/roxo.
	if route_id == &"fu":
		draw_line(
			rect.position + Vector2(14, 10),
			Vector2(minf(rect.end.x - 14, rect.position.x + 58), rect.position.y + 10),
			POLICY.ROUTE_FU_ACCENT,
			2.0
		)

	# Quebras de pedra discretas reforçam a leitura de material.
	var blocks := maxi(2, int(rect.size.x / 70.0))
	for block in range(1, blocks):
		var x := rect.position.x + rect.size.x * float(block) / float(blocks)
		draw_line(
			Vector2(x, rect.position.y + 9),
			Vector2(x - 5, rect.end.y - 2),
			Color(0.035, 0.040, 0.042, 0.72),
			2.0
		)

func _draw_moving_platforms() -> void:
	if not is_instance_valid(_arena):
		return
	if is_instance_valid(_arena._moving_platform):
		var size := Vector2(150, 22)
		_draw_surface(Rect2(_arena._moving_platform.position - size * 0.5, size), &"fu")
	if is_instance_valid(_arena._vertical_platform):
		var size := Vector2(135, 22)
		_draw_surface(Rect2(_arena._vertical_platform.position - size * 0.5, size), &"tai")

# Tehkné Solutions
