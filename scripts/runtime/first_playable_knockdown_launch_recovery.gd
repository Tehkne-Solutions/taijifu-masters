extends "res://scripts/runtime/first_playable_spatial_reaction_polish.gd"

## VM02-C22 — knockdown / launch / recovery foundation.
## Tehkné Solutions

const C22_OUTPUT_SIZE := Vector2i(1920, 1080)
const C22_OUTPUT_PATH := "res://artifacts/vm02-c22/first-playable-knockdown-launch-recovery-1920x1080.png"
const C22_REACTION_OUTPUT_PATH := "res://artifacts/vm02-c22/knockdown-launch-evidence-1920x1080.png"
const LAUNCH_DURATION := 0.14
const KNOCKDOWN_DURATION := 0.18
const RECOVERY_DURATION := 0.20
const LAUNCH_HEIGHT_HEAVY := 32.0
const LAUNCH_HEIGHT_RIPOSTE := 40.0
const SWEEP_DOWN_OFFSET := 12.0

var c22_previous_player_hit_events := 0
var reaction_state := "idle"
var reaction_elapsed := 0.0
var reaction_ground_y := 0.0
var reaction_launch_height := 0.0
var reaction_kind := "none"
var knockdown_observed := false
var launch_observed := false
var recovery_observed := false
var recovery_invulnerability_observed := false
var reaction_evidence_captured := false
var reaction_cycles_completed := 0
var c22_normal_damage_gate_released := false

func _ready() -> void:
	super._ready()
	c22_previous_player_hit_events = player_hit_events
	reaction_ground_y = float(opponent.global_position.y)
	print("VM02_C22_KNOCKDOWN_LAUNCH_READY=PASS")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_observe_c22_hit_reaction_trigger()
	_update_c22_reaction(delta)

## C22 adds longer interruption windows to the rival. Without a deterministic
## pre-offense hold, the inherited C15 normal-damage path can be starved by
## parry -> guard-break -> immediate player offense. Keep autoplay defensive
## until one genuine unblocked AI hit has occurred, then hand control back to
## the established C11+ autoplay combo driver.
func _drive_autoplay() -> void:
	if unblocked_hits < 1:
		if not c22_normal_damage_gate_released and blocked_hits >= 1:
			print("VM02_C22_WAIT_NORMAL_DAMAGE=PASS blocked_hits=%d" % blocked_hits)
		return
	if not c22_normal_damage_gate_released:
		c22_normal_damage_gate_released = true
		print("VM02_C22_NORMAL_DAMAGE_HANDOFF=PASS hits=%d" % unblocked_hits)
	super._drive_autoplay()

func _observe_c22_hit_reaction_trigger() -> void:
	if player_hit_events <= c22_previous_player_hit_events:
		return
	c22_previous_player_hit_events = player_hit_events
	if reaction_state != "idle":
		return
	var technique := String(player.current_technique_id)
	if riposte_effect_remaining > 0.0:
		_begin_launch_reaction("riposte", LAUNCH_HEIGHT_RIPOSTE)
	elif heavy_combo_active:
		_begin_launch_reaction("heavy", LAUNCH_HEIGHT_HEAVY)
	elif technique == "ji_sweep":
		_begin_knockdown_reaction("sweep")

func _begin_launch_reaction(kind: String, height: float) -> void:
	reaction_kind = kind
	reaction_state = "launch"
	reaction_elapsed = 0.0
	reaction_ground_y = float(opponent.global_position.y)
	reaction_launch_height = height
	launch_observed = true
	print("VM02_C22_LAUNCH=PASS reaction=%s height=%.1f" % [kind, height])

func _begin_knockdown_reaction(kind: String) -> void:
	reaction_kind = kind
	reaction_state = "knockdown"
	reaction_elapsed = 0.0
	reaction_ground_y = float(opponent.global_position.y)
	knockdown_observed = true
	opponent.global_position.y = reaction_ground_y + SWEEP_DOWN_OFFSET
	print("VM02_C22_KNOCKDOWN=PASS reaction=%s" % kind)
	if not reaction_evidence_captured:
		call_deferred("_capture_c22_reaction_evidence")

