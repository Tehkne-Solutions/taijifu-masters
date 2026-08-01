class_name FirstPlayableArena
extends TriplePathArena

const PLAYABLE_LEFT := 80.0
const PLAYABLE_RIGHT := 2720.0

func start_battle_flow() -> void:
	super.start_battle_flow()
	# O First Playable não usa fechamento progressivo. O jogador precisa aprender
	# mobilidade e combate antes de lidar com pressão territorial.
	_closure_stage = 0
	_left_boundary = -180.0
	_set_environment_round_active(true)

func stop_battle_flow() -> void:
	_battle_active = false
	_active_manifestation = -1
	_manifestation_timer = 0.0
	_closure_stage = 0
	_left_boundary = -180.0
	_set_environment_round_active(false)
	queue_redraw()

func _build_blockout() -> void:
	# Piso contínuo: evita aprisionamento entre paredes e deixa a leitura imediata.
	_create_static_platform(Rect2(-180, 850, 3160, 120), Color(0.15, 0.17, 0.22))

	# Escalonamento máximo ~90 px entre níveis, compatível com o pulo atual.
	# A arena passa a funcionar como plataforma de luta, não como labirinto.
	_create_static_platform(Rect2(260, 770, 360, 24), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(760, 700, 340, 24), Color(0.38, 0.25, 0.55))
	_create_static_platform(Rect2(1210, 620, 380, 24), Color(0.18, 0.38, 0.55))
	_create_static_platform(Rect2(1710, 700, 340, 24), Color(0.52, 0.24, 0.19))
	_create_static_platform(Rect2(2180, 770, 360, 24), Color(0.38, 0.25, 0.55))

func _build_moving_platforms() -> void:
	# Plataformas móveis ficam fora do primeiro duelo. Elas competiam com câmera,
	# salto e leitura de alcance antes do jogador dominar o básico.
	pass

func _update_closure(_delta: float) -> void:
	_closure_stage = 0
	_left_boundary = -180.0

func apply_sector_pressure(_fighter: FighterController) -> void:
	# Sem parede de pressão invisível no First Playable.
	pass

func camera_left_limit() -> float:
	return PLAYABLE_LEFT

func is_position_safe(position: Vector2, margin: float = 95.0) -> bool:
	return position.x >= PLAYABLE_LEFT + margin and position.x <= PLAYABLE_RIGHT - margin

func presentation_signature() -> Dictionary:
	return {
		"continuous_floor": true,
		"platform_count": 5,
		"max_vertical_step": 90,
		"moving_platforms": false,
		"sector_closure": false,
		"pressure_wall": false,
		"first_combat_readability": true,
		"signature": "Tehkné Solutions"
	}

func _set_environment_round_active(active: bool) -> void:
	var environment := get_node_or_null("../EnvironmentArt") as FirstPlayableEnvironmentArt
	if is_instance_valid(environment):
		environment.set_round_active(active)

# Tehkné Solutions
