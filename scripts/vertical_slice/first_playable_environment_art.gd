class_name FirstPlayableEnvironmentArt
extends TriplePathEnvironmentArt

const FINAL_LAYER := preload("res://scripts/vertical_slice/first_playable_arena_final_layer.gd")

func _ready() -> void:
	# Fundo atrás do blockout, das ruínas e dos lutadores.
	z_index = -10
	_install_final_layer()
	queue_redraw()

func _install_final_layer() -> void:
	var root := get_parent()
	if root == null or root.has_node("ArenaFinalLayer"):
		return
	var final_layer := FINAL_LAYER.new() as FirstPlayableArenaFinalLayer
	final_layer.name = "ArenaFinalLayer"
	root.add_child.call_deferred(final_layer)

func presentation_signature() -> Dictionary:
	return {
		"sky_layers": 4,
		"mountain_layers": 2,
		"celestial_body": &"water_moon",
		"mist_bands": 3,
		"palette": &"ink_stone_jade_ember_gold",
		"purple_tech_glow": false,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	_draw_sky_wash()
	_draw_water_moon()
	_draw_ink_mountains()
	_draw_distant_temples()
	_draw_mist_bands()

func _draw_sky_wash() -> void:
	draw_rect(Rect2(-400, -120, 3800, 1080), Color(0.028, 0.050, 0.064, 1.0))
	draw_rect(Rect2(-400, 120, 3800, 840), Color(0.060, 0.092, 0.100, 0.76))
	draw_rect(Rect2(-400, 360, 3800, 600), Color(0.110, 0.135, 0.125, 0.36))
	draw_rect(Rect2(-400, 600, 3800, 360), Color(0.34, 0.25, 0.17, 0.12))

func _draw_water_moon() -> void:
	var center := Vector2(2380, 185)
	draw_circle(center, 112.0, Color(0.82, 0.88, 0.78, 0.10))
	draw_circle(center, 78.0, Color(0.88, 0.90, 0.76, 0.70))
	draw_circle(center + Vector2(25, -14), 74.0, Color(0.035, 0.062, 0.074, 0.88))
	for ring in range(3):
		draw_arc(center, 126.0 + ring * 15.0, PI * 0.12, PI * 1.76, 42, Color(0.62, 0.76, 0.70, 0.08), 3.0)

func _draw_ink_mountains() -> void:
	var far := PackedVector2Array([
		Vector2(-300, 520), Vector2(220, 245), Vector2(530, 480), Vector2(920, 185),
		Vector2(1320, 520), Vector2(1820, 205), Vector2(2200, 510), Vector2(2700, 220),
		Vector2(3200, 520), Vector2(3200, 690), Vector2(-300, 690)
	])
	draw_colored_polygon(far, Color(0.035, 0.060, 0.072, 0.82))
	var middle := PackedVector2Array([
		Vector2(-280, 600), Vector2(420, 360), Vector2(820, 590), Vector2(1260, 315),
		Vector2(1660, 590), Vector2(2200, 340), Vector2(2860, 600), Vector2(3240, 420),
		Vector2(3240, 720), Vector2(-280, 720)
	])
	draw_colored_polygon(middle, Color(0.065, 0.085, 0.086, 0.78))
	for segment in [
		[Vector2(210, 258), Vector2(520, 478)],
		[Vector2(910, 198), Vector2(1310, 510)],
		[Vector2(1810, 218), Vector2(2190, 500)],
		[Vector2(2690, 232), Vector2(3100, 510)]
	]:
		draw_line(segment[0], segment[1], Color(0.64, 0.76, 0.68, 0.12), 8.0)

func _draw_distant_temples() -> void:
	for temple in [Vector2(460, 405), Vector2(1510, 388), Vector2(2860, 430)]:
		draw_rect(Rect2(temple + Vector2(-28, 0), Vector2(56, 58)), Color(0.025, 0.038, 0.042, 0.72))
		draw_colored_polygon(PackedVector2Array([
			temple + Vector2(-76, 4), temple + Vector2(0, -30), temple + Vector2(76, 4),
			temple + Vector2(48, 13), temple + Vector2(-48, 13)
		]), Color(0.025, 0.038, 0.042, 0.76))
		draw_line(temple + Vector2(0, -30), temple + Vector2(0, -65), Color(0.34, 0.25, 0.15, 0.34), 3.0)

func _draw_mist_bands() -> void:
	for band in range(3):
		var y := 520.0 + band * 72.0
		var alpha := 0.11 - band * 0.02
		for segment in range(8):
			var x := -260.0 + segment * 470.0 + band * 110.0
			draw_circle(Vector2(x, y), 210.0 + band * 22.0, Color(0.64, 0.72, 0.68, alpha))

# Tehkné Solutions
