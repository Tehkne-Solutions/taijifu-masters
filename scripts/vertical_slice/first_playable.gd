class_name FirstPlayableController
extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const PLAYER_PRESET: StringName = &"adaptive_staff"
const CPU_PRESET: StringName = &"rin_challenger"
const COUNTDOWN_SECONDS := 3

enum MatchState { BOOT, COUNTDOWN, BATTLE, RESULT }

@onready var arena: TriplePathArena = $Arena
@onready var bot_runtime: TacticalBotRuntime = $TacticalBotRuntime
@onready var camera: Camera2D = $Camera2D
@onready var player_one_label: Label = $HUD/PlayerOne
@onready var player_two_label: Label = $HUD/PlayerTwo
@onready var center_label: Label = $HUD/CenterInfo
@onready var controls_label: Label = $HUD/Controls
@onready var state_label: Label = $HUD/StateInfo

var player_one: FighterController
var player_two: FighterController
var _state: MatchState = MatchState.BOOT
var _match_generation := 0

func _ready() -> void:
	_register_inputs()
	arena.show_strategic_points = false
	bot_runtime.enabled = false
	_start_match()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"first_playable_restart"):
		_start_match()
		return
	if Input.is_action_just_pressed(&"first_playable_exit"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return

	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return

	_update_camera(delta)
	_update_hud()
	if _state == MatchState.BATTLE:
		_check_world_limits()

func _start_match() -> void:
	_match_generation += 1
	var generation := _match_generation
	_state = MatchState.COUNTDOWN
	bot_runtime.enabled = false
	_release_all_combat_actions()
	_cleanup_fighters()
	_cleanup_temporary_loot()
	_spawn_fighters()
	_set_fighters_active(false)
	camera.global_position = arena.world_center()
	camera.zoom = Vector2(0.72, 0.72)
	controls_label.text = "A/D mover • W saltar • F atacar • Q esquivar • R defender • G impulso • E agarrar\nENTER reinicia • ESC volta ao protótipo completo"
	state_label.text = "VERTICAL SLICE • P1 VS CPU • IA DISCÍPULO"

	for value in range(COUNTDOWN_SECONDS, 0, -1):
		if generation != _match_generation:
			return
		center_label.text = str(value)
		await get_tree().create_timer(0.72).timeout

	if generation != _match_generation:
		return
	center_label.text = "LUTEM"
	await get_tree().create_timer(0.42).timeout
	if generation != _match_generation:
		return

	_set_fighters_active(true)
	arena.start_battle_flow()
	bot_runtime.difficulty_id = &"disciple"
	bot_runtime.personality_id = &"aggressive"
	bot_runtime.enabled = true
	_state = MatchState.BATTLE
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO"

func _spawn_fighters() -> void:
	player_one = _spawn_fighter(1, PLAYER_PRESET, Color(0.22, 0.67, 1.0))
	player_two = _spawn_fighter(2, CPU_PRESET, Color(1.0, 0.34, 0.20))
	player_one.facing = 1.0
	player_two.facing = -1.0

func _spawn_fighter(player_index: int, preset_id: StringName, color: Color) -> FighterController:
	var fighter := FIGHTER_SCENE.instantiate() as FighterController
	fighter.player_index = player_index
	fighter.build_preset = preset_id
	fighter.fighter_color = color
	fighter.position = arena.respawn_point(player_index)
	fighter.defeated.connect(_on_fighter_defeated)
	add_child(fighter)
	fighter.queue_redraw()
	return fighter

func _on_fighter_defeated(defeated_fighter: FighterController) -> void:
	if _state != MatchState.BATTLE:
		return
	_state = MatchState.RESULT
	bot_runtime.enabled = false
	_release_all_combat_actions()
	_set_fighters_active(false)
	var winner := player_two if defeated_fighter == player_one else player_one
	var result_label := "DERROTA" if winner.player_index == 2 else "VITÓRIA"
	center_label.text = "%s\n%s VENCE" % [result_label, winner.build.character_name.to_upper()]
	controls_label.text = "ENTER para revanche • ESC para voltar ao protótipo completo"
	state_label.text = "PARTIDA CONCLUÍDA • KO"

func _set_fighters_active(active: bool) -> void:
	for fighter in [player_one, player_two]:
		if not is_instance_valid(fighter):
			continue
		fighter.set_physics_process(active)
		if not active:
			fighter.velocity = Vector2.ZERO

func _cleanup_fighters() -> void:
	for fighter in [player_one, player_two]:
		if is_instance_valid(fighter):
			fighter.queue_free()
	player_one = null
	player_two = null

func _cleanup_temporary_loot() -> void:
	for loot in get_tree().get_nodes_in_group("temporary_loot"):
		loot.queue_free()

func _check_world_limits() -> void:
	for fighter in [player_one, player_two]:
		if not is_instance_valid(fighter):
			continue
		arena.apply_sector_pressure(fighter)
		if fighter.global_position.y > TriplePathArena.WORLD_HEIGHT + 120.0:
			fighter.receive_hit(9999.0, 9999.0, Vector2.ZERO, fighter.global_position)

func _update_camera(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	midpoint.y = clampf(midpoint.y - 80.0, 280.0, 720.0)
	midpoint.x = clampf(midpoint.x, arena.camera_left_limit(), TriplePathArena.WORLD_WIDTH - 420.0)
	camera.global_position = camera.global_position.lerp(midpoint, 1.0 - exp(-5.0 * delta))
	var distance := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom := clampf(1180.0 / maxf(900.0, distance + 420.0), 0.62, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-4.0 * delta))

func _update_hud() -> void:
	player_one_label.text = _fighter_summary(player_one, "P1")
	player_two_label.text = _fighter_summary(player_two, "CPU")

func _fighter_summary(fighter: FighterController, prefix: String) -> String:
	return "%s • %s\nVIDA %d  POST %d  FÔL %d\n%s • %s" % [
		prefix,
		fighter.build.character_name.to_upper(),
		roundi(fighter.health),
		roundi(fighter.posture),
		roundi(fighter.stamina),
		String(fighter.build.element_id).to_upper(),
		fighter.current_weapon_label()
	]

func _release_all_combat_actions() -> void:
	for player_index in [1, 2]:
		for suffix in ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "echo", "block", "element", "swap"]:
			Input.action_release(StringName("p%d_%s" % [player_index, suffix]))

func _register_inputs() -> void:
	_add_key_action(&"p1_left", KEY_A)
	_add_key_action(&"p1_right", KEY_D)
	_add_key_action(&"p1_down", KEY_S)
	_add_key_action(&"p1_jump", KEY_W)
	_add_key_action(&"p1_dodge", KEY_Q)
	_add_key_action(&"p1_attack", KEY_F)
	_add_key_action(&"p1_push", KEY_G)
	_add_key_action(&"p1_grab", KEY_E)
	_add_key_action(&"p1_echo", KEY_H)
	_add_key_action(&"p1_block", KEY_R)
	_add_key_action(&"p1_element", KEY_C)
	_add_key_action(&"p1_swap", KEY_T)
	for suffix in ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "echo", "block", "element", "swap"]:
		var action := StringName("p2_%s" % suffix)
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
	_add_key_action(&"first_playable_restart", KEY_ENTER)
	_add_key_action(&"first_playable_exit", KEY_ESCAPE)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
