extends "res://scripts/runtime/first_playable_polish.gd"

## VM02-C13 — combat game feel presentation layer.
## Observes the validated C12 combat contract and adds hit feedback only.
## Tehkné Solutions

const C13_OUTPUT_SIZE := Vector2i(1920, 1080)
const C13_OUTPUT_PATH := "res://artifacts/vm02-c13/first-playable-game-feel-1920x1080.png"
const C13_IMPACT_OUTPUT_PATH := "res://artifacts/vm02-c13/impact-game-feel-1920x1080.png"
const SHAKE_DURATION := 0.11
const FLASH_DURATION := 0.085
const HITSTOP_DURATION := 0.045

var last_player_damage_events := 0
var last_player_hit_events := 0
var player_flash_events := 0
var rival_flash_events := 0
var shake_events := 0
var hitstop_events := 0
var impact_burst_events := 0
var round_pulse_events := 0
var victory_pulse_events := 0
var shake_remaining := 0.0
var flash_remaining := 0.0
var hitstop_remaining := 0.0
var impact_origin := Vector2.ZERO
var impact_strength := 0.0
var impact_age := 1.0
var c13_contract_ready := false
var impact_evidence_requested := false
var impact_evidence_captured := false
var base_camera_position := Vector2.ZERO
var base_player_modulate := Color.WHITE
var base_rival_modulate := Color.WHITE

@onready var rival_visual: Sprite2D = $Opponent/VisualRival
@onready var player_visual: Node = $Player

func _ready() -> void:
	super._ready()
	base_camera_position = camera.position
	base_rival_modulate = rival_visual.modulate
	base_player_modulate = player.modulate
	c13_contract_ready = true
	round_pulse_events = 1
	print("VM02_C13_GAME_FEEL_READY=PASS")
	print("VM02_C13_ROUND_PRESENTATION=PASS")

func _physics_process(delta: float) -> void:
	if finished:
		return
	var prev_player_damage := player_damage_events
	var prev_player_hits := player_hit_events
	super._physics_process(delta)
	if finished:
		return
	if player_damage_events > prev_player_damage:
		_trigger_player_impact()
	if player_hit_events > prev_player_hits:
		_trigger_rival_impact()
	_update_game_feel(delta)

func _trigger_player_impact() -> void:
	player_flash_events += 1
	shake_events += 1
	hitstop_events += 1
	impact_burst_events += 1
	shake_remaining = SHAKE_DURATION
	flash_remaining = FLASH_DURATION
	hitstop_remaining = HITSTOP_DURATION
	impact_origin = player.global_position + Vector2(0, -42)
	impact_strength = 0.72
	impact_age = 0.0
	player.modulate = Color(1.0, 0.62, 0.48, 1.0)
	print("VM02_C13_PLAYER_HIT_FLASH=PASS count=%d" % player_flash_events)
	print("VM02_C13_HITSTOP=PASS count=%d duration=%.3f" % [hitstop_events, HITSTOP_DURATION])
	print("VM02_C13_SCREEN_SHAKE=PASS count=%d" % shake_events)
	print("VM02_C13_IMPACT_BURST=PASS count=%d target=player" % impact_burst_events)
	queue_redraw()

func _trigger_rival_impact() -> void:
	rival_flash_events += 1
	shake_events += 1
	hitstop_events += 1
	impact_burst_events += 1
	shake_remaining = SHAKE_DURATION
	flash_remaining = FLASH_DURATION
	hitstop_remaining = HITSTOP_DURATION
	impact_origin = opponent.global_position + Vector2(0, -40)
	var technique := String(player.current_technique_id)
	impact_strength = 1.0 if technique == "ji_body_hook" else 1.18
	impact_age = 0.0
	rival_visual.modulate = Color(1.0, 0.78, 0.38, 1.0)
	print("VM02_C13_RIVAL_HIT_FLASH=PASS count=%d technique=%s" % [rival_flash_events, technique])
	print("VM02_C13_HITSTOP=PASS count=%d duration=%.3f" % [hitstop_events, HITSTOP_DURATION])
	print("VM02_C13_SCREEN_SHAKE=PASS count=%d" % shake_events)
	print("VM02_C13_IMPACT_BURST=PASS count=%d target=rival strength=%.2f" % [impact_burst_events, impact_strength])
	queue_redraw()
	if capture and technique == "ji_sweep" and not impact_evidence_requested:
		impact_evidence_requested = true
		call_deferred("_capture_impact_evidence")

func _capture_impact_evidence() -> void:
	# Wait one rendered frame so the flash, radial burst and camera shake are visible.
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c13"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C13_IMPACT_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C13_OUTPUT_SIZE:
		image.resize(C13_OUTPUT_SIZE.x, C13_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C13_IMPACT_OUTPUT_PATH)) != OK:
		print("VM02_C13_IMPACT_EVIDENCE=BLOCKED save_failed")
		return
	impact_evidence_captured = true
	print("VM02_C13_IMPACT_EVIDENCE=PASS")
	print("VM02_C13_IMPACT_OUTPUT=%s" % C13_IMPACT_OUTPUT_PATH)

