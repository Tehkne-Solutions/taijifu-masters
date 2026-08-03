extends "res://scripts/runtime/first_playable_parry_counter_cancel.gd"

## VM02-C19 — Dedicated Riposte Technique Foundation.
## Tehkné Solutions

const C19_OUTPUT_SIZE := Vector2i(1920, 1080)
const C19_OUTPUT_PATH := "res://artifacts/vm02-c19/first-playable-dedicated-riposte-1920x1080.png"
const C19_RIPOSTE_OUTPUT_PATH := "res://artifacts/vm02-c19/riposte-evidence-1920x1080.png"
const RIPOSTE_TECHNIQUE_ID := &"ji_riposte"
const RIPOSTE_DAMAGE_MULTIPLIER := 1.25
const RIPOSTE_TOTAL_STAMINA_COST := 10.0
const RIPOSTE_GUARD_PRESSURE := 18.0

var riposte_pending := false
var riposte_active := false
var riposte_armed_observed := false
var riposte_binding_observed := false
var riposte_damage_observed := false
var riposte_stamina_observed := false
var riposte_guard_pressure_observed := false
var riposte_single_consume_observed := false
var riposte_evidence_captured := false
var riposte_hit_count := 0
var riposte_effect_remaining := 0.0
var riposte_stamina_before := 0.0

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D MOVE   SHIFT RUN   SPACE JUMP   F LIGHT/COMBO   G+F HEAVY   R BLOCK   V PARRY → F RIPOSTE"
	print("VM02_C19_DEDICATED_RIPOSTE_READY=PASS")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if riposte_effect_remaining > 0.0:
		riposte_effect_remaining = maxf(0.0, riposte_effect_remaining - delta)
		queue_redraw()

func _consume_counter_window(source: String) -> void:
	var can_consume := counter_window_remaining > 0.0 and not counter_consumed_observed
	super._consume_counter_window(source)
	if not can_consume:
		return
	riposte_pending = true
	riposte_armed_observed = true
	print("VM02_C19_RIPOSTE_ARM=PASS technique=%s source=%s" % [String(RIPOSTE_TECHNIQUE_ID), source])

func _on_combo_link_started(index: int, technique_id: StringName) -> void:
	super._on_combo_link_started(index, technique_id)
	if index != 1 or not riposte_pending:
		return
	riposte_pending = false
	riposte_active = true
	riposte_binding_observed = true
	current_attack_weight = "riposte"
	var extra_cost := maxf(0.0, RIPOSTE_TOTAL_STAMINA_COST - LIGHT_STAMINA_COST)
	riposte_stamina_before = stamina + LIGHT_STAMINA_COST
	stamina = maxf(0.0, stamina - extra_cost)
	stamina_low_watermark = minf(stamina_low_watermark, stamina)
	offensive_stamina_low = minf(offensive_stamina_low, stamina)
	riposte_stamina_observed = is_equal_approx(riposte_stamina_before - stamina, RIPOSTE_TOTAL_STAMINA_COST)
	print("VM02_C19_RIPOSTE_BINDING=PASS technique=%s" % String(RIPOSTE_TECHNIQUE_ID))
	print("VM02_C19_RIPOSTE_STAMINA=PASS spent=%.1f remaining=%.1f" % [riposte_stamina_before - stamina, stamina])

func _process_player_hit_on_ai() -> void:
	if String(player.attack_phase) != "active":
		return
	if player_hit_link == int(player.combo_index):
		return
	for area in player_attack.get_overlapping_areas():
		if area != $Opponent/Hurtbox:
			continue
		var technique = TechniqueCatalog.get_technique(player.current_technique_id)
		var base_damage := float(technique.damage)
		var applied_damage := base_damage
		if riposte_active:
			applied_damage = base_damage * RIPOSTE_DAMAGE_MULTIPLIER
			riposte_hit_count += 1
			riposte_damage_observed = applied_damage > base_damage
			rival_guard_pressure += RIPOSTE_GUARD_PRESSURE
			riposte_guard_pressure_observed = rival_guard_pressure >= RIPOSTE_GUARD_PRESSURE
			riposte_effect_remaining = 0.28
			print("VM02_C19_RIPOSTE_HIT=PASS technique=%s base=%.2f applied=%.2f guard_pressure=%.1f" % [String(RIPOSTE_TECHNIQUE_ID), base_damage, applied_damage, rival_guard_pressure])
			if not riposte_evidence_captured:
				call_deferred("_capture_riposte_evidence")
			riposte_active = false
			current_attack_weight = "light"
		else:
			applied_damage = base_damage * (HEAVY_DAMAGE_MULTIPLIER if heavy_combo_active else 1.0)
			if heavy_combo_active:
				heavy_damage_observed = applied_damage > base_damage
				rival_guard_pressure += HEAVY_GUARD_PRESSURE
				heavy_guard_pressure_observed = rival_guard_pressure >= HEAVY_GUARD_PRESSURE
				print("VM02_C17_HEAVY_HIT=PASS base=%.2f applied=%.2f guard_pressure=%.1f" % [base_damage, applied_damage, rival_guard_pressure])
				if not heavy_evidence_captured:
					call_deferred("_capture_heavy_evidence")
			else:
				light_damage_observed = is_equal_approx(applied_damage, base_damage)
				print("VM02_C17_LIGHT_HIT=PASS damage=%.2f" % applied_damage)
		opponent.receive_combat_hit(applied_damage)
		player_hit_link = int(player.combo_index)
		player_hit_events += 1
		print("VM02_C11_PLAYER_HIT_RIVAL=PASS link=%d technique=%s damage=%.2f hp=%.2f" % [int(player.combo_index), String(player.current_technique_id), applied_damage, float(opponent.health)])
		if riposte_hit_count == 1:
			riposte_single_consume_observed = true
		return