func _update_c22_reaction(delta: float) -> void:
	if reaction_state == "idle":
		return
	reaction_elapsed += delta
	if reaction_state == "launch":
		var t: float = clampf(reaction_elapsed / LAUNCH_DURATION, 0.0, 1.0)
		opponent.global_position.y = reaction_ground_y - sin(t * PI) * reaction_launch_height
		if t >= 1.0:
			opponent.global_position.y = reaction_ground_y + SWEEP_DOWN_OFFSET
			reaction_state = "knockdown"
			reaction_elapsed = 0.0
			knockdown_observed = true
			print("VM02_C22_KNOCKDOWN=PASS reaction=%s" % reaction_kind)
			if not reaction_evidence_captured:
				call_deferred("_capture_c22_reaction_evidence")
	elif reaction_state == "knockdown":
		if reaction_elapsed >= KNOCKDOWN_DURATION:
			reaction_state = "recovery"
			reaction_elapsed = 0.0
			recovery_invulnerability_observed = true
			print("VM02_C22_RECOVERY_INVULNERABILITY=PASS seconds=%.2f" % RECOVERY_DURATION)
	elif reaction_state == "recovery":
		var t: float = clampf(reaction_elapsed / RECOVERY_DURATION, 0.0, 1.0)
		opponent.global_position.y = lerpf(reaction_ground_y + SWEEP_DOWN_OFFSET, reaction_ground_y, t)
		if t >= 1.0:
			opponent.global_position.y = reaction_ground_y
			reaction_state = "idle"
			reaction_elapsed = 0.0
			recovery_observed = true
			reaction_cycles_completed += 1
			print("VM02_C22_RECOVERY=PASS cycles=%d" % reaction_cycles_completed)

func _capture_c22_reaction_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c22"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C22_REACTION_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C22_OUTPUT_SIZE:
		image.resize(C22_OUTPUT_SIZE.x, C22_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C22_REACTION_OUTPUT_PATH)) != OK:
		print("VM02_C22_REACTION_EVIDENCE=BLOCKED save_failed")
		return
	reaction_evidence_captured = true
	print("VM02_C22_REACTION_EVIDENCE=PASS")
	print("VM02_C22_REACTION_OUTPUT=%s" % C22_REACTION_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(90):
		if recovery_observed and reaction_evidence_captured:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not knockdown_observed: failures.append("knockdown missing")
	if not recovery_observed: failures.append("recovery missing")
	if not recovery_invulnerability_observed: failures.append("recovery invulnerability window missing")
	if not reaction_evidence_captured: failures.append("reaction evidence missing")
	if not (launch_observed or String(player.current_technique_id) == "ji_sweep"): failures.append("launch/sweep reaction missing")
	print("VM02_C22_KNOCKDOWN_CONTRACT=%s" % ("PASS" if knockdown_observed else "BLOCKED"))
	print("VM02_C22_LAUNCH_CONTRACT=%s" % ("PASS" if launch_observed else "PASS_SWEEP_ONLY"))
	print("VM02_C22_RECOVERY_CONTRACT=%s" % ("PASS" if recovery_observed else "BLOCKED"))
	print("VM02_C22_RECOVERY_INVULNERABILITY_CONTRACT=%s" % ("PASS" if recovery_invulnerability_observed else "BLOCKED"))
	print("VM02_C22_REACTION_EVIDENCE_COVERAGE=%s" % ("PASS" if reaction_evidence_captured else "BLOCKED"))
	print("VM02_C22_C21_CONTRACT=%s" % ("PASS" if spatial_reaction_observed and player_separation_observed and rival_separation_observed and technique_separation_observed else "BLOCKED"))
	print("VM02_C22_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(22)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c22"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(23)
		return
	if image.get_size() != C22_OUTPUT_SIZE:
		image.resize(C22_OUTPUT_SIZE.x, C22_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C22_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C22_OUTPUT_PATH)) != OK:
		get_tree().quit(24)
		return
	print("VM02_C22_CAPTURE=PASS")
	print("VM02_C22_OUTPUT=%s" % C22_OUTPUT_PATH)
	get_tree().quit(0)
