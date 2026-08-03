extends Node2D

## VM02-C10 — visual sparring rival integrated with validated opponent AI.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-c10/visual-rival-ai-integration-1920x1080.png"
const AI_TECHNIQUE_ID := &"ji_shove"

@onready var player: Node = $Player
@onready var player_attack: Area2D = $Player/AttackArea
@onready var opponent: Node = $Opponent
@onready var opponent_attack: Area2D = $Opponent/AttackArea
@onready var visual_rival: Node = $Opponent/VisualRival
@onready var hud_state: Label = $CanvasLayer/HUD/State
@onready var hud_metrics: Label = $CanvasLayer/HUD/Metrics

var player_hp := 100.0
var elapsed := 0.0
var ai_hit_player := false
var ai_hit_attack_index := -1
var player_hit_link := 0
var combo_started := false
var combo_buffered := false
var combo_complete := false
var visited_states: Array[String] = []
var visited_visual_states: Array[String] = []
var player_links: Array[StringName] = []
var finished := false
var capture := false

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	player.set_test_input(0.0, false, false)
	opponent.set_target(player)
	opponent.ai_state_changed.connect(_on_ai_state)
	player.combo_link_started.connect(_on_combo_link)
	player.combo_completed.connect(_on_combo_complete)
	_track_visual_state()
	print("VM02_C10_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	if finished: return
	elapsed += delta
	_process_ai_hit_on_player()
	_process_player_hit_on_ai()
	_track_visual_state()

	if ai_hit_player and not combo_started and String(opponent.attack_phase) == "idle":
		combo_started = true
		player.set_test_attack_edge(true)
		print("VM02_C10_PLAYER_COUNTER_REQUEST=1")
	if combo_started and not combo_buffered and String(player.attack_phase) == "recovery" and bool(player.combo_buffer_open):
		combo_buffered = true
		player.set_test_combo_edge(true)
		print("VM02_C10_PLAYER_COUNTER_BUFFER=PASS")

	hud_state.text = "AI: %s · %s · VISUAL:%s | PLAYER: %s · %s" % [String(opponent.ai_state).to_upper(), String(opponent.attack_phase).to_upper(), String(visual_rival.visual_state).to_upper(), String(player.current_technique_id), String(player.attack_phase).to_upper()]
	hud_metrics.text = "player_hp=%.1f ai_hp=%.1f attacks=%d counter_hits=%d visual_states=%d proxy=true" % [player_hp, float(opponent.health), int(opponent.attack_count), int(opponent.hit_count), visited_visual_states.size()]

	if combo_complete and String(opponent.ai_state) != "hitstun" and String(player.attack_phase) == "idle" and elapsed > 1.5:
		_finish_gate()
	elif elapsed > 7.0:
		print("VM02_C10_WATCHDOG=BLOCKED ai=%s visual=%s player_hp=%.1f ai_hp=%.1f" % [String(opponent.ai_state), String(visual_rival.visual_state), player_hp, float(opponent.health)])
		get_tree().quit(6)

func _process_ai_hit_on_player() -> void:
	if String(opponent.attack_phase) != "active": return
	if ai_hit_attack_index == int(opponent.attack_count): return
	for area in opponent_attack.get_overlapping_areas():
		if area == $Player/Hurtbox:
			var t = TechniqueCatalog.get_technique(AI_TECHNIQUE_ID)
			player_hp = maxf(0.0, player_hp - float(t.damage))
			ai_hit_player = true
			ai_hit_attack_index = int(opponent.attack_count)
			print("VM02_C10_AI_HIT_PLAYER=PASS damage=%.2f player_hp=%.2f" % [float(t.damage), player_hp])
			return

func _process_player_hit_on_ai() -> void:
	if String(player.attack_phase) != "active": return
	if player_hit_link == int(player.combo_index): return
	for area in player_attack.get_overlapping_areas():
		if area == $Opponent/Hurtbox:
			var t = TechniqueCatalog.get_technique(player.current_technique_id)
			opponent.receive_combat_hit(float(t.damage))
			player_hit_link = int(player.combo_index)
			print("VM02_C10_PLAYER_HIT_AI=PASS link=%d technique=%s damage=%.2f" % [int(player.combo_index), String(player.current_technique_id), float(t.damage)])
			return

func _on_ai_state(state: String) -> void:
	if state not in visited_states: visited_states.append(state)
	call_deferred("_track_visual_state")

func _track_visual_state() -> void:
	var state_name := String(visual_rival.visual_state)
	if state_name not in visited_visual_states:
		visited_visual_states.append(state_name)
		print("VM02_C10_VISUAL_STATE=%s" % state_name)

func _on_combo_link(_index: int, technique_id: StringName) -> void:
	player_links.append(technique_id)

func _on_combo_complete(hits: int) -> void:
	combo_complete = hits == 2
	print("VM02_C10_PLAYER_COMBO_COMPLETE=%d" % hits)

func _finish_gate() -> void:
	finished = true
	var failures: Array[String] = []
	for required_state in ["approach", "attack", "hitstun", "idle"]:
		if required_state not in visited_visual_states: failures.append("missing visual state %s" % required_state)
	if bool(opponent.draw_debug_body): failures.append("geometric debug body still enabled")
	if not bool(visual_rival.visual_ready): failures.append("visual rival not ready")
	if not bool(visual_rival.flip_h): failures.append("rival not mirrored toward player at finish")
	if not ai_hit_player or player_hp >= 100.0: failures.append("AI never damaged player")
	if int(opponent.hit_count) != 2 or int(opponent.reaction_count) < 2: failures.append("counter reaction invalid")
	if player_links.size() < 2 or player_links[0] != &"ji_body_hook" or player_links[1] != &"ji_sweep": failures.append("counter combo invalid")
	if not combo_complete: failures.append("combo incomplete")
	print("VM02_C10_VISUAL_BOUND_TO_AI=%s" % ("PASS" if failures.filter(func(x): return String(x).begins_with("missing visual state")).is_empty() else "BLOCKED"))
	print("VM02_C10_GEOMETRIC_PLACEHOLDER=%s" % ("OFF" if not bool(opponent.draw_debug_body) else "ON"))
	print("VM02_C10_VISUAL_STATE_COVERAGE=%s states=%s" % [("PASS" if ["approach","attack","hitstun","idle"].all(func(s): return s in visited_visual_states) else "BLOCKED"), str(visited_visual_states)])
	print("VM02_C10_AI_COMBAT_CONTRACT=%s" % ("PASS" if ai_hit_player and int(opponent.hit_count) == 2 and combo_complete else "BLOCKED"))
	print("VM02_C10_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for f in failures: push_error(f)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	if capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c10"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): get_tree().quit(4); return
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C10_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK: get_tree().quit(5); return
	print("VM02_C10_CAPTURE=PASS")
	print("VM02_C10_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
