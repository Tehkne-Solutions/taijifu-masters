class_name TriplePathArena
extends Node2D

signal sector_shifted(stage: int, boundary_x: float)

const WORLD_WIDTH := 2800.0
const WORLD_HEIGHT := 1050.0
const CLOSURE_START_SECONDS := 16.0

@export var show_strategic_points := true

var _platforms: Array[Dictionary] = []
var _moving_platform: AnimatableBody2D
var _vertical_platform: AnimatableBody2D
var _moving_origin := Vector2(1420, 470)
var _vertical_origin := Vector2(2380, 735)
var _elapsed := 0.0
var _battle_active := false

var _closure_stage := 0
var _left_boundary := -180.0
var _pressure_cooldowns := {1: 0.0, 2: 0.0}

var _manifestation_slots := [
	{"position": Vector2(720, 250), "type": &"tai", "color": Color(0.32, 0.72, 1.0)},
	{"position": Vector2(1260, 720), "type": &"ji", "color": Color(0.96, 0.45, 0.24)},
	{"position": Vector2(1960, 455), "type": &"fu", "color": Color(0.65, 0.38, 1.0)}
]
var _active_manifestation := 0
var _manifestation_timer := 0.0

## Pontos de intenção para IA, telemetria e futuras missões. Eles não são
## caminhos rígidos: cada ponto descreve onde uma estratégia tende a funcionar.
var _strategic_points: Array[Dictionary] = [
	{"id": &"tai_west_terrace", "route": &"tai", "role": &"high_ground", "position": Vector2(700, 345), "risk": 0.32},
	{"id": &"tai_central_overlook", "route": &"tai", "role": &"range", "position": Vector2(1050, 225), "risk": 0.58},
	{"id": &"tai_final_arch", "route": &"tai", "role": &"high_ground", "position": Vector2(2300, 240), "risk": 0.46},
	{"id": &"tai_east_landing", "route": &"tai", "role": &"recovery", "position": Vector2(2630, 420), "risk": 0.62},
	{"id": &"ji_west_corridor", "route": &"ji", "role": &"choke", "position": Vector2(650, 665), "risk": 0.20},
	{"id": &"ji_center_wall", "route": &"ji", "role": &"control", "position": Vector2(1110, 610), "risk": 0.28},
	{"id": &"ji_east_corridor", "route": &"ji", "role": &"choke", "position": Vector2(1780, 690), "risk": 0.34},
	{"id": &"fu_west_transition", "route": &"fu", "role": &"transition", "position": Vector2(190, 645), "risk": 0.18},
	{"id": &"fu_moving_crossing", "route": &"fu", "role": &"transition", "position": Vector2(1390, 445), "risk": 0.42},
	{"id": &"fu_manifestation_lane", "route": &"fu", "role": &"resource", "position": Vector2(1960, 455), "risk": 0.36},
	{"id": &"fu_vertical_gate", "route": &"fu", "role": &"ascent", "position": Vector2(2290, 610), "risk": 0.40},
	{"id": &"fu_final_step", "route": &"fu", "role": &"ascent", "position": Vector2(2590, 310), "risk": 0.55}
]

func _ready() -> void:
	_build_blockout()
	_build_moving_platforms()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta if _battle_active else delta * 0.22

	if is_instance_valid(_moving_platform):
		_moving_platform.position = _moving_origin + Vector2(
			sin(_elapsed * 0.85) * 240.0,
			cos(_elapsed * 1.15) * 85.0
		)

	if is_instance_valid(_vertical_platform):
		_vertical_platform.position = _vertical_origin + Vector2(
			sin(_elapsed * 0.62) * 62.0,
			-sin(_elapsed * 0.78) * 275.0
		)

	if _battle_active:
		_manifestation_timer += delta
		_update_closure(delta)
		_update_pressure_cooldowns(delta)

		if _active_manifestation < 0 and _manifestation_timer >= 5.5:
			_manifestation_timer = 0.0
			_active_manifestation = randi_range(0, _manifestation_slots.size() - 1)

		_collect_manifestation_if_reached()
	queue_redraw()

func start_battle_flow() -> void:
	_battle_active = true
	_elapsed = 0.0
	_closure_stage = 0
	_left_boundary = -180.0
	_manifestation_timer = 0.0
	_active_manifestation = 0
	_pressure_cooldowns = {1: 0.0, 2: 0.0}
	sector_shifted.emit(_closure_stage, _left_boundary)
	queue_redraw()

func reset_battle_flow() -> void:
	start_battle_flow()

