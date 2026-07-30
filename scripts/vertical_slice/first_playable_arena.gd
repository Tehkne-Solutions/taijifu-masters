class_name FirstPlayableArena
extends TriplePathArena

func start_battle_flow() -> void:
	super.start_battle_flow()
	_set_environment_round_active(true)

func stop_battle_flow() -> void:
	_battle_active = false
	_active_manifestation = -1
	_manifestation_timer = 0.0
	_set_environment_round_active(false)
	queue_redraw()

func _set_environment_round_active(active: bool) -> void:
	var environment := get_node_or_null("../EnvironmentArt") as FirstPlayableEnvironmentArt
	if is_instance_valid(environment):
		environment.set_round_active(active)
