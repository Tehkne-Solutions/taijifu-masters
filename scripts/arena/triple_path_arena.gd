class_name TriplePathArena
extends Node2D

const WORLD_WIDTH := 2800.0
const WORLD_HEIGHT := 1050.0

var _platforms: Array[Dictionary] = []
var _moving_platform: AnimatableBody2D
var _moving_origin := Vector2(1420, 470)
var _elapsed := 0.0

var _manifestation_slots := [
	{"position": Vector2(720, 250), "type": &"tai", "color": Color(0.32, 0.72, 1.0)},
	{"position": Vector2(1260, 720), "type": &"ji", "color": Color(0.96, 0.45, 0.24)},
	{"position": Vector2(1960, 455), "type": &"fu", "color": Color(0.65, 0.38, 1.0)}
]
var _active_manifestation := 0
var _manifestation_timer := 0.0

func _ready() -> void:
	_build_blockout()
	_build_moving_platform()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_manifestation_timer += delta

	if is_instance_valid(_moving_platform):
		_moving_platform.position = _moving_origin + Vector2(sin(_elapsed * 0.85) * 240.0, cos(_elapsed * 1.15) * 85.0)

	if _active_manifestation < 0 and _manifestation_timer >= 5.5:
		_manifestation_timer = 0.0
		_active_manifestation = randi_range(0, _manifestation_slots.size() - 1)

	_collect_manifestation_if_reached()
	queue_redraw()

func _build_blockout() -> void:
	# Base de travessia.
	_create_static_platform(Rect2(-180, 850, 3160, 120), Color(0.15, 0.17, 0.22))

	# Rota superior — TAI: amplitude, saltos e risco de queda.
	_create_static_platform(Rect2(180, 560, 280, 28), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(570, 390, 250, 24), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(930, 270, 230, 24), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(2150, 285, 310, 24), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(2530, 470, 250, 24), Color(0.18, 0.38, 0.55))

	# Rota inferior — JI: contato, paredes e espaços controlados.
	_create_static_platform(Rect2(440, 710, 420, 26), Color(0.52, 0.24, 0.19))
	_create_static_platform(Rect2(930, 650, 380, 26), Color(0.52, 0.24, 0.19))
	_create_static_platform(Rect2(1540, 735, 470, 26), Color(0.52, 0.24, 0.19))
	_create_wall(Rect2(830, 560, 25, 176))
	_create_wall(Rect2(1305, 545, 25, 190))
	_create_wall(Rect2(2005, 575, 25, 186))

	# Rota central — FU: transição e mudança de altura.
	_create_static_platform(Rect2(60, 690, 230, 24), Color(0.38, 0.25, 0.55))
	_create_static_platform(Rect2(1160, 490, 250, 24), Color(0.38, 0.25, 0.55))
	_create_static_platform(Rect2(1740, 505, 300, 24), Color(0.38, 0.25, 0.55))
	_create_static_platform(Rect2(2250, 650, 270, 24), Color(0.38, 0.25, 0.55))

func _build_moving_platform() -> void:
	_moving_platform = AnimatableBody2D.new()
	_moving_platform.name = "MovingFuPlatform"
	_moving_platform.position = _moving_origin
	_moving_platform.collision_layer = 1
	_moving_platform.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(150, 22)
	shape.shape = rectangle
	_moving_platform.add_child(shape)
	add_child(_moving_platform)

func _create_static_platform(rect: Rect2, color: Color) -> void:
	_platforms.append({"rect": rect, "color": color})

	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 1

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _create_wall(rect: Rect2) -> void:
	_create_static_platform(rect, Color(0.26, 0.22, 0.20))

func _collect_manifestation_if_reached() -> void:
	if _active_manifestation < 0:
		return

	var slot: Dictionary = _manifestation_slots[_active_manifestation]
	var slot_position: Vector2 = to_global(slot.position)

	for node in get_tree().get_nodes_in_group("fighters"):
		if node is not FighterController:
			continue
		var fighter := node as FighterController
		if fighter.global_position.distance_to(slot_position) > 44.0:
			continue

		match slot.type:
			&"tai":
				fighter.stamina = minf(100.0, fighter.stamina + 38.0)
				fighter.velocity.y -= 170.0
			&"ji":
				fighter.posture = minf(fighter.build.max_posture(), fighter.posture + 42.0)
			&"fu":
				fighter.health = minf(fighter.build.max_health(), fighter.health + 14.0)
				fighter.stamina = minf(100.0, fighter.stamina + 18.0)

		_active_manifestation = -1
		_manifestation_timer = 0.0
		fighter.combat_state_changed.emit(fighter)
		break

func respawn_point(player_index: int) -> Vector2:
	return Vector2(240, 760) if player_index == 1 else Vector2(2520, 760)

func world_center() -> Vector2:
	return Vector2(WORLD_WIDTH * 0.5, 500)

func _draw() -> void:
	# Fundo em camadas provisórias para leitura do blockout.
	draw_rect(Rect2(-500, -200, 3800, 1300), Color(0.035, 0.045, 0.065))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-300, 580), Vector2(380, 260), Vector2(850, 580)]),
		Color(0.08, 0.12, 0.18)
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(1300, 610), Vector2(2050, 210), Vector2(2950, 610)]),
		Color(0.075, 0.11, 0.17)
	)

	for platform in _platforms:
		draw_rect(platform.rect, platform.color)
		draw_line(platform.rect.position, platform.rect.position + Vector2(platform.rect.size.x, 0), platform.color.lightened(0.22), 3.0)

	if is_instance_valid(_moving_platform):
		draw_rect(Rect2(_moving_platform.position - Vector2(75, 11), Vector2(150, 22)), Color(0.55, 0.36, 0.76))

	if _active_manifestation >= 0:
		var slot: Dictionary = _manifestation_slots[_active_manifestation]
		var pulse := 18.0 + sin(_elapsed * 4.0) * 4.0
		draw_circle(slot.position, pulse, Color(slot.color, 0.32))
		draw_arc(slot.position, pulse + 8.0, 0.0, TAU, 30, slot.color, 3.0)
