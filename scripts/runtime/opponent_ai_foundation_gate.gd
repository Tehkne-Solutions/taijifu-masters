extends Node2D

## VM02-C8 — deterministic opponent AI confrontation gate.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-c8/lian-wu-opponent-ai-foundation-1920x1080.png"

@onready var player: Node = $Player
@onready var player_attack: Area2D = $Player/AttackArea
@onready var opponent: OpponentAIFoundation = $Opponent
@onready var opponent_attack: Area2D = $Opponent/AttackArea
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
	print("VM02_C8_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	if finished: return
	elapsed += delta
	_process_ai_hit_on_player()
	_process_player_hit_on_ai()

	if ai_hit_player and not combo_started and opponent.attack_phase == "idle":
		combo_started = true
		player.set_test_attack_edge(true)
		print("VM02_C8_PLAYER_COUNTER_REQUEST=1")
	if combo_started and not combo_buffered and player.attack_phase == "recovery" and player.combo_buffer_open:
		combo_buffered = true
		player.set_test_combo_edge(true)
		print("VM02_C8_PLAYER_COUNTER_BUFFER=PASS")

	hud_state.text = "AI: %s · %s | PLAYER: %s · %s" % [opponent.ai_state.to_upper(), opponent.attack_phase.to_upper(), String(player.current_technique_id), String(player.attack_phase).to_upper()]
	hud_metrics.text = "player_hp=%.1f ai_hp=%.1f ai_attacks=%d ai_hits=%d counter_hits=%d combo=%s" % [player_hp, opponent.health, opponent.attack_count, (1 if ai_hit_player else 0), opponent.hit_count, str(combo_complete)]

	if combo_complete and opponent.ai_state != "hitstun" and player.attack_phase == "idle" and elapsed > 1.5:
		_finish_gate()
	elif elapsed > 7.0:
		print("VM02_C8_WATCHDOG=BLOCKED ai=%s attack=%s player_hp=%.1f ai_hp=%.1f ai_hits=%d player_links=%d" % [opponent.ai_state, opponent.attack_phase, player_hp, opponent.health, opponent.hit_count, player_links.size()])
		get_tree().quit(6)

func _process_ai_hit_on_player() -> void:
	if opponent.attack_phase != "active": return
	if ai_hit_attack_index == opponent.attack_count: return
	for area in opponent_attack.get_overlapping_areas():
		if area == $Player/Hurtbox:
			var t = TechniqueCatalog.get_technique(OpponentAIFoundation.TECHNIQUE_ID)
			player_hp = maxf(0.0, player_hp - float(t.damage))
			ai_hit_player = true
			ai_hit_attack_index = opponent.attack_count
			print("VM02_C8_AI_HIT_PLAYER=PASS damage=%.2f player_hp=%.2f" % [float(t.damage), player_hp])
			return

func _process_player_hit_on_ai() -> void:
	if player.attack_phase != "active": return
	if player_hit_link == player.combo_index: return
	for area in player_attack.get_overlapping_areas():
		if area == $Opponent/Hurtbox:
			var t = TechniqueCatalog.get_technique(player.current_technique_id)
			opponent.receive_combat_hit(float(t.damage))
			player_hit_link = player.combo_index
			print("VM02_C8_PLAYER_HIT_AI=PASS link=%d technique=%s damage=%.2f" % [player.combo_index, String(player.current_technique_id), float(t.damage)])
			return

func _on_ai_state(state: String) -> void:
	if state not in visited_states: visited_states.append(state)

func _on_combo_link(_index: int, technique_id: StringName) -> void:
	player_links.append(technique_id)

func _on_combo_complete(hits: int) -> void:
	combo_complete = hits == 2
	print("VM02_C8_PLAYER_COMBO_COMPLETE=%d" % hits)

func _finish_gate() -> void:
	finished = true
	var failures: Array[String] = []
	if "approach" not in visited_states: failures.append("AI never approached")
	if "hold" not in visited_states and "attack" not in visited_states: failures.append("AI never acquired combat range")
	if opponent.attack_count < 1: failures.append("AI never attacked")
	if not ai_hit_player or player_hp >= 100.0: failures.append("AI never damaged player")
	if player_links.size() < 2 or player_links[0] != &"ji_body_hook" or player_links[1] != &"ji_sweep": failures.append("player counter combo links invalid")
	if opponent.hit_count != 2: failures.append("AI did not receive exactly two counter hits")
	if opponent.reaction_count < 2: failures.append("AI did not react to counter hits")
	if opponent.health >= 100.0: failures.append("AI health unchanged")
	if not combo_complete: failures.append("player counter combo incomplete")
	print("VM02_C8_AI_APPROACH=%s" % ("PASS" if "approach" in visited_states else "BLOCKED"))
	print("VM02_C8_AI_RANGE_DECISION=%s" % ("PASS" if ("hold" in visited_states or "attack" in visited_states) else "BLOCKED"))
	print("VM02_C8_AI_ATTACK=%s attacks=%d" % [("PASS" if opponent.attack_count >= 1 else "BLOCKED"), opponent.attack_count])
	print("VM02_C8_AI_DAMAGE_PLAYER=%s hp=%.2f" % [("PASS" if ai_hit_player and player_hp < 100.0 else "BLOCKED"), player_hp])
	print("VM02_C8_AI_RECEIVES_COUNTER=%s hits=%d" % [("PASS" if opponent.hit_count == 2 else "BLOCKED"), opponent.hit_count])
	print("VM02_C8_AI_REACTION=%s reactions=%d" % [("PASS" if opponent.reaction_count >= 2 else "BLOCKED"), opponent.reaction_count])
	print("VM02_C8_PLAYER_COUNTER_COMBO=%s" % ("PASS" if combo_complete else "BLOCKED"))
	print("VM02_C8_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for f in failures: push_error(f)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	if capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c8"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): get_tree().quit(4); return
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x,OUTPUT_SIZE.y,Image.INTERPOLATE_LANCZOS)
		print("VM02_C8_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK: get_tree().quit(5); return
	print("VM02_C8_CAPTURE=PASS")
	print("VM02_C8_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