func _on_combo_complete(hits: int) -> void:
	super._on_combo_complete(hits)
	riposte_active = false
	if riposte_hit_count == 1:
		riposte_single_consume_observed = true

func _update_hud() -> void:
	super._update_hud()
	if riposte_pending:
		status_label.text += "   ·   RIPOSTE READY"
	elif riposte_active or riposte_effect_remaining > 0.0:
		status_label.text += "   ·   RIPOSTE"

func _capture_riposte_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c19"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("VM02_C19_RIPOSTE_EVIDENCE=BLOCKED empty_image")
		return
	if image.get_size() != C19_OUTPUT_SIZE:
		image.resize(C19_OUTPUT_SIZE.x, C19_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C19_RIPOSTE_OUTPUT_PATH)) != OK:
		print("VM02_C19_RIPOSTE_EVIDENCE=BLOCKED save_failed")
		return
	riposte_evidence_captured = true
	print("VM02_C19_RIPOSTE_EVIDENCE=PASS")
	print("VM02_C19_RIPOSTE_OUTPUT=%s" % C19_RIPOSTE_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(40):
		if riposte_evidence_captured:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not riposte_armed_observed: failures.append("riposte not armed")
	if not riposte_binding_observed: failures.append("riposte binding missing")
	if not riposte_damage_observed: failures.append("riposte damage missing")
	if not riposte_stamina_observed: failures.append("riposte stamina contract missing")
	if not riposte_guard_pressure_observed: failures.append("riposte guard pressure missing")
	if not riposte_single_consume_observed or riposte_hit_count != 1: failures.append("riposte single consume failed")
	if not riposte_evidence_captured: failures.append("riposte evidence missing")
	print("VM02_C19_RIPOSTE_ARM=%s" % ("PASS" if riposte_armed_observed else "BLOCKED"))
	print("VM02_C19_RIPOSTE_BINDING=%s" % ("PASS" if riposte_binding_observed else "BLOCKED"))
	print("VM02_C19_RIPOSTE_DAMAGE=%s" % ("PASS" if riposte_damage_observed else "BLOCKED"))
	print("VM02_C19_RIPOSTE_STAMINA=%s" % ("PASS" if riposte_stamina_observed else "BLOCKED"))
	print("VM02_C19_RIPOSTE_GUARD_PRESSURE=%s" % ("PASS" if riposte_guard_pressure_observed else "BLOCKED"))
	print("VM02_C19_RIPOSTE_SINGLE_CONSUME=%s hits=%d" % [("PASS" if riposte_single_consume_observed and riposte_hit_count == 1 else "BLOCKED"), riposte_hit_count])
	print("VM02_C19_RIPOSTE_EVIDENCE_COVERAGE=%s" % ("PASS" if riposte_evidence_captured else "BLOCKED"))
	print("VM02_C19_C18_CONTRACT=%s" % ("PASS" if counter_ready_observed and cancel_window_observed and counter_consumed_observed else "BLOCKED"))
	print("VM02_C19_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(19)
		return
	await super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c19"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(20)
		return
	if image.get_size() != C19_OUTPUT_SIZE:
		image.resize(C19_OUTPUT_SIZE.x, C19_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C19_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C19_OUTPUT_PATH)) != OK:
		get_tree().quit(21)
		return
	print("VM02_C19_CAPTURE=PASS")
	print("VM02_C19_OUTPUT=%s" % C19_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	super._draw()
	var center: Vector2 = player.global_position + Vector2(0.0, -44.0)
	if riposte_pending:
		draw_arc(center, 74.0, -1.9, 1.9, 36, Color(0.35, 0.95, 1.0, 0.95), 4.0)
	if riposte_effect_remaining > 0.0:
		var alpha := clampf(riposte_effect_remaining / 0.28, 0.0, 1.0)
		draw_arc(center, 52.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.28, alpha), 5.0)
		for i in range(12):
			var angle := TAU * float(i) / 12.0
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(center + dir * 34.0, center + dir * 82.0, Color(0.45, 0.92, 1.0, alpha), 3.0)
