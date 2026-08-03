extends "res://scripts/runtime/first_playable_impact_polish.gd"

## VM02-C15 — Defense + stamina foundation.
## Adds hold-block, reduced damage/knockback, stamina spend/regeneration,
## and deterministic autoplay evidence without changing the C14 attack contract.
## Tehkné Solutions

const C15_OUTPUT_SIZE := Vector2i(1920, 1080)
const C15_OUTPUT_PATH := "res://artifacts/vm02-c15/first-playable-defense-stamina-1920x1080.png"
const C15_BLOCK_OUTPUT_PATH := "res://artifacts/vm02-c15/block-evidence-1920x1080.png"
const STAMINA_MAX := 100.0
const BLOCK_STAMINA_COST := 18.0
const STAMINA_REGEN_PER_SECOND := 28.0
const BLOCK_DAMAGE_MULTIPLIER := 0.35
const NORMAL_KNOCKBACK := 14.0
const BLOCK_KNOCKBACK_MULTIPLIER := 0.25

var stamina := STAMINA_MAX
var stamina_low_watermark := STAMINA_MAX
var blocked_hits := 0
var unblocked_hits := 0
var blocked_damage_total := 0.0
var unblocked_damage_total := 0.0
var block_damage_reduction_observed := false
var block_knockback_reduction_observed := false
var stamina_spend_observed := false
var stamina_regen_observed := false
var block_evidence_captured := false
var block_effect_remaining := 0.0
var blocking := false

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D MOVE   SHIFT RUN   SPACE JUMP   F ATTACK/COMBO   R BLOCK"
	print("VM02_C15_DEFENSE_STAMINA_READY=PASS")

func _physics_process(delta: float) -> void:
	blocking = _should_block()
	super._physics_process(delta)
	if not blocking and round_state == "fight" and stamina < STAMINA_MAX:
		var previous := stamina
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN_PER_SECOND * delta)
		if stamina > previous and stamina >= stamina_low_watermark + 4.0:
			stamina_regen_observed = true
	if block_effect_remaining > 0.0:
		block_effect_remaining = maxf(0.0, block_effect_remaining - delta)
		queue_redraw()

func _should_block() -> bool:
	if round_state != "fight" or stamina < BLOCK_STAMINA_COST:
		return false
	if autoplay:
		# Deterministic gate: absorb the first AI hit, then release block so
		# the same run proves both blocked and normal damage paths.
		return player_damage_events == 0 and int(opponent.attack_count) <= 1
	return Input.is_action_pressed(&"p1_block") and String(player.attack_phase) == "idle"

func _process_ai_hit_on_player() -> void:
	if String(opponent.attack_phase) != "active":
		return
	ai_attack_observed = true
	if ai_hit_attack_index == int(opponent.attack_count):
		return
	for area in opponent_attack.get_overlapping_areas():
		if area != $Player/Hurtbox:
			continue
		var technique = TechniqueCatalog.get_technique(AI_TECHNIQUE_ID)
		var raw_damage := float(technique.damage)
		var applied_damage := raw_damage
		var knockback := NORMAL_KNOCKBACK
		var did_block := blocking and stamina >= BLOCK_STAMINA_COST
		if did_block:
			applied_damage = raw_damage * BLOCK_DAMAGE_MULTIPLIER
			knockback *= BLOCK_KNOCKBACK_MULTIPLIER
			stamina = maxf(0.0, stamina - BLOCK_STAMINA_COST)
			stamina_low_watermark = minf(stamina_low_watermark, stamina)
			stamina_spend_observed = true
			blocked_hits += 1
			blocked_damage_total += applied_damage
			block_damage_reduction_observed = applied_damage < raw_damage
			block_knockback_reduction_observed = knockback < NORMAL_KNOCKBACK
			block_effect_remaining = 0.18
			print("VM02_C15_BLOCK_HIT=PASS raw=%.2f applied=%.2f stamina=%.1f knockback=%.1f" % [raw_damage, applied_damage, stamina, knockback])
			if not block_evidence_captured:
				call_deferred("_capture_block_evidence")
		else:
			unblocked_hits += 1
			unblocked_damage_total += applied_damage
			print("VM02_C15_NORMAL_HIT=PASS damage=%.2f" % applied_damage)
		player_hp = maxf(0.0, player_hp - applied_damage)
		var away := -1.0 if opponent.global_position.x >= player.global_position.x else 1.0
		player.global_position.x += away * knockback
		player_damage_events += 1
		ai_hit_attack_index = int(opponent.attack_count)
		print("VM02_C11_PLAYER_DAMAGED=PASS damage=%.2f hp=%.2f" % [applied_damage, player_hp])
		queue_redraw()
		return

