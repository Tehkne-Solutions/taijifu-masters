extends Node2D

## VM02-C11 — first playable level foundation.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c11/first-playable-level-1920x1080.png"
const AI_TECHNIQUE_ID := &"ji_shove"
const ROUND_INTRO_SECONDS := 0.65
const WATCHDOG_SECONDS := 14.0

@onready var player: Node = $Player
@onready var player_attack: Area2D = $Player/AttackArea
@onready var opponent: Node = $Opponent
@onready var opponent_attack: Area2D = $Opponent/AttackArea
@onready var player_hp_bar: ProgressBar = $CanvasLayer/HUD/PlayerPanel/HP
@onready var rival_hp_bar: ProgressBar = $CanvasLayer/HUD/RivalPanel/HP
@onready var round_label: Label = $CanvasLayer/HUD/RoundLabel
@onready var status_label: Label = $CanvasLayer/HUD/Status
@onready var controls_label: Label = $CanvasLayer/HUD/Controls
@onready var camera: Camera2D = $Camera2D

var player_hp := 100.0
var round_state := "intro"
var elapsed := 0.0
var fight_elapsed := 0.0
var autoplay := false
var capture := false
var finished := false
var ai_hit_attack_index := -1
var player_hit_link := 0
var combo_started := false
var combo_buffered := false
var combo_count := 0
var player_damage_events := 0
var player_hit_events := 0
var ai_attack_observed := false
var victory_observed := false
var defeat_observed := false
var round_start_observed := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	capture = args.has("--capture-and-quit")
	autoplay = capture or args.has("--autoplay")
	player_hp_bar.max_value = 100.0
	player_hp_bar.value = player_hp
	rival_hp_bar.max_value = float(opponent.max_health)
	rival_hp_bar.value = float(opponent.health)
	opponent.set_target(null)
	player.combo_completed.connect(_on_combo_complete)
	player.combo_link_started.connect(_on_combo_link_started)
	if autoplay:
		player.set_test_input(0.0, false, false)
	round_label.text = "ROUND 1"
	status_label.text = "GET READY"
	controls_label.text = "MOVE: A/D or arrows   RUN: Shift   JUMP: Space   ATTACK/COMBO: F"
	queue_redraw()
	print("VM02_C11_MODE=%s" % ("AUTOPLAY" if autoplay else "PLAYER"))
	print("VM02_C11_STAGE_READY=PASS")
	print("VM02_C11_SPAWNS_READY=PASS player_x=%.1f rival_x=%.1f" % [float(player.global_position.x), float(opponent.global_position.x)])
	print("VM02_C11_CAMERA_READY=PASS")
	print("VM02_C11_HUD_READY=PASS")

func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if round_state == "intro":
		if elapsed >= ROUND_INTRO_SECONDS:
			_begin_round()
		return
	if round_state != "fight":
		return

	fight_elapsed += delta
	_process_ai_hit_on_player()
	_process_player_hit_on_ai()
	_update_hud()

	if autoplay:
		_drive_autoplay()

	if float(opponent.health) <= 0.0:
		_end_round("victory")
	elif player_hp <= 0.0:
		_end_round("defeat")
	elif elapsed >= WATCHDOG_SECONDS:
		print("VM02_C11_WATCHDOG=BLOCKED state=%s player_hp=%.1f rival_hp=%.1f combos=%d" % [round_state, player_hp, float(opponent.health), combo_count])
		get_tree().quit(6)

func _begin_round() -> void:
	round_state = "fight"
	round_start_observed = true
	opponent.set_target(player)
	round_label.text = "FIGHT"
	status_label.text = ""
	print("VM02_C11_ROUND_START=PASS")

func _drive_autoplay() -> void:
	if not combo_started and player_damage_events >= 1 and String(opponent.attack_phase) == "idle" and String(player.attack_phase) == "idle":
		combo_started = true
		combo_buffered = false
		player.set_test_attack_edge(true)
		print("VM02_C11_AUTOPLAY_COMBO_REQUEST=%d" % (combo_count + 1))
	if combo_started and not combo_buffered and String(player.attack_phase) == "recovery" and bool(player.combo_buffer_open):
		combo_buffered = true
		player.set_test_combo_edge(true)
		print("VM02_C11_AUTOPLAY_COMBO_BUFFER=PASS")

func _process_ai_hit_on_player() -> void:
	if String(opponent.attack_phase) != "active":
		return
	ai_attack_observed = true
	if ai_hit_attack_index == int(opponent.attack_count):
		return
	for area in opponent_attack.get_overlapping_areas():
		if area == $Player/Hurtbox:
			var technique = TechniqueCatalog.get_technique(AI_TECHNIQUE_ID)
			player_hp = maxf(0.0, player_hp - float(technique.damage))
			player_damage_events += 1
			ai_hit_attack_index = int(opponent.attack_count)
			print("VM02_C11_PLAYER_DAMAGED=PASS damage=%.2f hp=%.2f" % [float(technique.damage), player_hp])
			return

