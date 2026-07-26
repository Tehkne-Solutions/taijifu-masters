extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const ELEMENT_IDS: Array[StringName] = [&"fire", &"water", &"earth", &"air"]

const ELEMENT_LABELS := {
	&"fire": "FOGO — pressão e combustão",
	&"water": "ÁGUA — empurrão e aderência",
	&"earth": "TERRA — postura e ancoragem",
	&"air": "AR — deslocamento e desequilíbrio"
}

enum MatchState {
	PREPARATION,
	BATTLE
}

@onready var arena: TriplePathArena = $Arena
@onready var camera: Camera2D = $Camera2D
@onready var player_one_label: Label = $HUD/PlayerOne
@onready var player_two_label: Label = $HUD/PlayerTwo
@onready var center_label: Label = $HUD/CenterInfo
@onready var controls_label: Label = $HUD/Controls

var player_one: FighterController
var player_two: FighterController
var _resetting_round := false
var _state: MatchState = MatchState.PREPARATION
var _preset_ids: Array[StringName] = []
var _selected_preset_indices: Array[int] = [0, 2]
var _selected_element_indices: Array[int] = [3, 2]
var _message_sequence := 0

func _ready() -> void:
	_register_prototype_inputs()
	_preset_ids = BuildProfile.available_prototype_presets()
	arena.sector_shifted.connect(_on_sector_shifted)
	_enter_preparation()

func _process(delta: float) -> void:
	if _state == MatchState.PREPARATION:
		_process_preparation()
		return

	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return

	_update_camera(delta)
	_update_hud()
	_check_world_limits()

func _enter_preparation() -> void:
	_state = MatchState.PREPARATION
	camera.global_position = arena.world_center()
	camera.zoom = Vector2(0.72, 0.72)
	center_label.text = "PREPARAÇÃO DE BATALHA\nENTER PARA INICIAR"
	controls_label.text = "P1 A/D build • Q/E elemento    |    P2 ←/→ build • Num4/Num5 elemento    |    ENTER inicia"
	_update_preparation_ui()

func _process_preparation() -> void:
	var changed := false
	if Input.is_action_just_pressed("p1_left"):
		_cycle_preset(0, -1)
		changed = true
	elif Input.is_action_just_pressed("p1_right"):
		_cycle_preset(0, 1)
		changed = true

	if Input.is_action_just_pressed("p2_left"):
		_cycle_preset(1, -1)
		changed = true
	elif Input.is_action_just_pressed("p2_right"):
		_cycle_preset(1, 1)
		changed = true

	if Input.is_action_just_pressed("p1_element_prev"):
		_cycle_element(0, -1)
		changed = true
	elif Input.is_action_just_pressed("p1_element_next"):
		_cycle_element(0, 1)
		changed = true

	if Input.is_action_just_pressed("p2_element_prev"):
		_cycle_element(1, -1)
		changed = true
	elif Input.is_action_just_pressed("p2_element_next"):
		_cycle_element(1, 1)
		changed = true

	if changed:
		_update_preparation_ui()

	if Input.is_action_just_pressed("start_match"):
		_start_battle()

func _cycle_preset(player_slot: int, direction: int) -> void:
	_selected_preset_indices[player_slot] = wrapi(
		_selected_preset_indices[player_slot] + direction,
		0,
		_preset_ids.size()
	)

func _cycle_element(player_slot: int, direction: int) -> void:
	_selected_element_indices[player_slot] = wrapi(
		_selected_element_indices[player_slot] + direction,
		0,
		ELEMENT_IDS.size()
	)

func _update_preparation_ui() -> void:
	var p1_build := BuildProfile.prototype_preset(_preset_ids[_selected_preset_indices[0]])
	var p2_build := BuildProfile.prototype_preset(_preset_ids[_selected_preset_indices[1]])
	var p1_element := ELEMENT_IDS[_selected_element_indices[0]]
	var p2_element := ELEMENT_IDS[_selected_element_indices[1]]
	player_one_label.text = _preparation_summary(p1_build, p1_element, "P1 — KAEL")
	player_two_label.text = _preparation_summary(p2_build, p2_element, "P2 — NARA")

func _preparation_summary(build: BuildProfile, element_id: StringName, title: String) -> String:
	return "%s\n◀ %s ▶\nTAI %d  JI %d  FU %d\nELEMENTO: %s\n%s" % [
		title,
		build.display_name,
		roundi(build.tai_index()),
		roundi(build.ji_index()),
		roundi(build.fu_index()),
		ELEMENT_LABELS.get(element_id, "NEUTRO"),
		build.tactical_summary
	]

