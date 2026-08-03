extends "res://scripts/runtime/first_playable_defense_stamina.gd"

## VM02-C16 — Guard Break / Parry Foundation.
## Adds a timed parry window, guard integrity, guard break recovery,
## cleaner defensive HUD presentation and deterministic evidence.
## Tehkné Solutions

const C16_OUTPUT_SIZE := Vector2i(1920, 1080)
const C16_OUTPUT_PATH := "res://artifacts/vm02-c16/first-playable-guard-break-parry-1920x1080.png"
const C16_PARRY_OUTPUT_PATH := "res://artifacts/vm02-c16/parry-evidence-1920x1080.png"
const C16_BREAK_OUTPUT_PATH := "res://artifacts/vm02-c16/guard-break-evidence-1920x1080.png"
const GUARD_MAX := 100.0
const GUARD_BLOCK_COST := 100.0
const GUARD_REGEN_PER_SECOND := 34.0
const GUARD_BREAK_SECONDS := 0.55
const PARRY_WINDOW_SECONDS := 0.13

var guard_integrity := GUARD_MAX
var guard_low_watermark := GUARD_MAX
var guard_broken := false
var guard_break_remaining := 0.0
var guard_break_observed := false
var guard_recovery_observed := false
var parry_window_remaining := 0.0
var parry_observed := false
var parry_damage_negated := false
var parry_evidence_captured := false
var guard_break_evidence_captured := false
var autoplay_parry_armed := false
var autoplay_block_armed := false

var stamina_bar: ProgressBar
var guard_bar: ProgressBar
var defense_label: Label

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D MOVE   SHIFT RUN   SPACE JUMP   F ATTACK/COMBO   R BLOCK   V PARRY"
	_create_defense_hud()
	print("VM02_C16_GUARD_PARRY_READY=PASS")

func _create_defense_hud() -> void:
	var hud := $CanvasLayer/HUD
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.position = Vector2(54, 92)
	stamina_bar.size = Vector2(360, 10)
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = stamina
	stamina_bar.show_percentage = false
	hud.add_child(stamina_bar)
	guard_bar = ProgressBar.new()
	guard_bar.name = "GuardBar"
	guard_bar.position = Vector2(54, 108)
	guard_bar.size = Vector2(360, 8)
	guard_bar.max_value = GUARD_MAX
	guard_bar.value = guard_integrity
	guard_bar.show_percentage = false
	hud.add_child(guard_bar)
	defense_label = Label.new()
	defense_label.name = "DefenseState"
	defense_label.position = Vector2(425, 88)
	defense_label.size = Vector2(240, 32)
	defense_label.text = "STAMINA 100 · GUARD 100"
	hud.add_child(defense_label)
	print("VM02_C16_DEFENSE_HUD=PASS")

func _physics_process(delta: float) -> void:
	_update_parry_input(delta)
	if guard_broken:
		guard_break_remaining = maxf(0.0, guard_break_remaining - delta)
		if guard_break_remaining <= 0.0:
			guard_broken = false
			guard_integrity = maxf(42.0, guard_integrity)
			guard_recovery_observed = true
			print("VM02_C16_GUARD_RECOVERY=PASS guard=%.1f" % guard_integrity)
	elif not blocking and round_state == "fight" and guard_integrity < GUARD_MAX:
		guard_integrity = minf(GUARD_MAX, guard_integrity + GUARD_REGEN_PER_SECOND * delta)
	super._physics_process(delta)
	if stamina_bar != null:
		stamina_bar.value = stamina
	if guard_bar != null:
		guard_bar.value = guard_integrity
	if defense_label != null:
		var mode := "BREAK" if guard_broken else ("PARRY" if parry_window_remaining > 0.0 else ("BLOCK" if blocking else "READY"))
		defense_label.text = "STAMINA %.0f · GUARD %.0f · %s" % [stamina, guard_integrity, mode]

func _update_parry_input(delta: float) -> void:
	if parry_window_remaining > 0.0:
		parry_window_remaining = maxf(0.0, parry_window_remaining - delta)
	if round_state != "fight" or guard_broken:
		return
	if autoplay:
		if int(opponent.attack_count) == 1 and not autoplay_parry_armed and String(opponent.attack_phase) == "startup":
			autoplay_parry_armed = true
			parry_window_remaining = PARRY_WINDOW_SECONDS
			print("VM02_C16_PARRY_WINDOW=PASS mode=autoplay")
	else:
		if Input.is_action_just_pressed(&"p1_parry") and String(player.attack_phase) == "idle":
			parry_window_remaining = PARRY_WINDOW_SECONDS
			print("VM02_C16_PARRY_WINDOW=PASS mode=player")

func _should_block() -> bool:
	if guard_broken:
		return false
	if autoplay:
		# First AI attack is reserved for parry. Second defensive contact
		# is a block that intentionally breaks guard for deterministic coverage.
		if int(opponent.attack_count) <= 1:
			return false
		if not autoplay_block_armed and int(opponent.attack_count) == 2:
			autoplay_block_armed = true
		return autoplay_block_armed and blocked_hits == 0 and int(opponent.attack_count) == 2 and stamina >= BLOCK_STAMINA_COST
	return super._should_block()

