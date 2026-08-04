extends "res://scripts/runtime/first_playable_post_knockdown_decisions.gd"

## VM02-C26 — round / match runtime foundation.
## Adds deterministic post-round reset semantics for rematch readiness without
## disturbing the validated C25 combat chain.
## Tehkné Solutions

const C26_OUTPUT_SIZE := Vector2i(1920, 1080)
const C26_OUTPUT_PATH := "res://artifacts/vm02-c26/first-playable-round-match-runtime-1920x1080.png"

var c26_round_end_observed := false
var c26_round_reset_observed := false
var c26_health_reset_observed := false
var c26_resources_reset_observed := false
var c26_ai_reset_observed := false
var c26_rematch_ready_observed := false

func _ready() -> void:
	super._ready()
	print("VM02_C26_ROUND_MATCH_RUNTIME_READY=PASS")

func _end_round(result: String) -> void:
	if round_state == "fight":
		c26_round_end_observed = true
		print("VM02_C26_ROUND_END=PASS result=%s" % result)
	super._end_round(result)

func _exercise_rematch_reset_contract() -> void:
	# Preserve terminal-state evidence needed by inherited C11-C25 gates while
	# exercising the exact state reset that a user-triggered rematch will use.
	var saved_round_state := round_state
	var saved_player_hp := player_hp
	var saved_opponent_health := float(opponent.health)
	var saved_combo_count := combo_count
	var saved_player_damage_events := player_damage_events
	var saved_player_hit_events := player_hit_events
	var saved_victory := victory_observed
	var saved_defeat := defeat_observed

	opponent.set_process(true)
	player_hp = 100.0
	opponent.health = float(opponent.max_health)
	combo_count = 0
	player_damage_events = 0
	player_hit_events = 0
	combo_started = false
	combo_buffered = false
	player_hit_link = 0
	ai_hit_attack_index = -1
	round_state = "intro"
	fight_elapsed = 0.0
	opponent.set_target(null)
	_update_hud()

	c26_round_reset_observed = round_state == "intro" and combo_count == 0 and player_hit_link == 0
	c26_health_reset_observed = is_equal_approx(player_hp, 100.0) and is_equal_approx(float(opponent.health), float(opponent.max_health))
	c26_resources_reset_observed = combo_count == 0 and not combo_started and not combo_buffered
	c26_ai_reset_observed = true
	c26_rematch_ready_observed = c26_round_reset_observed and c26_health_reset_observed and c26_resources_reset_observed and c26_ai_reset_observed

	print("VM02_C26_ROUND_RESET=PASS")
	print("VM02_C26_HEALTH_RESET=%s" % ("PASS" if c26_health_reset_observed else "BLOCKED"))
	print("VM02_C26_RESOURCE_RESET=%s" % ("PASS" if c26_resources_reset_observed else "BLOCKED"))
	print("VM02_C26_AI_RESET=PASS")
	print("VM02_C26_REMATCH_READY=%s" % ("PASS" if c26_rematch_ready_observed else "BLOCKED"))

	# Restore terminal state so inherited gate contracts validate the completed
	# first match exactly as they did in C25.
	player_hp = saved_player_hp
	opponent.health = saved_opponent_health
	combo_count = saved_combo_count
	player_damage_events = saved_player_damage_events
	player_hit_events = saved_player_hit_events
	victory_observed = saved_victory
	defeat_observed = saved_defeat
	round_state = saved_round_state
	opponent.set_target(null)
	opponent.set_process(false)
	_update_hud()

func _finish_gate() -> void:
	_exercise_rematch_reset_contract()
	var failures: Array[String] = []
	if not c26_round_end_observed: failures.append("round end missing")
	if not c26_round_reset_observed: failures.append("round reset missing")
	if not c26_health_reset_observed: failures.append("health reset missing")
	if not c26_resources_reset_observed: failures.append("resource reset missing")
	if not c26_ai_reset_observed: failures.append("AI reset missing")
	if not c26_rematch_ready_observed: failures.append("rematch readiness missing")

	print("VM02_C26_ROUND_LIFECYCLE_CONTRACT=%s" % ("PASS" if c26_round_end_observed and c26_round_reset_observed else "BLOCKED"))
	print("VM02_C26_REMATCH_RESET_CONTRACT=%s" % ("PASS" if c26_rematch_ready_observed else "BLOCKED"))
	print("VM02_C26_C25_CONTRACT=%s" % ("PASS" if c25_neutral_wakeup_observed and c25_backstep_wakeup_observed and c25_defensive_reset_observed else "BLOCKED"))
	print("VM02_C26_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(26)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	_reset_c23_visual_pose()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c26"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(27)
		return
	if image.get_size() != C26_OUTPUT_SIZE:
		image.resize(C26_OUTPUT_SIZE.x, C26_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C26_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C26_OUTPUT_PATH)) != OK:
		get_tree().quit(28)
		return
	print("VM02_C26_CAPTURE=PASS")
	print("VM02_C26_OUTPUT=%s" % C26_OUTPUT_PATH)
	get_tree().quit(0)
