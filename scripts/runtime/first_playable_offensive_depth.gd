extends "res://scripts/runtime/first_playable_guard_break_parry.gd"

## VM02-C17 — Offensive Combat Depth Foundation.
## Adds light/heavy attack intent, offensive stamina costs, heavy guard pressure,
## technique contrast and a compact defensive resource panel.
## Tehkné Solutions

const C17_OUTPUT_SIZE := Vector2i(1920, 1080)
const C17_OUTPUT_PATH := "res://artifacts/vm02-c17/first-playable-offensive-depth-1920x1080.png"
const C17_HEAVY_OUTPUT_PATH := "res://artifacts/vm02-c17/heavy-impact-evidence-1920x1080.png"
const LIGHT_STAMINA_COST := 6.0
const HEAVY_STAMINA_COST := 18.0
const HEAVY_DAMAGE_MULTIPLIER := 1.45
const HEAVY_GUARD_PRESSURE := 28.0

var current_attack_weight := "light"
var heavy_combo_active := false
var light_combo_observed := false
var heavy_combo_observed := false
var offensive_stamina_spend_observed := false
var light_damage_observed := false
var heavy_damage_observed := false
var heavy_guard_pressure_observed := false
var heavy_evidence_captured := false
var offensive_stamina_low := STAMINA_MAX
var rival_guard_pressure := 0.0
var defense_panel: Panel
var attack_weight_label: Label

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D MOVE   SHIFT RUN   SPACE JUMP   F LIGHT/COMBO   G+F HEAVY   R BLOCK   V PARRY"
	_refine_defense_hud()
	print("VM02_C17_OFFENSIVE_DEPTH_READY=PASS")

func _refine_defense_hud() -> void:
	var hud := $CanvasLayer/HUD
	defense_panel = Panel.new()
	defense_panel.name = "CombatResourcesPanel"
	defense_panel.position = Vector2(34, 88)
	defense_panel.size = Vector2(388, 62)
	hud.add_child(defense_panel)
	if stamina_bar != null:
		stamina_bar.reparent(defense_panel)
		stamina_bar.position = Vector2(14, 10)
		stamina_bar.size = Vector2(250, 10)
	if guard_bar != null:
		guard_bar.reparent(defense_panel)
		guard_bar.position = Vector2(14, 28)
		guard_bar.size = Vector2(250, 8)
	if defense_label != null:
		defense_label.reparent(defense_panel)
		defense_label.position = Vector2(14, 40)
		defense_label.size = Vector2(250, 18)
		defense_label.add_theme_font_size_override("font_size", 11)
	attack_weight_label = Label.new()
	attack_weight_label.name = "AttackWeight"
	attack_weight_label.position = Vector2(274, 12)
	attack_weight_label.size = Vector2(104, 34)
	attack_weight_label.text = "LIGHT"
	attack_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_weight_label.add_theme_font_size_override("font_size", 13)
	defense_panel.add_child(attack_weight_label)
	print("VM02_C17_RESOURCE_HUD=PASS")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if attack_weight_label != null:
		attack_weight_label.text = current_attack_weight.to_upper()
	if defense_label != null:
		var mode := "BREAK" if guard_broken else ("PARRY" if parry_window_remaining > 0.0 else ("BLOCK" if blocking else "READY"))
		defense_label.text = "STA %.0f  ·  GRD %.0f  ·  %s" % [stamina, guard_integrity, mode]

func _on_combo_link_started(index: int, technique_id: StringName) -> void:
	if index == 1:
		var wants_heavy := false
		if autoplay:
			wants_heavy = combo_count >= 1
		else:
			wants_heavy = Input.is_physical_key_pressed(KEY_G)
		heavy_combo_active = wants_heavy and stamina >= HEAVY_STAMINA_COST
		current_attack_weight = "heavy" if heavy_combo_active else "light"
		var cost := HEAVY_STAMINA_COST if heavy_combo_active else LIGHT_STAMINA_COST
		stamina = maxf(0.0, stamina - cost)
		stamina_low_watermark = minf(stamina_low_watermark, stamina)
		offensive_stamina_low = minf(offensive_stamina_low, stamina)
		offensive_stamina_spend_observed = true
		if heavy_combo_active:
			heavy_combo_observed = true
			print("VM02_C17_HEAVY_REQUEST=PASS stamina=%.1f" % stamina)
		else:
			light_combo_observed = true
			print("VM02_C17_LIGHT_REQUEST=PASS stamina=%.1f" % stamina)
	super._on_combo_link_started(index, technique_id)

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
		var applied_damage := base_damage * (HEAVY_DAMAGE_MULTIPLIER if heavy_combo_active else 1.0)
		opponent.receive_combat_hit(applied_damage)
		player_hit_link = int(player.combo_index)
		player_hit_events += 1
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
		print("VM02_C11_PLAYER_HIT_RIVAL=PASS link=%d technique=%s damage=%.2f hp=%.2f" % [int(player.combo_index), String(player.current_technique_id), applied_damage, float(opponent.health)])
		return

