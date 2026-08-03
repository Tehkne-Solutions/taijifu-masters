extends "res://scripts/runtime/first_playable_knockdown_launch_recovery.gd"

## VM02-C23 — knockdown visual state + get-up animation.
## Tehkné Solutions

const C23_OUTPUT_SIZE := Vector2i(1920, 1080)
const C23_OUTPUT_PATH := "res://artifacts/vm02-c23/first-playable-knockdown-visual-getup-1920x1080.png"
const C23_DOWNED_OUTPUT_PATH := "res://artifacts/vm02-c23/knockdown-downed-evidence-1920x1080.png"
const DOWNED_ROTATION := -PI * 0.5
const AIRBORNE_ROTATION := -0.48
const DOWNED_VISUAL_OFFSET := Vector2(10.0, 12.0)

@onready var c23_visual_rival: Sprite2D = $Opponent/VisualRival

var c23_airborne_visual_observed := false
var c23_downed_visual_observed := false
var c23_getup_visual_observed := false
var c23_ready_restore_observed := false
var c23_downed_evidence_captured := false
var c23_last_reaction_state := "idle"

func _ready() -> void:
	super._ready()
	_reset_c23_visual_pose()
	print("VM02_C23_KNOCKDOWN_VISUAL_GETUP_READY=PASS")

func _update_c22_reaction(delta: float) -> void:
	var before := String(reaction_state)
	super._update_c22_reaction(delta)
	_apply_c23_visual_pose()
	_observe_c23_visual_state(before, String(reaction_state))

func _apply_c23_visual_pose() -> void:
	match String(reaction_state):
		"launch":
			var t := clampf(reaction_elapsed / LAUNCH_DURATION, 0.0, 1.0)
			var arc := sin(t * PI)
			c23_visual_rival.rotation = AIRBORNE_ROTATION * arc
			c23_visual_rival.position = Vector2(6.0 * t, -10.0 * arc)
		"knockdown":
			c23_visual_rival.rotation = DOWNED_ROTATION
			c23_visual_rival.position = DOWNED_VISUAL_OFFSET
		"recovery":
			var t := clampf(reaction_elapsed / RECOVERY_DURATION, 0.0, 1.0)
			c23_visual_rival.rotation = lerpf(DOWNED_ROTATION, 0.0, t)
			c23_visual_rival.position = DOWNED_VISUAL_OFFSET.lerp(Vector2.ZERO, t)
		_:
			_reset_c23_visual_pose()

func _observe_c23_visual_state(previous: String, current: String) -> void:
	if current == "launch" and not c23_airborne_visual_observed:
		c23_airborne_visual_observed = true
		print("VM02_C23_AIRBORNE_VISUAL=PASS")
	if current == "knockdown" and not c23_downed_visual_observed:
		c23_downed_visual_observed = true
		print("VM02_C23_DOWNED_VISUAL=PASS rotation_deg=%.1f" % rad_to_deg(c23_visual_rival.rotation))
		if not c23_downed_evidence_captured:
			call_deferred("_capture_c23_downed_evidence")
	if current == "recovery" and not c23_getup_visual_observed:
		c23_getup_visual_observed = true
		print("VM02_C23_GETUP_VISUAL=PASS")
	if previous == "recovery" and current == "idle" and not c23_ready_restore_observed:
		_reset_c23_visual_pose()
		c23_ready_restore_observed = true
		print("VM02_C23_READY_RESTORE=PASS")
	c23_last_reaction_state = current

func _reset_c23_visual_pose() -> void:
	if not is_instance_valid(c23_visual_rival):
		return
	c23_visual_rival.rotation = 0.0
	c23_visual_rival.position = Vector2.ZERO

func _capture_c23_downed_evidence() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c23"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C23_DOWNED_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C23_OUTPUT_SIZE:
		image.resize(C23_OUTPUT_SIZE.x, C23_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C23_DOWNED_OUTPUT_PATH)) != OK:
		print("VM02_C23_DOWNED_EVIDENCE=BLOCKED save_failed")
		return
	c23_downed_evidence_captured = true
	print("VM02_C23_DOWNED_EVIDENCE=PASS")
	print("VM02_C23_DOWNED_OUTPUT=%s" % C23_DOWNED_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(120):
		if c23_ready_restore_observed and c23_downed_evidence_captured:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not c23_airborne_visual_observed: failures.append("airborne visual missing")
	if not c23_downed_visual_observed: failures.append("downed visual missing")
	if not c23_getup_visual_observed: failures.append("get-up visual missing")
	if not c23_ready_restore_observed: failures.append("ready restore missing")
	if not c23_downed_evidence_captured: failures.append("downed evidence missing")
	print("VM02_C23_AIRBORNE_VISUAL_CONTRACT=%s" % ("PASS" if c23_airborne_visual_observed else "BLOCKED"))
	print("VM02_C23_DOWNED_VISUAL_CONTRACT=%s" % ("PASS" if c23_downed_visual_observed else "BLOCKED"))
	print("VM02_C23_GETUP_VISUAL_CONTRACT=%s" % ("PASS" if c23_getup_visual_observed else "BLOCKED"))
	print("VM02_C23_READY_RESTORE_CONTRACT=%s" % ("PASS" if c23_ready_restore_observed else "BLOCKED"))
	print("VM02_C23_DOWNED_EVIDENCE_COVERAGE=%s" % ("PASS" if c23_downed_evidence_captured else "BLOCKED"))
	print("VM02_C23_C22_CONTRACT=%s" % ("PASS" if knockdown_observed and launch_observed and recovery_observed and recovery_invulnerability_observed else "BLOCKED"))
	print("VM02_C23_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(23)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	_reset_c23_visual_pose()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c23"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(24)
		return
	if image.get_size() != C23_OUTPUT_SIZE:
		image.resize(C23_OUTPUT_SIZE.x, C23_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C23_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C23_OUTPUT_PATH)) != OK:
		get_tree().quit(25)
		return
	print("VM02_C23_CAPTURE=PASS")
	print("VM02_C23_OUTPUT=%s" % C23_OUTPUT_PATH)
	get_tree().quit(0)
