class_name FirstPlayableEnvironmentArt
extends TriplePathEnvironmentArt

func _ready() -> void:
	# O fundo precisa permanecer atrás do blockout, da camada de ruínas e dos
	# lutadores procedurais. O script original usa z=1 para o protótipo com atlas.
	z_index = -10
	queue_redraw()

func _draw_ink_mountains() -> void:
	# As silhuetas são fechadas por uma base inferior explícita. Isso evita a
	# aresta diagonal de fechamento atravessar o interior do polígono e gerar
	# falhas de triangulação no renderer headless.
	var far := PackedVector2Array([
		Vector2(-300, 520), Vector2(220, 245), Vector2(530, 480), Vector2(920, 185),
		Vector2(1320, 520), Vector2(1820, 205), Vector2(2200, 510), Vector2(2700, 220),
		Vector2(3200, 520), Vector2(3200, 690), Vector2(-300, 690)
	])
	draw_colored_polygon(far, Color(0.045, 0.075, 0.105, 0.72))
	var middle := PackedVector2Array([
		Vector2(-280, 600), Vector2(420, 360), Vector2(820, 590), Vector2(1260, 315),
		Vector2(1660, 590), Vector2(2200, 340), Vector2(2860, 600), Vector2(3240, 420),
		Vector2(3240, 720), Vector2(-280, 720)
	])
	draw_colored_polygon(middle, Color(0.065, 0.095, 0.125, 0.66))
	for segment in [
		[Vector2(210, 258), Vector2(520, 478)],
		[Vector2(910, 198), Vector2(1310, 510)],
		[Vector2(1810, 218), Vector2(2190, 500)],
		[Vector2(2690, 232), Vector2(3100, 510)]
	]:
		draw_line(segment[0], segment[1], Color(0.52, 0.72, 0.86, 0.15), 8.0)