func _update_hud() -> void:
	super._update_hud()
	status_label.text += "   ·   STAMINA %.0f   ·   BLOCK %s" % [stamina, ("ON" if blocking else "OFF")]

func _capture_block_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c15"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C15_BLOCK_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C15_OUTPUT_SIZE:
		image.resize(C15_OUTPUT_SIZE.x, C15_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C15_BLOCK_OUTPUT_PATH)) != OK:
		print("VM02_C15_BLOCK_EVIDENCE=BLOCKED save_failed")
		return
	block_evidence_captured = true
	print("VM02_C15_BLOCK_EVIDENCE=PASS")
	print("VM02_C15_BLOCK_OUTPUT=%s" % C15_BLOCK_OUTPUT_PATH)

func _finish_gate() -> void:
	if not block_evidence_captured:
		for _i in range(20):
			await get_tree().process_frame
			if block_evidence_captured:
				break
	if stamina > stamina_low_watermark + 4.0:
		stamina_regen_observed = true
	var failures: Array[String] = []
	if blocked_hits < 1: failures.append("block was never exercised")
	if unblocked_hits < 1: failures.append("normal damage path missing")
	if not block_damage_reduction_observed: failures.append("blocked damage was not reduced")
	if not block_knockback_reduction_observed: failures.append("blocked knockback was not reduced")
	if not stamina_spend_observed: failures.append("stamina was not spent")
	if not stamina_regen_observed: failures.append("stamina did not regenerate")
	if not block_evidence_captured: failures.append("block evidence missing")
	print("VM02_C15_BLOCK_DAMAGE_REDUCTION=%s blocked_hits=%d" % [("PASS" if block_damage_reduction_observed else "BLOCKED"), blocked_hits])
	print("VM02_C15_BLOCK_KNOCKBACK_REDUCTION=%s" % ("PASS" if block_knockback_reduction_observed else "BLOCKED"))
	print("VM02_C15_STAMINA_SPEND=%s low=%.1f" % [("PASS" if stamina_spend_observed else "BLOCKED"), stamina_low_watermark])
	print("VM02_C15_STAMINA_REGEN=%s final=%.1f" % [("PASS" if stamina_regen_observed else "BLOCKED"), stamina])
	print("VM02_C15_NORMAL_DAMAGE_PATH=%s hits=%d" % [("PASS" if unblocked_hits >= 1 else "BLOCKED"), unblocked_hits])
	print("VM02_C15_BLOCK_EVIDENCE_COVERAGE=%s" % ("PASS" if block_evidence_captured else "BLOCKED"))
	print("VM02_C15_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(9)
		return
	super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c15"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(10)
		return
	if image.get_size() != C15_OUTPUT_SIZE:
		image.resize(C15_OUTPUT_SIZE.x, C15_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C15_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C15_OUTPUT_PATH)) != OK:
		get_tree().quit(11)
		return
	print("VM02_C15_CAPTURE=PASS")
	print("VM02_C15_OUTPUT=%s" % C15_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	if block_effect_remaining <= 0.0:
		return
	var alpha := clampf(block_effect_remaining / 0.18, 0.0, 1.0)
	var center := player.global_position + Vector2(0.0, -44.0)
	draw_arc(center, 38.0, -2.1, 2.1, 28, Color(0.45, 0.78, 1.0, 0.9 * alpha), 5.0)
	draw_arc(center, 46.0, -2.0, 2.0, 28, Color(0.92, 0.84, 0.48, 0.55 * alpha), 2.0)