func _process_ai_hit_on_player() -> void:
	if String(opponent.attack_phase) != "active":
		return
	ai_attack_observed = true
	if ai_hit_attack_index == int(opponent.attack_count):
		return
	for area in opponent_attack.get_overlapping_areas():
		if area != $Player/Hurtbox:
			continue
		if parry_window_remaining > 0.0 and not guard_broken:
			ai_hit_attack_index = int(opponent.attack_count)
			parry_window_remaining = 0.0
			parry_observed = true
			parry_damage_negated = true
			block_effect_remaining = 0.22
			print("VM02_C16_PARRY=PASS damage=0.00 attack=%d" % int(opponent.attack_count))
			if not parry_evidence_captured:
				call_deferred("_capture_parry_evidence")
			queue_redraw()
			return

		var before_blocked := blocked_hits
		super._process_ai_hit_on_player()
		if blocked_hits > before_blocked:
			guard_integrity = maxf(0.0, guard_integrity - GUARD_BLOCK_COST)
			guard_low_watermark = minf(guard_low_watermark, guard_integrity)
			print("VM02_C16_GUARD_DAMAGE=PASS guard=%.1f" % guard_integrity)
			if guard_integrity <= 0.0:
				guard_broken = true
				guard_break_remaining = GUARD_BREAK_SECONDS
				guard_break_observed = true
				blocking = false
				print("VM02_C16_GUARD_BREAK=PASS recovery=%.2f" % GUARD_BREAK_SECONDS)
				if not guard_break_evidence_captured:
					call_deferred("_capture_guard_break_evidence")
		return

func _update_hud() -> void:
	# Keep the center status compact. Defense resources live in their own HUD.
	player_hp_bar.value = player_hp
	rival_hp_bar.value = float(opponent.health)
	status_label.text = "LIAN %.0f   |   RIVAL %.0f   ·   COMBOS %d" % [player_hp, float(opponent.health), combo_count]

func _capture_parry_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c16"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): return
	if image.get_size() != C16_OUTPUT_SIZE:
		image.resize(C16_OUTPUT_SIZE.x, C16_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C16_PARRY_OUTPUT_PATH)) == OK:
		parry_evidence_captured = true
		print("VM02_C16_PARRY_EVIDENCE=PASS")
		print("VM02_C16_PARRY_OUTPUT=%s" % C16_PARRY_OUTPUT_PATH)

func _capture_guard_break_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c16"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): return
	if image.get_size() != C16_OUTPUT_SIZE:
		image.resize(C16_OUTPUT_SIZE.x, C16_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C16_BREAK_OUTPUT_PATH)) == OK:
		guard_break_evidence_captured = true
		print("VM02_C16_GUARD_BREAK_EVIDENCE=PASS")
		print("VM02_C16_GUARD_BREAK_OUTPUT=%s" % C16_BREAK_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(40):
		if parry_evidence_captured and guard_break_evidence_captured and guard_recovery_observed:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not parry_observed: failures.append("parry missing")
	if not parry_damage_negated: failures.append("parry did not negate damage")
	if not guard_break_observed: failures.append("guard break missing")
	if not guard_recovery_observed: failures.append("guard recovery missing")
	if not parry_evidence_captured: failures.append("parry evidence missing")
	if not guard_break_evidence_captured: failures.append("guard break evidence missing")
	if stamina_bar == null or guard_bar == null or defense_label == null: failures.append("defense HUD missing")
	print("VM02_C16_PARRY_CONTRACT=%s" % ("PASS" if parry_observed and parry_damage_negated else "BLOCKED"))
	print("VM02_C16_GUARD_BREAK_CONTRACT=%s" % ("PASS" if guard_break_observed else "BLOCKED"))
	print("VM02_C16_GUARD_RECOVERY_CONTRACT=%s" % ("PASS" if guard_recovery_observed else "BLOCKED"))
	print("VM02_C16_DEFENSE_HUD_CONTRACT=%s" % ("PASS" if stamina_bar != null and guard_bar != null and defense_label != null else "BLOCKED"))
	print("VM02_C16_EVIDENCE_COVERAGE=%s" % ("PASS" if parry_evidence_captured and guard_break_evidence_captured else "BLOCKED"))
	print("VM02_C16_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures: push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(12)
		return
	super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c16"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(13)
		return
	if image.get_size() != C16_OUTPUT_SIZE:
		image.resize(C16_OUTPUT_SIZE.x, C16_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C16_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C16_OUTPUT_PATH)) != OK:
		get_tree().quit(14)
		return
	print("VM02_C16_CAPTURE=PASS")
	print("VM02_C16_OUTPUT=%s" % C16_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	if parry_window_remaining > 0.0:
		var center: Vector2 = player.global_position + Vector2(0.0, -44.0)
		draw_arc(center, 52.0, 0.0, TAU, 36, Color(0.72, 0.94, 1.0, 0.92), 4.0)
		draw_arc(center, 60.0, 0.0, TAU, 36, Color(1.0, 0.86, 0.38, 0.62), 2.0)
	if guard_broken:
		var break_center: Vector2 = player.global_position + Vector2(0.0, -46.0)
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(break_center + dir * 24.0, break_center + dir * 62.0, Color(1.0, 0.34, 0.16, 0.9), 3.0)
