extends "res://scripts/runtime/first_playable_game_feel.gd"

## VM02-C14 — impact readability + reaction polish.
## Adds clearer contact-core feedback and visual reaction only.
## Combat damage/range/timing remains inherited from C13.
## Tehkné Solutions

const C14_OUTPUT_SIZE := Vector2i(1920, 1080)
const C14_OUTPUT_PATH := "res://artifacts/vm02-c14/first-playable-impact-polish-1920x1080.png"
const C14_IMPACT_OUTPUT_PATH := "res://artifacts/vm02-c14/impact-readability-1920x1080.png"

var contact_core_events := 0
var reaction_readability_events := 0
var body_hook_readability := false
var sweep_readability := false
var c14_impact_evidence_captured := false
var reaction_offset := Vector2.ZERO
var reaction_remaining := 0.0
var base_rival_local_position := Vector2.ZERO

func _ready() -> void:
	super._ready()
	base_rival_local_position = rival_visual.position
	print("VM02_C14_IMPACT_POLISH_READY=PASS")

func _impact_forward() -> float:
	# Do not depend on a controller-specific facing_right property.
	# The opponent position is the authoritative combat-space direction.
	return 1.0 if opponent.global_position.x >= player.global_position.x else -1.0

func _trigger_player_impact() -> void:
	super._trigger_player_impact()
	contact_core_events += 1
	impact_origin = player.global_position + Vector2(10.0 * _impact_forward(), -43.0)
	impact_strength = maxf(impact_strength, 0.82)
	print("VM02_C14_CONTACT_CORE=PASS target=player count=%d" % contact_core_events)

func _trigger_rival_impact() -> void:
	var technique := String(player.current_technique_id)
	super._trigger_rival_impact()
	contact_core_events += 1
	reaction_readability_events += 1
	impact_origin = (player.global_position + opponent.global_position) * 0.5 + Vector2(0, -43)
	if technique == "ji_body_hook":
		body_hook_readability = true
		impact_strength = 1.15
		reaction_offset = Vector2(5.0 * _impact_forward(), -1.0)
		reaction_remaining = 0.10
	else:
		sweep_readability = true
		impact_strength = 1.38
		reaction_offset = Vector2(9.0 * _impact_forward(), 3.0)
		reaction_remaining = 0.14
	rival_visual.position = base_rival_local_position + reaction_offset
	print("VM02_C14_REACTION_READABILITY=PASS technique=%s count=%d" % [technique, reaction_readability_events])
	print("VM02_C14_TECHNIQUE_IMPACT=%s strength=%.2f" % [technique, impact_strength])
	queue_redraw()

func _update_game_feel(delta: float) -> void:
	super._update_game_feel(delta)
	if reaction_remaining > 0.0:
		reaction_remaining = maxf(0.0, reaction_remaining - delta)
		var t := reaction_remaining / 0.14
		rival_visual.position = base_rival_local_position + reaction_offset * clampf(t, 0.0, 1.0)
	else:
		rival_visual.position = rival_visual.position.lerp(base_rival_local_position, minf(1.0, delta * 24.0))

func _capture_impact_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c14"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C14_IMPACT_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C14_OUTPUT_SIZE:
		image.resize(C14_OUTPUT_SIZE.x, C14_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C14_IMPACT_OUTPUT_PATH)) != OK:
		print("VM02_C14_IMPACT_EVIDENCE=BLOCKED save_failed")
		return
	impact_evidence_captured = true
	c14_impact_evidence_captured = true
	print("VM02_C14_IMPACT_EVIDENCE=PASS")
	print("VM02_C14_IMPACT_OUTPUT=%s" % C14_IMPACT_OUTPUT_PATH)

func _finish_gate() -> void:
	if impact_evidence_requested and not c14_impact_evidence_captured:
		for _i in range(20):
			await get_tree().process_frame
			if c14_impact_evidence_captured:
				break
	# C13 completes combo bookkeeping a few physics frames after victory.
	if combo_count < 2 and victory_observed:
		for _i in range(40):
			await get_tree().physics_frame
			if combo_count >= 2:
				break
	var local_failures: Array[String] = []
	if contact_core_events < 5: local_failures.append("contact core coverage missing")
	if reaction_readability_events < 4: local_failures.append("reaction readability missing")
	if not body_hook_readability: local_failures.append("body hook contrast missing")
	if not sweep_readability: local_failures.append("sweep contrast missing")
	if not c14_impact_evidence_captured: local_failures.append("C14 impact evidence missing")
	var c13_contract_ok := player_hit_events >= 4 and combo_count >= 2 and victory_observed
	if not c13_contract_ok: local_failures.append("C13 combat contract regressed")
	print("VM02_C14_CONTACT_CORE_COVERAGE=%s count=%d" % [("PASS" if contact_core_events >= 5 else "BLOCKED"), contact_core_events])
	print("VM02_C14_REACTION_READABILITY=%s count=%d" % [("PASS" if reaction_readability_events >= 4 else "BLOCKED"), reaction_readability_events])
	print("VM02_C14_TECHNIQUE_CONTRAST=%s body_hook=%s sweep=%s" % [("PASS" if body_hook_readability and sweep_readability else "BLOCKED"), str(body_hook_readability), str(sweep_readability)])
	print("VM02_C14_IMPACT_EVIDENCE_COVERAGE=%s" % ("PASS" if c14_impact_evidence_captured else "BLOCKED"))
	print("VM02_C14_C13_CONTRACT=%s" % ("PASS" if c13_contract_ok else "BLOCKED"))
	print("VM02_C14_RUNTIME=%s" % ("PASS" if local_failures.is_empty() else "BLOCKED"))
	for failure in local_failures:
		push_error(failure)
	if not local_failures.is_empty():
		if capture: get_tree().quit(6)
		return
	super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c14"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(7)
		return
	if image.get_size() != C14_OUTPUT_SIZE:
		image.resize(C14_OUTPUT_SIZE.x, C14_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C14_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C14_OUTPUT_PATH)) != OK:
		get_tree().quit(8)
		return
	print("VM02_C14_CAPTURE=PASS")
	print("VM02_C14_OUTPUT=%s" % C14_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	if impact_age >= 1.0:
		return
	var alpha := 1.0 - impact_age
	var core_radius := 7.0 + impact_age * 8.0
	draw_circle(impact_origin, core_radius, Color(1.0, 0.96, 0.78, 0.95 * alpha), true)
	draw_circle(impact_origin, 15.0 + impact_age * 30.0 * impact_strength, Color(1.0, 0.42, 0.10, 0.72 * alpha), false, 4.0)
	draw_circle(impact_origin, 24.0 + impact_age * 46.0 * impact_strength, Color(1.0, 0.78, 0.28, 0.38 * alpha), false, 2.0)
	var forward := _impact_forward()
	for i in range(5):
		var spread := float(i - 2) * 0.18
		var direction := Vector2(forward, spread).normalized()
		var start := impact_origin + direction * 9.0
		var finish := impact_origin + direction * (38.0 + 22.0 * impact_strength) * (1.0 - impact_age * 0.45)
		draw_line(start, finish, Color(1.0, 0.88, 0.52, 0.92 * alpha), 3.0)
