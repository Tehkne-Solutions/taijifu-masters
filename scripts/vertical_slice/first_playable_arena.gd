class_name FirstPlayableArena
extends TriplePathArena

func stop_battle_flow() -> void:
	_battle_active = false
	_active_manifestation = -1
	_manifestation_timer = 0.0
	queue_redraw()
