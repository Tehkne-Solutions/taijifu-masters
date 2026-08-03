extends "res://scripts/runtime/first_playable_riposte_visual_polish.gd"

## VM02-C21 — hit reaction + spatial readability polish.
## Tehkné Solutions

const C21_OUTPUT_SIZE := Vector2i(1920, 1080)
const C21_OUTPUT_PATH := "res://artifacts/vm02-c21/first-playable-spatial-reaction-1920x1080.png"
const C21_REACTION_OUTPUT_PATH := "res://artifacts/vm02-c21/spatial-reaction-evidence-1920x1080.png"
const PLAYER_REACTION_PUSH := 12.0
const RIVAL_LIGHT_PUSH := 18.0
const RIVAL_SWEEP_PUSH := 26.0
const RIVAL_RIPOSTE_PUSH := 34.0
const ARENA_MIN_X := 250.0
const ARENA_MAX_X := 1030.0

var spatial_reaction_observed := false
var player_separation_observed := false
var rival_separation_observed := false
var technique_separation_observed := false
var spatial_evidence_captured := false
var previous_player_damage_events := 0
var previous_player_hit_events := 0
var previous_player_x := 0.0
var previous_rival_x := 0.0
var normal_hit_wait_observed := false

func _ready() -> void:
	super._ready()
	previous_player_damage_events = player_damage_events
	previous_player_hit_events = player_hit_events
	previous_player_x = float(player.global_position.x)
	previous_rival_x = float(opponent.global_position.x)
	print("VM02_C21_SPATIAL_REACTION_READY=PASS")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if round_state != "fight" and round_state != "victory":
		return
	_observe_and_apply_player_reaction()
	_observe_and_apply_rival_reaction()

func _drive_autoplay() -> void:
	# C21 creates more distance than the inherited combat gates. After the first
	# complete combo, give the AI one deterministic unblocked contact before the
	# next player combo starts so C15's normal-damage contract remains exercised.
	if combo_count >= 1 and unblocked_hits < 1:
		normal_hit_wait_observed = true
		return
	super._drive_autoplay()

func _observe_and_apply_player_reaction() -> void:
	if player_damage_events <= previous_player_damage_events:
		return
	previous_player_damage_events = player_damage_events
	var direction: float = -1.0 if float(player.global_position.x) <= float(opponent.global_position.x) else 1.0
	var before_x: float = float(player.global_position.x)
	player.global_position.x = clampf(before_x + direction * PLAYER_REACTION_PUSH, ARENA_MIN_X, ARENA_MAX_X)
	var moved: float = absf(float(player.global_position.x) - before_x)
	player_separation_observed = player_separation_observed or moved >= 1.0
	spatial_reaction_observed = spatial_reaction_observed or player_separation_observed
	previous_player_x = float(player.global_position.x)
	print("VM02_C21_PLAYER_SEPARATION=%s distance=%.1f" % [("PASS" if moved >= 1.0 else "BLOCKED"), moved])

func _observe_and_apply_rival_reaction() -> void:
	if player_hit_events <= previous_player_hit_events:
		return
	previous_player_hit_events = player_hit_events
	var direction: float = 1.0 if float(opponent.global_position.x) >= float(player.global_position.x) else -1.0
	var push_distance: float = RIVAL_LIGHT_PUSH
	var reaction_id := "light"
	if riposte_effect_remaining > 0.0:
		push_distance = RIVAL_RIPOSTE_PUSH
		reaction_id = "riposte"
	elif String(player.current_technique_id) == "ji_sweep":
		push_distance = RIVAL_SWEEP_PUSH
		reaction_id = "sweep"
	elif heavy_combo_active:
		push_distance = RIVAL_SWEEP_PUSH
		reaction_id = "heavy"
	var before_x: float = float(opponent.global_position.x)
	opponent.global_position.x = clampf(before_x + direction * push_distance, ARENA_MIN_X, ARENA_MAX_X)
	var moved: float = absf(float(opponent.global_position.x) - before_x)
	rival_separation_observed = rival_separation_observed or moved >= 1.0
	technique_separation_observed = technique_separation_observed or push_distance > RIVAL_LIGHT_PUSH
	spatial_reaction_observed = spatial_reaction_observed or rival_separation_observed
	previous_rival_x = float(opponent.global_position.x)
	print("VM02_C21_RIVAL_SEPARATION=%s reaction=%s distance=%.1f" % [("PASS" if moved >= 1.0 else "BLOCKED"), reaction_id, moved])
	if not spatial_evidence_captured and player_hit_events >= 2:
		call_deferred("_capture_spatial_evidence")

func _capture_spatial_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c21"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C21_SPATIAL_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C21_OUTPUT_SIZE:
		image.resize(C21_OUTPUT_SIZE.x, C21_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C21_REACTION_OUTPUT_PATH)) != OK:
		print("VM02_C21_SPATIAL_EVIDENCE=BLOCKED save_failed")
		return
	spatial_evidence_captured = true
	print("VM02_C21_SPATIAL_EVIDENCE=PASS")
	print("VM02_C21_SPATIAL_OUTPUT=%s" % C21_REACTION_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(48):
		if spatial_evidence_captured:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not spatial_reaction_observed: failures.append("spatial reaction missing")
	if not player_separation_observed: failures.append("player separation missing")
	if not rival_separation_observed: failures.append("rival separation missing")
	if not technique_separation_observed: failures.append("technique separation contrast missing")
	if not spatial_evidence_captured: failures.append("spatial reaction evidence missing")
	if autoplay and not normal_hit_wait_observed: failures.append("inherited normal-hit wait was not exercised")
	print("VM02_C21_SPATIAL_REACTION=%s" % ("PASS" if spatial_reaction_observed else "BLOCKED"))
	print("VM02_C21_PLAYER_SEPARATION=%s" % ("PASS" if player_separation_observed else "BLOCKED"))
	print("VM02_C21_RIVAL_SEPARATION=%s" % ("PASS" if rival_separation_observed else "BLOCKED"))
	print("VM02_C21_TECHNIQUE_SEPARATION=%s" % ("PASS" if technique_separation_observed else "BLOCKED"))
	print("VM02_C21_NORMAL_HIT_WAIT=%s" % ("PASS" if normal_hit_wait_observed else "BLOCKED"))
	print("VM02_C21_SPATIAL_EVIDENCE_COVERAGE=%s" % ("PASS" if spatial_evidence_captured else "BLOCKED"))
	print("VM02_C21_C20_CONTRACT=%s" % ("PASS" if riposte_visual_binding_observed and hud_cleanup_observed and riposte_visual_evidence_captured else "BLOCKED"))
	print("VM02_C21_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(21)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c21"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(22)
		return
	if image.get_size() != C21_OUTPUT_SIZE:
		image.resize(C21_OUTPUT_SIZE.x, C21_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C21_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C21_OUTPUT_PATH)) != OK:
		get_tree().quit(23)
		return
	print("VM02_C21_CAPTURE=PASS")
	print("VM02_C21_OUTPUT=%s" % C21_OUTPUT_PATH)
	get_tree().quit(0)
