class_name CompetitiveArenaRuntime
extends Node

@onready var arena: TriplePathArena = get_node("../Arena")
@onready var environment_art: TriplePathEnvironmentArt = get_node("../TriplePathEnvironmentArt")

var _rules: Dictionary = CompetitiveMatchCatalog.resolved_arena_rules(CompetitiveMatchCatalog.default_config())
var _round_active := false

func _ready() -> void:
	_apply_environment_art()

func _physics_process(delta: float) -> void:
	if not _round_active or not is_instance_valid(arena):
		return
	var closure_enabled := bool(_rules.get("closure_enabled", true))
	var time_scale := maxf(0.25, float(_rules.get("closure_time_scale", 1.0)))
	if not closure_enabled:
		arena._elapsed = minf(arena._elapsed, TriplePathArena.CLOSURE_START_SECONDS - 0.25)
		arena._closure_stage = 0
		arena._left_boundary = -180.0
	elif time_scale < 0.999:
		arena._elapsed += delta * (1.0 / time_scale - 1.0)
	elif time_scale > 1.001:
		arena._elapsed = maxf(0.0, arena._elapsed - delta * (1.0 - 1.0 / time_scale))

	var manifestations_enabled := bool(_rules.get("manifestations_enabled", true))
	if not manifestations_enabled:
		arena._active_manifestation = -1
		arena._manifestation_timer = 0.0
	else:
		var interval := maxf(1.0, float(_rules.get("manifestation_interval", 5.5)))
		if arena._active_manifestation < 0 and arena._manifestation_timer >= interval:
			arena._manifestation_timer = 5.5
	arena.queue_redraw()

func configure(rules: Dictionary) -> void:
	_rules = rules.duplicate(true)
	_apply_environment_art()

func prepare_round() -> void:
	arena.reset_battle_flow()
	arena._battle_active = false
	arena._elapsed = 0.0
	arena._closure_stage = 0
	arena._left_boundary = -180.0
	arena._manifestation_timer = 0.0
	arena._active_manifestation = 0 if bool(_rules.get("manifestations_enabled", true)) else -1
	_round_active = false
	if is_instance_valid(environment_art):
		environment_art.set_round_active(false)
	arena.queue_redraw()

func start_round() -> void:
	arena.start_battle_flow()
	if not bool(_rules.get("manifestations_enabled", true)):
		arena._active_manifestation = -1
	_round_active = true
	if is_instance_valid(environment_art):
		environment_art.set_round_active(true)

func stop_round() -> void:
	_round_active = false
	arena._battle_active = false
	if is_instance_valid(environment_art):
		environment_art.set_round_active(false)

func update_score_visual(snapshot: Dictionary) -> void:
	if is_instance_valid(environment_art):
		environment_art.set_score_snapshot(snapshot)

func current_rules() -> Dictionary:
	return _rules.duplicate(true)

func is_round_active() -> bool:
	return _round_active

func _apply_environment_art() -> void:
	if not is_instance_valid(environment_art):
		return
	environment_art.configure({"arena_id": StringName(_rules.get("arena_id", &"triple_ruins"))}, _rules)