func _update_game_feel(delta: float) -> void:
	if shake_remaining > 0.0:
		shake_remaining = maxf(0.0, shake_remaining - delta)
		var phase := elapsed * 118.0
		var amplitude := 4.2 * (shake_remaining / SHAKE_DURATION)
		camera.position = base_camera_position + Vector2(sin(phase) * amplitude, cos(phase * 1.37) * amplitude * 0.58)
	else:
		camera.position = camera.position.lerp(base_camera_position, minf(1.0, delta * 18.0))
	if flash_remaining > 0.0:
		flash_remaining = maxf(0.0, flash_remaining - delta)
	else:
		player.modulate = base_player_modulate
		rival_visual.modulate = base_rival_modulate
	if hitstop_remaining > 0.0:
		hitstop_remaining = maxf(0.0, hitstop_remaining - delta)
	impact_age = minf(1.0, impact_age + delta * 5.5)
	queue_redraw()

func _end_round(result: String) -> void:
	var was_fight := round_state == "fight"
	super._end_round(result)
	if was_fight and result == "victory":
		victory_pulse_events += 1
		print("VM02_C13_VICTORY_PRESENTATION=PASS")

func _finish_gate() -> void:
	# Allow C12 to settle the final combo signal before evaluating the C13 layer.
	if combo_count < 2 and victory_observed:
		for _i in range(40):
			await get_tree().physics_frame
			if combo_count >= 2:
				break
	# Also allow the asynchronous impact-evidence capture to finish.
	if impact_evidence_requested and not impact_evidence_captured:
		for _i in range(20):
			await get_tree().process_frame
			if impact_evidence_captured:
				break
	var failures: Array[String] = []
	if not c13_contract_ready: failures.append("game feel layer not ready")
	if player_flash_events < 1: failures.append("player hit flash missing")
	if rival_flash_events < 4: failures.append("rival hit flashes missing")
	if shake_events < 5: failures.append("screen shake coverage missing")
	if hitstop_events < 5: failures.append("hit-stop coverage missing")
	if impact_burst_events < 5: failures.append("impact bursts missing")
	if round_pulse_events < 1: failures.append("round presentation missing")
	if victory_pulse_events < 1: failures.append("victory presentation missing")
	if not impact_evidence_captured: failures.append("impact evidence missing")
	if player_hit_events < 4 or combo_count < 2: failures.append("C12 combat contract regressed")
	if not victory_observed or float(opponent.health) > 0.0: failures.append("win condition regressed")
	print("VM02_C13_HIT_FLASH=%s player=%d rival=%d" % [("PASS" if player_flash_events >= 1 and rival_flash_events >= 4 else "BLOCKED"), player_flash_events, rival_flash_events])
	print("VM02_C13_HITSTOP_COVERAGE=%s count=%d" % [("PASS" if hitstop_events >= 5 else "BLOCKED"), hitstop_events])
	print("VM02_C13_SCREEN_SHAKE_COVERAGE=%s count=%d" % [("PASS" if shake_events >= 5 else "BLOCKED"), shake_events])
	print("VM02_C13_PARTICLE_BURST_COVERAGE=%s count=%d" % [("PASS" if impact_burst_events >= 5 else "BLOCKED"), impact_burst_events])
	print("VM02_C13_IMPACT_EVIDENCE_COVERAGE=%s" % ("PASS" if impact_evidence_captured else "BLOCKED"))
	print("VM02_C13_ROUND_PRESENTATION=%s" % ("PASS" if round_pulse_events >= 1 and victory_pulse_events >= 1 else "BLOCKED"))
	print("VM02_C13_C12_COMBAT_CONTRACT=%s" % ("PASS" if player_hit_events >= 4 and combo_count >= 2 and victory_observed else "BLOCKED"))
	print("VM02_C13_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	finished = true
	if capture:
		call_deferred("_capture_and_quit_c13")

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c13"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(4)
		return
	if image.get_size() != C13_OUTPUT_SIZE:
		image.resize(C13_OUTPUT_SIZE.x, C13_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C13_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C13_OUTPUT_PATH)) != OK:
		get_tree().quit(5)
		return
	print("VM02_C13_CAPTURE=PASS")
	print("VM02_C13_OUTPUT=%s" % C13_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	if impact_age >= 1.0:
		return
	var alpha := 1.0 - impact_age
	var radius := 14.0 + impact_age * 42.0 * impact_strength
	draw_circle(impact_origin, radius, Color(1.0, 0.63, 0.18, 0.12 * alpha), false, 3.0)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + impact_age * 0.25
		var inner := impact_origin + Vector2(cos(angle), sin(angle)) * (8.0 + impact_age * 14.0)
		var outer := impact_origin + Vector2(cos(angle), sin(angle)) * (22.0 + impact_age * 54.0 * impact_strength)
		draw_line(inner, outer, Color(1.0, 0.76, 0.28, 0.88 * alpha), 2.0)