func _start_battle() -> void:
	_state = MatchState.BATTLE
	_cleanup_temporary_loot()
	arena.start_battle_flow()
	_spawn_fighters()
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
	controls_label.text = "P1: A/D • W salto • S varredura/queda • Q esquiva • F técnica • G empurrão • E agarrão • C elemento • H eco • R defesa\nP2: Setas • Num0 esquiva • Num1 técnica • Num2 empurrão • Num4 agarrão • Num6 elemento • Num5 eco • Num3 defesa"

func _spawn_fighters() -> void:
	player_one = FIGHTER_SCENE.instantiate() as FighterController
	player_one.player_index = 1
	player_one.build_preset = _preset_ids[_selected_preset_indices[0]]
	player_one.fighter_color = Color(0.25, 0.70, 1.0)
	player_one.position = arena.respawn_point(1)
	_connect_fighter_signals(player_one)
	add_child(player_one)
	player_one.build.element_id = ELEMENT_IDS[_selected_element_indices[0]]
	player_one.queue_redraw()

	player_two = FIGHTER_SCENE.instantiate() as FighterController
	player_two.player_index = 2
	player_two.build_preset = _preset_ids[_selected_preset_indices[1]]
	player_two.fighter_color = Color(1.0, 0.40, 0.24)
	player_two.position = arena.respawn_point(2)
	_connect_fighter_signals(player_two)
	add_child(player_two)
	player_two.build.element_id = ELEMENT_IDS[_selected_element_indices[1]]
	player_two.queue_redraw()

func _connect_fighter_signals(fighter: FighterController) -> void:
	fighter.defeated.connect(_on_fighter_defeated)
	fighter.parry_performed.connect(_on_parry_performed)
	fighter.posture_broken.connect(_on_posture_broken)
	fighter.weapon_disarmed.connect(_on_weapon_disarmed)
	fighter.loot_collected.connect(_on_loot_collected)
	fighter.grab_started.connect(_on_grab_started)
	fighter.grab_finished.connect(_on_grab_finished)
	if fighter.has_signal("elemental_state_changed"):
		fighter.connect("elemental_state_changed", Callable(self, "_on_elemental_state_changed"))
	if fighter.has_signal("elemental_interaction"):
		fighter.connect("elemental_interaction", Callable(self, "_on_elemental_interaction"))

func _update_camera(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	midpoint.y = clampf(midpoint.y - 80.0, 280.0, 720.0)
	midpoint.x = clampf(
		midpoint.x,
		arena.camera_left_limit(),
		TriplePathArena.WORLD_WIDTH - 420.0
	)
	camera.global_position = camera.global_position.lerp(midpoint, 1.0 - exp(-5.0 * delta))

	var distance := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom := clampf(1180.0 / maxf(900.0, distance + 420.0), 0.62, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-4.0 * delta))

func _update_hud() -> void:
	player_one_label.text = _fighter_summary(player_one, "P1 — KAEL")
	player_two_label.text = _fighter_summary(player_two, "P2 — NARA")

func _fighter_summary(fighter: FighterController, title: String) -> String:
	var element_label := String(fighter.build.element_id).to_upper()
	var state_label := "ESTÁVEL"
	if fighter is ElementalFighterController:
		var elemental := fighter as ElementalFighterController
		element_label = elemental.current_element_label()
		state_label = elemental.current_elemental_status_label()

	return "%s\n%s\nVIDA %d  POST %d  FÔL %d\nTAI %d  JI %d  FU %d\n%s • %s\nARMA %s  DES %d%%\n%s • %s" % [
		title,
		fighter.build.display_name,
		roundi(fighter.health),
		roundi(fighter.posture),
		roundi(fighter.stamina),
		roundi(fighter.build.tai_index()),
		roundi(fighter.build.ji_index()),
		roundi(fighter.build.fu_index()),
		element_label,
		state_label,
		fighter.current_weapon_label(),
		roundi(fighter.disarm_pressure),
		fighter.current_technique_label(),
		fighter.current_echo_label()
	]

func _check_world_limits() -> void:
	for fighter in [player_one, player_two]:
		arena.apply_sector_pressure(fighter)
		if fighter.global_position.y > TriplePathArena.WORLD_HEIGHT + 120.0:
			fighter.receive_hit(9999.0, 9999.0, Vector2.ZERO, fighter.global_position)