func _update_closure(delta: float) -> void:
	var next_stage := 0
	var target_boundary := -180.0
	var speed := 0.0

	if _elapsed >= CLOSURE_START_SECONDS and _elapsed < 28.0:
		next_stage = 1
		target_boundary = 720.0
		speed = 78.0
	elif _elapsed >= 28.0 and _elapsed < 38.0:
		next_stage = 2
		target_boundary = 720.0
		speed = 40.0
	elif _elapsed >= 38.0 and _elapsed < 54.0:
		next_stage = 3
		target_boundary = 1510.0
		speed = 52.0
	elif _elapsed >= 54.0:
		next_stage = 4
		target_boundary = 1510.0
		speed = 40.0

	_left_boundary = move_toward(_left_boundary, target_boundary, speed * delta)
	if next_stage != _closure_stage:
		_closure_stage = next_stage
		sector_shifted.emit(_closure_stage, _left_boundary)

func _update_pressure_cooldowns(delta: float) -> void:
	for player_index in _pressure_cooldowns.keys():
		_pressure_cooldowns[player_index] = maxf(0.0, float(_pressure_cooldowns[player_index]) - delta)

func apply_sector_pressure(fighter: FighterController) -> void:
	if not _battle_active or _closure_stage == 0:
		return
	if fighter.global_position.x >= _left_boundary + 34.0:
		return

	fighter.global_position.x = maxf(fighter.global_position.x, _left_boundary + 12.0)
	fighter.velocity.x = maxf(fighter.velocity.x, 235.0)

	var cooldown := float(_pressure_cooldowns.get(fighter.player_index, 0.0))
	if cooldown > 0.0:
		return

	_pressure_cooldowns[fighter.player_index] = 0.38
	fighter.receive_hit(
		0.65,
		3.2,
		Vector2(315.0, -55.0),
		Vector2(_left_boundary - 70.0, fighter.global_position.y),
		null,
		&"torso",
		null,
		true,
		0.0
	)

func camera_left_limit() -> float:
	return maxf(420.0, _left_boundary + 420.0)

func closure_stage() -> int:
	return _closure_stage

func closure_stage_label() -> String:
	match _closure_stage:
		1:
			return "COLAPSO INICIAL"
		2:
			return "SETOR JI FECHADO"
		3:
			return "ASCENSÃO FINAL"
		4:
			return "PLATAFORMA LIMITE"
		_:
			return "ARENA ESTÁVEL"

func route_for_position(position: Vector2) -> StringName:
	if position.y <= 430.0:
		return &"tai"
	if position.y >= 610.0:
		return &"ji"
	return &"fu"

func is_position_safe(position: Vector2, margin: float = 95.0) -> bool:
	return position.x >= _left_boundary + margin and position.x <= WORLD_WIDTH - 55.0

func active_manifestation_data() -> Dictionary:
	if _active_manifestation < 0 or _active_manifestation >= _manifestation_slots.size():
		return {}
	var slot: Dictionary = _manifestation_slots[_active_manifestation].duplicate(true)
	slot["global_position"] = to_global(slot["position"])
	return slot

