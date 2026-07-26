extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")

@onready var arena: TriplePathArena = $Arena
@onready var camera: Camera2D = $Camera2D
@onready var player_one_label: Label = $HUD/PlayerOne
@onready var player_two_label: Label = $HUD/PlayerTwo
@onready var center_label: Label = $HUD/CenterInfo

var player_one: FighterController
var player_two: FighterController
var _resetting_round := false

func _ready() -> void:
	_register_prototype_inputs()
	_spawn_fighters()
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"

func _process(delta: float) -> void:
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return

	_update_camera(delta)
	_update_hud()
	_check_world_limits()

func _spawn_fighters() -> void:
	player_one = FIGHTER_SCENE.instantiate() as FighterController
	player_one.player_index = 1
	player_one.build_preset = &"adaptive_staff"
	player_one.fighter_color = Color(0.25, 0.70, 1.0)
	player_one.position = arena.respawn_point(1)
	player_one.defeated.connect(_on_fighter_defeated)
	add_child(player_one)

	player_two = FIGHTER_SCENE.instantiate() as FighterController
	player_two.player_index = 2
	player_two.build_preset = &"rock_guardian"
	player_two.fighter_color = Color(1.0, 0.40, 0.24)
	player_two.position = arena.respawn_point(2)
	player_two.defeated.connect(_on_fighter_defeated)
	add_child(player_two)

func _update_camera(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	midpoint.y = clampf(midpoint.y - 80.0, 280.0, 720.0)
	midpoint.x = clampf(midpoint.x, 420.0, TriplePathArena.WORLD_WIDTH - 420.0)
	camera.global_position = camera.global_position.lerp(midpoint, 1.0 - exp(-5.0 * delta))

	var distance := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom := clampf(1180.0 / maxf(900.0, distance + 420.0), 0.62, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-4.0 * delta))

func _update_hud() -> void:
	player_one_label.text = _fighter_summary(player_one, "P1 — KAEL")
	player_two_label.text = _fighter_summary(player_two, "P2 — NARA")

func _fighter_summary(fighter: FighterController, title: String) -> String:
	return "%s\n%s\nVIDA %d  POST %d  FÔL %d\nTAI %d  JI %d  FU %d" % [
		title,
		fighter.build.display_name,
		roundi(fighter.health),
		roundi(fighter.posture),
		roundi(fighter.stamina),
		roundi(fighter.build.tai_index()),
		roundi(fighter.build.ji_index()),
		roundi(fighter.build.fu_index())
	]

func _check_world_limits() -> void:
	for fighter in [player_one, player_two]:
		if fighter.global_position.y > TriplePathArena.WORLD_HEIGHT + 120.0:
			fighter.receive_hit(9999.0, 9999.0, Vector2.ZERO, fighter.global_position)

func _on_fighter_defeated(_fighter: FighterController) -> void:
	if _resetting_round:
		return
	_resetting_round = true
	center_label.text = "FLUXO INTERROMPIDO"
	await get_tree().create_timer(1.15).timeout
	player_one.reset_fighter(arena.respawn_point(1))
	player_two.reset_fighter(arena.respawn_point(2))
	center_label.text = "ADAPTE-SE"
	await get_tree().create_timer(0.75).timeout
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
	_resetting_round = false

func _register_prototype_inputs() -> void:
	_add_key_action(&"p1_left", KEY_A)
	_add_key_action(&"p1_right", KEY_D)
	_add_key_action(&"p1_down", KEY_S)
	_add_key_action(&"p1_jump", KEY_W)
	_add_key_action(&"p1_dodge", KEY_Q)
	_add_key_action(&"p1_attack", KEY_F)
	_add_key_action(&"p1_push", KEY_G)
	_add_key_action(&"p1_block", KEY_R)

	_add_key_action(&"p2_left", KEY_LEFT)
	_add_key_action(&"p2_right", KEY_RIGHT)
	_add_key_action(&"p2_down", KEY_DOWN)
	_add_key_action(&"p2_jump", KEY_UP)
	_add_key_action(&"p2_dodge", KEY_KP_0)
	_add_key_action(&"p2_attack", KEY_KP_1)
	_add_key_action(&"p2_push", KEY_KP_2)
	_add_key_action(&"p2_block", KEY_KP_3)

func _add_key_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