func _on_combo_complete(hits: int) -> void:
	super._on_combo_complete(hits)
	heavy_combo_active = false
	current_attack_weight = "light"

func _update_hud() -> void:
	player_hp_bar.value = player_hp
	rival_hp_bar.value = float(opponent.health)
	status_label.text = "LIAN %.0f   |   RIVAL %.0f   ·   COMBOS %d   ·   %s" % [player_hp, float(opponent.health), combo_count, current_attack_weight.to_upper()]

func _capture_heavy_evidence() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c17"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	if image.get_size() != C17_OUTPUT_SIZE:
		image.resize(C17_OUTPUT_SIZE.x, C17_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(C17_HEAVY_OUTPUT_PATH)) == OK:
		heavy_evidence_captured = true
		print("VM02_C17_HEAVY_EVIDENCE=PASS")
		print("VM02_C17_HEAVY_OUTPUT=%s" % C17_HEAVY_OUTPUT_PATH)

func _finish_gate() -> void:
	for _i in range(40):
		if heavy_evidence_captured:
			break
		await get_tree().physics_frame
	var failures: Array[String] = []
	if not light_combo_observed: failures.append("light combo missing")
	if not heavy_combo_observed: failures.append("heavy combo missing")
	if not offensive_stamina_spend_observed: failures.append("offensive stamina spend missing")
	if not light_damage_observed: failures.append("light damage contract missing")
	if not heavy_damage_observed: failures.append("heavy damage contrast missing")
	if not heavy_guard_pressure_observed: failures.append("heavy guard pressure missing")
	if not heavy_evidence_captured: failures.append("heavy evidence missing")
	if defense_panel == null or attack_weight_label == null: failures.append("resource HUD missing")
	print("VM02_C17_LIGHT_ATTACK=%s" % ("PASS" if light_combo_observed and light_damage_observed else "BLOCKED"))
	print("VM02_C17_HEAVY_ATTACK=%s" % ("PASS" if heavy_combo_observed and heavy_damage_observed else "BLOCKED"))
	print("VM02_C17_OFFENSIVE_STAMINA=%s low=%.1f" % [("PASS" if offensive_stamina_spend_observed else "BLOCKED"), offensive_stamina_low])
	print("VM02_C17_HEAVY_GUARD_PRESSURE=%s pressure=%.1f" % [("PASS" if heavy_guard_pressure_observed else "BLOCKED"), rival_guard_pressure])
	print("VM02_C17_RESOURCE_HUD_CONTRACT=%s" % ("PASS" if defense_panel != null and attack_weight_label != null else "BLOCKED"))
	print("VM02_C17_HEAVY_EVIDENCE_COVERAGE=%s" % ("PASS" if heavy_evidence_captured else "BLOCKED"))
	print("VM02_C17_C16_CONTRACT=%s" % ("PASS" if parry_observed and guard_break_observed and guard_recovery_observed else "BLOCKED"))
	print("VM02_C17_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture:
			get_tree().quit(17)
		return
	super._finish_gate()

func _capture_and_quit_c13() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c17"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(18)
		return
	if image.get_size() != C17_OUTPUT_SIZE:
		image.resize(C17_OUTPUT_SIZE.x, C17_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C17_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C17_OUTPUT_PATH)) != OK:
		get_tree().quit(19)
		return
	print("VM02_C17_CAPTURE=PASS")
	print("VM02_C17_OUTPUT=%s" % C17_OUTPUT_PATH)
	get_tree().quit(0)
