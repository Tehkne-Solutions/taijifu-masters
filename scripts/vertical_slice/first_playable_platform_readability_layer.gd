class_name FirstPlayablePlatformReadabilityLayer
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")

var _arena: FirstPlayableArena

var _surfaces: Array[Dictionary] = [
	{"rect": Rect2(260, 770, 360, 24), "route": &"tai"},
	{"rect": Rect2(760, 700, 340, 24), "route": &"fu"},
	{"rect": Rect2(1210, 620, 380, 24), "route": &"tai"},
	{"rect": Rect2(1710, 700, 340, 24), "route": &"ji"},
	{"rect": Rect2(2180, 770, 360, 24), "route": &"fu"}
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
		"moving_platforms": 0,
		"top_edge_highlight": true,
		"underside_face": true,
		"contact_shadow": true,
		"route_fu_uses_purple": false,
		"route_fu_palette": &"jade_gold",
		"simplified_first_playable_layout": true,
		"collision_changes": false,
		"physics_changes": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	for surface in _surfaces:
		_draw_surface(surface["rect"], StringName(surface["route"]))

func _draw_surface(rect: Rect2, route_id: StringName) -> void:
	var route_color := POLICY.route_color(route_id)
	var face_depth := clampf(rect.size.y * 0.72, 12.0, 18.0)

	draw_rect(
		Rect2(rect.position + Vector2(7, rect.size.y + 8), Vector2(rect.size.x - 2, face_depth + 8)),
		POLICY.PLATFORM_SHADOW
	)

	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(0, rect.size.y),
		rect.end,
		rect.end + Vector2(-10, face_depth),
		rect.position + Vector2(10, rect.size.y + face_depth)
	]), POLICY.PLATFORM_FACE)

	draw_rect(rect, POLICY.PLATFORM_STONE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), route_color)
	draw_line(
		rect.position + Vector2(4, 6),
		Vector2(rect.end.x - 4, rect.position.y + 6),
		route_color.lightened(0.28),
		2.0
	)

	if route_id == &"fu":
		draw_line(
			rect.position + Vector2(14, 10),
			Vector2(minf(rect.end.x - 14, rect.position.x + 58), rect.position.y + 10),
			POLICY.ROUTE_FU_ACCENT,
			2.0
		)

	var blocks := maxi(2, int(rect.size.x / 82.0))
	for block in range(1, blocks):
		var x := rect.position.x + rect.size.x * float(block) / float(blocks)
		draw_line(
			Vector2(x, rect.position.y + 9),
			Vector2(x - 5, rect.end.y - 2),
			Color(0.035, 0.040, 0.042, 0.72),
			2.0
		)

# Tehkné Solutions