func strategic_points(route_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for point in _strategic_points:
		if route_id != &"" and StringName(point["route"]) != route_id:
			continue
		var global_position := to_global(point["position"])
		if not is_position_safe(global_position, 120.0):
			continue
		var copy := point.duplicate(true)
		copy["global_position"] = global_position
		result.append(copy)
	return result

func best_strategic_point(
	route_id: StringName,
	origin: Vector2,
	opponent_position: Vector2,
	objective_id: StringName = &"control"
) -> Dictionary:
	var candidates := strategic_points(route_id)
	if candidates.is_empty():
		candidates = strategic_points()
	if candidates.is_empty():
		return {
			"id": &"safe_fallback",
			"route": &"fu",
			"role": &"recovery",
			"global_position": Vector2(maxf(_left_boundary + 260.0, 1800.0), 720.0),
			"risk": 0.25
		}

	var best: Dictionary = candidates[0]
	var best_score := INF
	for point in candidates:
		var point_position: Vector2 = point["global_position"]
		var risk := float(point.get("risk", 0.5))
		var score := origin.distance_to(point_position) * 0.0035 + risk * 1.5
		var opponent_distance := opponent_position.distance_to(point_position)
		var role := StringName(point.get("role", &"control"))

		match objective_id:
			&"escape":
				score -= clampf((point_position.x - _left_boundary) * 0.0014, 0.0, 2.2)
				if role == &"ascent" or role == &"recovery":
					score -= 0.55
			&"engage":
				score += opponent_distance * 0.0018
				if role == &"choke" or role == &"control":
					score -= 0.48
			&"range":
				score -= clampf(opponent_distance * 0.0012, 0.0, 1.4)
				if role == &"high_ground" or role == &"range":
					score -= 0.65
			&"transition":
				if role == &"transition" or role == &"ascent":
					score -= 0.72
			_:
				if role == &"control" or role == &"resource":
					score -= 0.35

		if score < best_score:
			best_score = score
			best = point
	return best.duplicate(true)

func _build_blockout() -> void:
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

	# Escada final: navegação vertical quando os setores laterais fecham.
	_create_static_platform(Rect2(2050, 790, 180, 22), Color(0.38, 0.25, 0.55))
	_create_static_platform(Rect2(2320, 565, 165, 22), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(2540, 350, 170, 22), Color(0.38, 0.25, 0.55))

func _build_moving_platforms() -> void:
	_moving_platform = _create_moving_platform("MovingFuPlatform", _moving_origin, Vector2(150, 22))
	_vertical_platform = _create_moving_platform("VerticalLimitPlatform", _vertical_origin, Vector2(135, 22))

func _create_moving_platform(node_name: String, origin: Vector2, size: Vector2) -> AnimatableBody2D:
	var platform := AnimatableBody2D.new()
	platform.name = node_name
	platform.position = origin
	platform.collision_layer = 1
	platform.collision_mask = 1

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	platform.add_child(collision)
	add_child(platform)
	return platform

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
	var slot_position: Vector2 = to_global(slot["position"])

	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		if fighter.global_position.distance_to(slot_position) > 44.0:
			continue

		match slot["type"]:
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
		fighter.queue_redraw()
		break

func respawn_point(player_index: int) -> Vector2:
	var left_spawn := maxf(240.0, _left_boundary + 165.0)
	return Vector2(left_spawn, 760) if player_index == 1 else Vector2(2520, 760)

func world_center() -> Vector2:
	return Vector2(WORLD_WIDTH * 0.5, 500)

func _draw() -> void:
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
		var rect: Rect2 = platform["rect"]
		var color: Color = platform["color"]
		draw_rect(rect, color)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), color.lightened(0.22), 3.0)

	if is_instance_valid(_moving_platform):
		draw_rect(
			Rect2(_moving_platform.position - Vector2(75, 11), Vector2(150, 22)),
			Color(0.55, 0.36, 0.76)
		)
	if is_instance_valid(_vertical_platform):
		draw_rect(
			Rect2(_vertical_platform.position - Vector2(67.5, 11), Vector2(135, 22)),
			Color(0.28, 0.58, 0.72)
		)

	if show_strategic_points:
		var route_colors := {
			&"tai": Color(0.32, 0.72, 1.0, 0.44),
			&"ji": Color(0.96, 0.45, 0.24, 0.44),
			&"fu": Color(0.65, 0.38, 1.0, 0.44)
		}
		for point in _strategic_points:
			var point_position: Vector2 = point["position"]
			if not is_position_safe(to_global(point_position), 120.0):
				continue
			var point_color: Color = route_colors.get(StringName(point["route"]), Color(0.8, 0.8, 0.8, 0.4))
			draw_circle(point_position, 9.0, point_color)
			draw_arc(point_position, 14.0, 0.0, TAU, 16, point_color.lightened(0.25), 2.0)

	if _active_manifestation >= 0:
		var slot: Dictionary = _manifestation_slots[_active_manifestation]
		var slot_position: Vector2 = slot["position"]
		var slot_color: Color = slot["color"]
		var pulse := 18.0 + sin(_elapsed * 4.0) * 4.0
		draw_circle(slot_position, pulse, Color(slot_color, 0.32))
		draw_arc(slot_position, pulse + 8.0, 0.0, TAU, 30, slot_color, 3.0)

	if _closure_stage > 0:
		draw_rect(
			Rect2(-500, -100, _left_boundary + 500.0, 1200),
			Color(0.72, 0.10, 0.08, 0.20)
		)
		draw_line(
			Vector2(_left_boundary, 100),
			Vector2(_left_boundary, 980),
			Color(1.0, 0.28, 0.12, 0.92),
			9.0
		)
		for offset in range(0, 800, 62):
			draw_line(
				Vector2(_left_boundary - 22, 140 + offset),
				Vector2(_left_boundary + 26, 170 + offset),
				Color(1.0, 0.65, 0.18, 0.72),
				3.0
			)