func _on_parry_performed(_fighter: FighterController) -> void:
	_show_combat_event("APARO PERFEITO • FU", 0.45)

func _on_posture_broken(_fighter: FighterController, region_id: StringName) -> void:
	_show_combat_event("POSTURA QUEBRADA • %s" % String(region_id).to_upper(), 0.60)

func _on_weapon_disarmed(_fighter: FighterController, _weapon_id: StringName) -> void:
	_show_combat_event("DESARMAMENTO • ESPÓLIO LIBERADO", 0.72)

func _on_loot_collected(_fighter: FighterController, loot_type: StringName, _item_id: StringName) -> void:
	var label := "ARMA TOMADA" if loot_type == &"weapon" else "ECO DE TÉCNICA CAPTURADO"
	_show_combat_event(label, 0.72)

func _on_grab_started(_attacker: FighterController, _target: FighterController) -> void:
	_show_combat_event("CONTROLE JI • ESCOLHA A PROJEÇÃO", 0.42)

func _on_grab_finished(_attacker: FighterController, _target: FighterController) -> void:
	_show_combat_event("PROJEÇÃO DIRECIONAL • JI", 0.52)

func _on_elemental_state_changed(_fighter: FighterController, status_id: StringName) -> void:
	_show_combat_event("ESTADO ELEMENTAL • %s" % String(status_id).to_upper(), 0.56)

func _on_elemental_interaction(
	_fighter: FighterController,
	interaction_id: StringName,
	_element_id: StringName
) -> void:
	var labels := {
		&"steam": "VAPOR • FOGO + ÁGUA",
		&"combustion": "COMBUSTÃO • FOGO + AR",
		&"mud": "LAMA • ÁGUA + TERRA",
		&"extinguished": "CHAMA EXTINTA • ÁGUA",
		&"air_resisted": "RAJADA CONTIDA • TERRA"
	}
	_show_combat_event(labels.get(interaction_id, "INTERAÇÃO ELEMENTAL"), 0.72)

func _on_sector_shifted(stage: int, _boundary_x: float) -> void:
	if stage == 0:
		return
	_show_combat_event(arena.closure_stage_label(), 0.95)

func _show_combat_event(message: String, duration: float) -> void:
	_message_sequence += 1
	var sequence := _message_sequence
	center_label.text = message
	await get_tree().create_timer(duration).timeout
	if sequence == _message_sequence and not _resetting_round:
		center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"

func _on_fighter_defeated(_fighter: FighterController) -> void:
	if _resetting_round:
		return
	_resetting_round = true
	_message_sequence += 1
	center_label.text = "FLUXO INTERROMPIDO"
	await get_tree().create_timer(1.15).timeout
	_cleanup_temporary_loot()
	arena.reset_battle_flow()
	player_one.reset_fighter(arena.respawn_point(1))
	player_two.reset_fighter(arena.respawn_point(2))
	center_label.text = "ADAPTE-SE"
	await get_tree().create_timer(0.75).timeout
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
	_resetting_round = false

func _cleanup_temporary_loot() -> void:
	for loot in get_tree().get_nodes_in_group("temporary_loot"):
		loot.queue_free()

func _register_prototype_inputs() -> void:
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
	_add_key_action(&"p1_element_prev", KEY_Q)
	_add_key_action(&"p1_element_next", KEY_E)

	_add_key_action(&"p2_left", KEY_LEFT)
	_add_key_action(&"p2_right", KEY_RIGHT)
	_add_key_action(&"p2_down", KEY_DOWN)
	_add_key_action(&"p2_jump", KEY_UP)
	_add_key_action(&"p2_dodge", KEY_KP_0)
	_add_key_action(&"p2_attack", KEY_KP_1)
	_add_key_action(&"p2_push", KEY_KP_2)
	_add_key_action(&"p2_block", KEY_KP_3)
	_add_key_action(&"p2_grab", KEY_KP_4)
	_add_key_action(&"p2_echo", KEY_KP_5)
	_add_key_action(&"p2_element", KEY_KP_6)
	_add_key_action(&"p2_element_prev", KEY_KP_4)
	_add_key_action(&"p2_element_next", KEY_KP_5)
	_add_key_action(&"start_match", KEY_ENTER)

func _add_key_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)