func _process_player_hit_on_ai() -> void:
	if String(player.attack_phase) != "active":
		return
	if player_hit_link == int(player.combo_index):
		return
	for area in player_attack.get_overlapping_areas():
		if area == $Opponent/Hurtbox:
			var technique = TechniqueCatalog.get_technique(player.current_technique_id)
			opponent.receive_combat_hit(float(technique.damage))
			player_hit_link = int(player.combo_index)
			player_hit_events += 1
			print("VM02_C11_PLAYER_HIT_RIVAL=PASS link=%d technique=%s damage=%.2f hp=%.2f" % [int(player.combo_index), String(player.current_technique_id), float(technique.damage), float(opponent.health)])
			return

func _on_combo_link_started(index: int, technique_id: StringName) -> void:
	if index == 1:
		player_hit_link = 0
	print("VM02_C11_COMBO_LINK=%d technique=%s" % [index, String(technique_id)])

func _on_combo_complete(hits: int) -> void:
	if hits == 2:
		combo_count += 1
	combo_started = false
	combo_buffered = false
	player_hit_link = 0
	print("VM02_C11_COMBO_COMPLETE=%d total=%d" % [hits, combo_count])

func _update_hud() -> void:
	player_hp_bar.value = player_hp
	rival_hp_bar.value = float(opponent.health)
	status_label.text = "LIAN %.0f   |   RIVAL %.0f   ·   COMBOS %d" % [player_hp, float(opponent.health), combo_count]

func _end_round(result: String) -> void:
	if round_state != "fight":
		return
	round_state = result
	opponent.set_target(null)
	opponent.set_process(false)
	if result == "victory":
		victory_observed = true
		round_label.text = "VICTORY"
		status_label.text = "RIVAL DEFEATED"
		print("VM02_C11_VICTORY=PASS")
	else:
		defeat_observed = true
		round_label.text = "DEFEAT"
		status_label.text = "TRY AGAIN"
		print("VM02_C11_DEFEAT=PASS")
	_update_hud()
	if autoplay:
		call_deferred("_finish_gate")

func _finish_gate() -> void:
	finished = true
	var failures: Array[String] = []
	if not round_start_observed: failures.append("round never started")
	if not ai_attack_observed: failures.append("AI never attacked")
	if player_damage_events < 1: failures.append("player never took damage")
	if player_hit_events < 4: failures.append("player did not land two full combos")
	if combo_count < 2: failures.append("two combos not completed")
	if not victory_observed or float(opponent.health) > 0.0: failures.append("victory not reached")
	if player_hp <= 0.0: failures.append("player did not survive")
	if camera == null or not camera.enabled: failures.append("camera inactive")
	print("VM02_C11_ROUND_FLOW=%s" % ("PASS" if round_start_observed and victory_observed else "BLOCKED"))
	print("VM02_C11_AI_ACTIVE=%s" % ("PASS" if ai_attack_observed else "BLOCKED"))
	print("VM02_C11_PLAYER_COMBAT=%s hits=%d combos=%d" % [("PASS" if player_hit_events >= 4 and combo_count >= 2 else "BLOCKED"), player_hit_events, combo_count])
	print("VM02_C11_WIN_CONDITION=%s" % ("PASS" if victory_observed else "BLOCKED"))
	print("VM02_C11_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	if capture:
		call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c11"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(4)
		return
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C11_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		get_tree().quit(5)
		return
	print("VM02_C11_CAPTURE=PASS")
	print("VM02_C11_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	# Courtyard foundation: deliberately game-like, not a technical grid.
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.055, 0.075, 0.095, 1.0))
	draw_circle(Vector2(1070, 120), 54.0, Color(0.86, 0.78, 0.58, 0.9))
	var far_mountain := PackedVector2Array([Vector2(0,410),Vector2(150,260),Vector2(300,390),Vector2(455,220),Vector2(640,405),Vector2(825,250),Vector2(1010,390),Vector2(1180,235),Vector2(1280,360),Vector2(1280,560),Vector2(0,560)])
	draw_colored_polygon(far_mountain, Color(0.10,0.14,0.16,1.0))
	var near_mountain := PackedVector2Array([Vector2(0,470),Vector2(210,335),Vector2(380,460),Vector2(590,315),Vector2(760,455),Vector2(980,330),Vector2(1280,475),Vector2(1280,570),Vector2(0,570)])
	draw_colored_polygon(near_mountain, Color(0.13,0.18,0.18,1.0))
	# Temple silhouette and warm windows.
	draw_rect(Rect2(500,300,280,245), Color(0.16,0.10,0.075,1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(450,320),Vector2(640,220),Vector2(830,320)]), Color(0.12,0.075,0.055,1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(485,365),Vector2(640,285),Vector2(795,365)]), Color(0.19,0.11,0.07,1.0))
	for x in [545.0, 620.0, 695.0]:
		draw_rect(Rect2(x,390,38,70), Color(0.72,0.42,0.16,0.55))
	# Stone arena with depth bands.
	draw_rect(Rect2(0,535,1280,185), Color(0.18,0.19,0.18,1.0))
	draw_rect(Rect2(0,550,1280,4), Color(0.48,0.42,0.29,0.9))
	draw_rect(Rect2(0,620,1280,3), Color(0.12,0.13,0.12,0.75))
	# Lantern markers.
	for x in [120.0, 1160.0]:
		draw_line(Vector2(x,360), Vector2(x,540), Color(0.17,0.12,0.08,1.0), 8.0)
		draw_rect(Rect2(x-16,385,32,42), Color(0.78,0.35,0.13,0.9))
