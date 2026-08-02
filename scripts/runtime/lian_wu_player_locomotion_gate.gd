extends Node2D

## VM02-B2 player-controlled locomotion gate.
## Interactive: p1_left/p1_right, p1_jump, hold Shift to run.
## Automated: --autoplay drives the same public controller input surface.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-b2/lian-wu-player-controlled-1920x1080.png"

# Intentionally untyped: the Player node owns the controller script in the scene.
# This avoids depending on Godot's global class cache during isolated gate startup.
@onready var player = $Player
@onready var state_label: Label = $CanvasLayer/HUD/State
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics
@onready var help_label: Label = $CanvasLayer/HUD/Help

var _autoplay := false
var _capture := false
var _phase := 0
var _phase_elapsed := 0.0
var _start_x := 0.0
var _rightmost_x := 0.0
var _leftmost_after_turn := INF
var _saw_walk := false
var _saw_run := false
var _saw_jump_start := false
var _saw_jump_loop := false
var _saw_fall := false
var _saw_land := false
var _saw_left_facing := false
var _landing_count := 0
var _finished := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_autoplay = args.has("--autoplay")
	_capture = args.has("--capture-and-quit")
	_start_x = float(player.global_position.x)
	_rightmost_x = _start_x
	player.locomotion_state_changed.connect(_on_state_changed)
	player.landed.connect(_on_landed)
	help_label.text = "A/D or p1_left/right · Shift = Run · p1_jump = Jump" if not _autoplay else "AUTOPLAY GATE · same controller input surface"
	print("VM02_B2_MODE=%s" % ("AUTOPLAY" if _autoplay else "INTERACTIVE"))

func _physics_process(delta: float) -> void:
	if _finished: return
	if _autoplay:
		_phase_elapsed += delta
		_drive_autoplay()
	_rightmost_x = maxf(_rightmost_x, float(player.global_position.x))
	if _phase >= 4:
		_leftmost_after_turn = minf(_leftmost_after_turn, float(player.global_position.x))
	_saw_left_facing = _saw_left_facing or float(player.facing) < 0.0
	state_label.text = "STATE: %s · FACING: %s" % [String(player.locomotion_state).to_upper(), "RIGHT" if float(player.facing) > 0.0 else "LEFT"]
	metric_label.text = "x=%.1f  vx=%.1f  vy=%.1f  air=%.1f  landings=%d" % [float(player.global_position.x), float(player.velocity.x), float(player.velocity.y), float(player.max_air_height), _landing_count]

func _drive_autoplay() -> void:
	match _phase:
		0:
			# Walk right.
			player.set_test_input(1.0, false, false)
			if _phase_elapsed >= 0.85: _next_phase()
		1:
			# Run right.
			player.set_test_input(1.0, true, false)
			if _phase_elapsed >= 0.80: _next_phase()
		2:
			# Trigger jump while preserving run momentum.
			player.set_test_input(1.0, true, _phase_elapsed < 0.03)
			if _phase_elapsed >= 0.16: _next_phase()
		3:
			# Let full airborne chain and landing resolve.
			player.set_test_input(0.45, false, false)
			if _landing_count >= 1 and String(player.locomotion_state) == "idle": _next_phase()
			elif _phase_elapsed >= 2.5 and _landing_count >= 1: _next_phase()
		4:
			# Turn and walk left to prove facing + mirrored animation.
			player.set_test_input(-1.0, false, false)
			if _phase_elapsed >= 0.85: _next_phase()
		5:
			player.set_test_input(0.0, false, false)
			if _phase_elapsed >= 0.45: _finish_gate()

func _next_phase() -> void:
	_phase += 1
	_phase_elapsed = 0.0
	print("VM02_B2_AUTOPLAY_PHASE=%d" % _phase)

func _on_state_changed(state: String) -> void:
	match state:
		"walk": _saw_walk = true
		"run": _saw_run = true
		"jump_start": _saw_jump_start = true
		"jump_loop": _saw_jump_loop = true
		"fall": _saw_fall = true
		"land": _saw_land = true

func _on_landed() -> void:
	_landing_count += 1

func _finish_gate() -> void:
	_finished = true
	player.set_test_input(0.0, false, false)
	var failures: Array[String] = []
	var right_displacement: float = _rightmost_x - _start_x
	var left_return: float = _rightmost_x - float(player.global_position.x)
	if not _saw_walk: failures.append("walk state not observed")
	if not _saw_run: failures.append("run state not observed")
	if not _saw_jump_start: failures.append("jump_start not observed")
	if not _saw_jump_loop: failures.append("jump_loop not observed")
	if not _saw_fall: failures.append("fall not observed")
	if not _saw_land: failures.append("land not observed")
	if _landing_count < 1: failures.append("landing event not observed")
	if right_displacement < 160.0: failures.append("right displacement too small: %.2f" % right_displacement)
	if left_return < 45.0: failures.append("left return too small: %.2f" % left_return)
	if not _saw_left_facing: failures.append("left facing not observed")
	if float(player.max_air_height) < 45.0: failures.append("jump apex too low: %.2f" % float(player.max_air_height))
	if String(player.locomotion_state) != "idle": failures.append("final state not idle")
	if not player.is_on_floor(): failures.append("final player not grounded")

	print("VM02_B2_PLAYER_CONTROL_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_B2_WALK=%s" % ("PASS" if _saw_walk else "BLOCKED"))
	print("VM02_B2_RUN=%s" % ("PASS" if _saw_run else "BLOCKED"))
	print("VM02_B2_JUMP_CHAIN=%s" % ("PASS" if _saw_jump_start and _saw_jump_loop and _saw_fall and _saw_land else "BLOCKED"))
	print("VM02_B2_FACING_FLIP=%s" % ("PASS" if _saw_left_facing else "BLOCKED"))
	print("VM02_B2_RIGHT_DISPLACEMENT=%.2f" % right_displacement)
	print("VM02_B2_LEFT_RETURN=%.2f" % left_return)
	print("VM02_B2_MAX_AIR_HEIGHT=%.2f" % float(player.max_air_height))
	for failure in failures: push_error(failure)
	if not failures.is_empty():
		if _capture: get_tree().quit(3)
		return
	if _capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-b2"))
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_B2_CAPTURE_NORMALIZED=PASS")
	var err := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("failed to save B2 capture")
		get_tree().quit(4)
		return
	print("VM02_B2_CAPTURE=PASS")
	print("VM02_B2_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
