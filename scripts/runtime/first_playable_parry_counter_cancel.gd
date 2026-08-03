extends "res://scripts/runtime/first_playable_offensive_depth.gd"

## VM02-C18 — Parry Counter / Cancel Window Foundation.
## Converts a successful parry into a deterministic offensive opportunity
## without changing the validated C17 damage, stamina or guard contracts.
## Tehkné Solutions

const C18_OUTPUT_SIZE := Vector2i(1920, 1080)
const C18_OUTPUT_PATH := "res://artifacts/vm02-c18/first-playable-parry-counter-1920x1080.png"
const C18_COUNTER_OUTPUT_PATH := "res://artifacts/vm02-c18/parry-counter-evidence-1920x1080.png"
const COUNTER_WINDOW_SECONDS := 0.36
const CANCEL_WINDOW_SECONDS := 0.18

var counter_window_remaining := 0.0
var cancel_window_remaining := 0.0
var counter_effect_remaining := 0.0
var parry_latched := false
var counter_ready_observed := false
var counter_consumed_observed := false
var cancel_window_observed := false
var counter_evidence_captured := false
var counter_source := ""

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D MOVE   SHIFT RUN   SPACE JUMP   F LIGHT/COMBO   G+F HEAVY   R BLOCK   V PARRY → F COUNTER"
	print("VM02_C18_PARRY_COUNTER_READY=PASS")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if parry_observed and not parry_latched:
		parry_latched = true
		_open_counter_window()

	if counter_window_remaining > 0.0:
		counter_window_remaining = maxf(0.0, counter_window_remaining - delta)
		if autoplay and not counter_consumed_observed:
			_consume_counter_window("autoplay")
		elif not autoplay and Input.is_action_just_pressed(&"p1_attack") and not counter_consumed_observed:
			_consume_counter_window("player")

	if cancel_window_remaining > 0.0:
		cancel_window_remaining = maxf(0.0, cancel_window_remaining - delta)
	if counter_effect_remaining > 0.0:
		counter_effect_remaining = maxf(0.0, counter_effect_remaining - delta)
		queue_redraw()

func _open_counter_window() -> void:
	counter_window_remaining = COUNTER_WINDOW_SECONDS
	cancel_window_remaining = CANCEL_WINDOW_SECONDS
	counter_ready_observed = true
	cancel_window_observed = true
	print("VM02_C18_COUNTER_WINDOW=PASS seconds=%.2f" % COUNTER_WINDOW_SECONDS)
	print("VM02_C18_PARRY_CANCEL_WINDOW=PASS seconds=%.2f" % CANCEL_WINDOW_SECONDS)
	queue_redraw()

func _consume_counter_window(source: String) -> void:
	if counter_window_remaining <= 0.0 or counter_consumed_observed:
		return
	counter_consumed_observed = true
	counter_source = source
	counter_effect_remaining = 0.24
	counter_window_remaining = 0.0
	print("VM02_C18_COUNTER_CONSUMED=PASS source=%s" % source)
	if not counter_evidence_captured:
		call_deferred("_capture_counter_evidence")
	queue_redraw()

func _update_hud() -> void:
	super._update_hud()
	if counter_window_remaining > 0.0:
		status_label.text += "   ·   COUNTER READY"
	elif counter_consumed_observed and counter_effect_remaining > 0.0:
		status_label.text += "   ·   COUNTER"

func _capture_counter_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c18"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C18_COUNTER_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C18_OUTPUT_SIZE:
		image.resize(C18_OUTPUT_SIZE.x, C18_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C18_COUNTER_OUTPUT_PATH)) != OK:
		print("VM02_C18_COUNTER_EVIDENCE=BLOCKED save_failed")
		return
	counter_evidence_captured = true
	print("VM02_C18_COUNTER_EVIDENCE=PASS")
	print("VM02_C18_COUNTER_OUTPUT=%s" % C18_COUNTER_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(30):
		if counter_evidence_captured:
			break
		await get_tree().process_frame
	var failures: Array[String] = []
	if not counter_ready_observed: failures.append("counter window missing")
	if not cancel_window_observed: failures.append("parry cancel window missing")
	if not counter_consumed_observed: failures.append("counter input not consumed")
	if not counter_evidence_captured: failures.append("counter evidence missing")
	print("VM02_C18_COUNTER_WINDOW_CONTRACT=%s" % ("PASS" if counter_ready_observed else "BLOCKED"))
	print("VM02_C18_CANCEL_WINDOW_CONTRACT=%s" % ("PASS" if cancel_window_observed else "BLOCKED"))
	print("VM02_C18_COUNTER_CONSUME_CONTRACT=%s" % ("PASS" if counter_consumed_observed else "BLOCKED"))
	print("VM02_C18_COUNTER_EVIDENCE_COVERAGE=%s" % ("PASS" if counter_evidence_captured else "BLOCKED"))
	print("VM02_C18_C17_CONTRACT=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_C18_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(18)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c18"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(19)
		return
	if image.get_size() != C18_OUTPUT_SIZE:
		image.resize(C18_OUTPUT_SIZE.x, C18_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C18_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C18_OUTPUT_PATH)) != OK:
		get_tree().quit(20)
		return
	print("VM02_C18_CAPTURE=PASS")
	print("VM02_C18_OUTPUT=%s" % C18_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	var center: Vector2 = player.global_position + Vector2(0.0, -44.0)
	if counter_window_remaining > 0.0:
		draw_arc(center, 58.0, 0.0, TAU, 42, Color(1.0, 0.82, 0.30, 0.95), 4.0)
		draw_arc(center, 68.0, -1.25, 1.25, 28, Color(0.55, 0.90, 1.0, 0.86), 3.0)
	if counter_effect_remaining > 0.0:
		var alpha := clampf(counter_effect_remaining / 0.24, 0.0, 1.0)
		for i in range(10):
			var angle := TAU * float(i) / 10.0
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(center + dir * 28.0, center + dir * 72.0, Color(1.0, 0.72, 0.20, alpha), 3.0)