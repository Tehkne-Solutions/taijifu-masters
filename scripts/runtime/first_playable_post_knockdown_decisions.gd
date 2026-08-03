extends "res://scripts/runtime/first_playable_knockdown_gameplay_depth.gd"

## VM02-C25 — post-knockdown decision foundation.
## Adds deterministic wake-up variety and a short AI defensive reset after backstep wake-up.
## Tehkné Solutions

const C25_OUTPUT_SIZE := Vector2i(1920, 1080)
const C25_OUTPUT_PATH := "res://artifacts/vm02-c25/first-playable-post-knockdown-decisions-1920x1080.png"
const C25_BACKSTEP_DISTANCE := 42.0
const C25_DEFENSIVE_RESET_SECONDS := 0.18

var c25_wakeup_count := 0
var c25_neutral_wakeup_observed := false
var c25_backstep_wakeup_observed := false
var c25_defensive_reset_observed := false
var c25_defensive_reset_remaining := 0.0
var c25_defensive_target_restore_observed := false

func _ready() -> void:
	super._ready()
	print("VM02_C25_POST_KNOCKDOWN_DECISIONS_READY=PASS")

func _physics_process(delta: float) -> void:
	if c25_defensive_reset_remaining > 0.0:
		c25_defensive_reset_remaining = maxf(0.0, c25_defensive_reset_remaining - delta)
		if c25_defensive_reset_remaining <= 0.0 and round_state == "fight" and String(reaction_state) == "idle":
			opponent.set_target(player)
			c25_defensive_target_restore_observed = true
			print("VM02_C25_DEFENSIVE_TARGET_RESTORE=PASS")
	super._physics_process(delta)

func _update_c22_reaction(delta: float) -> void:
	var before := String(reaction_state)
	super._update_c22_reaction(delta)
	var current := String(reaction_state)
	if before != "recovery" or current != "idle":
		return

	c25_wakeup_count += 1
	if c25_wakeup_count % 2 == 1:
		c25_neutral_wakeup_observed = true
		print("VM02_C25_WAKEUP_NEUTRAL=PASS cycle=%d" % c25_wakeup_count)
		return

	var away := signf(float(opponent.global_position.x - player.global_position.x))
	if is_zero_approx(away):
		away = 1.0
	opponent.global_position.x = clampf(float(opponent.global_position.x) + away * C25_BACKSTEP_DISTANCE, 150.0, 1130.0)
	opponent.set_target(null)
	c25_defensive_reset_remaining = C25_DEFENSIVE_RESET_SECONDS
	c25_backstep_wakeup_observed = true
	c25_defensive_reset_observed = true
	print("VM02_C25_WAKEUP_BACKSTEP=PASS cycle=%d distance=%.1f" % [c25_wakeup_count, C25_BACKSTEP_DISTANCE])
	print("VM02_C25_AI_DEFENSIVE_RESET=PASS seconds=%.2f" % C25_DEFENSIVE_RESET_SECONDS)

func _finish_gate() -> void:
	for _i in range(180):
		if c25_neutral_wakeup_observed and c25_backstep_wakeup_observed and c25_defensive_reset_observed and c25_defensive_target_restore_observed:
			break
		await get_tree().physics_frame

	var failures: Array[String] = []
	if not c25_neutral_wakeup_observed: failures.append("neutral wake-up missing")
	if not c25_backstep_wakeup_observed: failures.append("backstep wake-up missing")
	if not c25_defensive_reset_observed: failures.append("AI defensive reset missing")
	if not c25_defensive_target_restore_observed: failures.append("AI target restore after defensive reset missing")
	if not c24_action_lock_observed: failures.append("C24 action lock missing")
	if not c24_wakeup_protection_observed: failures.append("C24 wake-up protection missing")

	print("VM02_C25_WAKEUP_VARIETY_CONTRACT=%s" % ("PASS" if c25_neutral_wakeup_observed and c25_backstep_wakeup_observed else "BLOCKED"))
	print("VM02_C25_AI_DEFENSIVE_RESET_CONTRACT=%s" % ("PASS" if c25_defensive_reset_observed and c25_defensive_target_restore_observed else "BLOCKED"))
	print("VM02_C25_C24_CONTRACT=%s" % ("PASS" if c24_action_lock_observed and c24_wakeup_protection_observed and c24_target_restore_observed and c24_anti_reknockdown_observed else "BLOCKED"))
	print("VM02_C25_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(25)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	_reset_c23_visual_pose()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c25"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(26)
		return
	if image.get_size() != C25_OUTPUT_SIZE:
		image.resize(C25_OUTPUT_SIZE.x, C25_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C25_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C25_OUTPUT_PATH)) != OK:
		get_tree().quit(27)
		return
	print("VM02_C25_CAPTURE=PASS")
	print("VM02_C25_OUTPUT=%s" % C25_OUTPUT_PATH)
	get_tree().quit(0)
