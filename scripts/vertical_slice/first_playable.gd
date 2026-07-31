class_name FirstPlayableController
extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const CHARACTER_IDENTITY := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")
const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const PLAYER_PRESET: StringName = &"lian_wu_first_playable"
const CPU_PRESET: StringName = &"training_rival_first_playable"
const COUNTDOWN_SECONDS := 3

@export_range(0.01, 2.0, 0.01) var countdown_step_seconds := 0.72
@export_range(0.01, 1.0, 0.01) var fight_command_seconds := 0.42
@export_range(5.0, 600.0, 1.0) var match_time_limit_seconds := 90.0

enum MatchState { BOOT, COUNTDOWN, BATTLE, RESULT }

@onready var arena: FirstPlayableArena = $Arena
@onready var bot_runtime: TacticalBotRuntime = $TacticalBotRuntime
@onready var difficulty_controller: FirstPlayableDifficultyController = $DifficultyController
@onready var hud_controller: FirstPlayableHudController = $HudController
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
var _time_remaining := 0.0
var _is_paused := false
var _round_started_msec := 0
var _last_telemetry_path := ""
var _feedback_submitted := false
var _telemetry := MatchTelemetry.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	arena.show_strategic_points = false
	bot_runtime.enabled = false
	hud_controller.rematch_requested.connect(_start_match)
	hud_controller.menu_requested.connect(_return_to_menu)
	hud_controller.resume_requested.connect(_resume_match)
	hud_controller.feedback_submitted.connect(_on_feedback_submitted)
	hud_controller.report_copy_requested.connect(_copy_playtest_report)
	difficulty_controller.difficulty_changed.connect(_on_difficulty_changed)
	_begin_playtest_session()
	_start_match()

func _physics_process(_delta: float) -> void:
	# O controlador pai processa antes dos lutadores. Soltar as ações aqui
	# mantém gravidade, colisão e assentamento no piso ativos sem permitir
	# comandos durante contagem regressiva ou tela de resultado.
	if _state != MatchState.BATTLE:
		_release_all_combat_actions()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"first_playable_pause"):
		if _state == MatchState.RESULT:
			_return_to_menu()
		else:
			_set_paused(not _is_paused)
		return
	if _is_paused:
		return
	if Input.is_action_just_pressed(&"first_playable_restart") and _state == MatchState.RESULT:
		_start_match()
		return

	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return

	_update_camera(delta)
	if _state == MatchState.BATTLE:
		_time_remaining = maxf(0.0, _time_remaining - delta)
		_check_world_limits()
		if _state == MatchState.BATTLE and _time_remaining <= 0.0:
			_resolve_timeout()
	_update_hud()

func _begin_playtest_session() -> void:
	_telemetry.begin_session({
		"experience": "first_playable",
		"build_version": String(ProjectSettings.get_setting("application/config/version", "unknown")),
		"platform": OS.get_name(),
		"locale": TranslationServer.get_locale(),
		"privacy": "local_only",
		"signature": "Tehkné Solutions"
	})

func _start_match() -> void:
	if _match_generation > 0:
		if _state == MatchState.RESULT:
			_last_telemetry_path = _telemetry.annotate_last_round({
				"rematch_requested": true,
				"rematch_requested_unix": int(Time.get_unix_time_from_system())
			})
		_telemetry.begin_round()

	_set_paused(false)
	hud_controller.hide_result()
	_match_generation += 1
	var generation := _match_generation
	_state = MatchState.COUNTDOWN
	_time_remaining = match_time_limit_seconds
	_round_started_msec = Time.get_ticks_msec()
	_feedback_submitted = false
	bot_runtime.enabled = false
	_release_all_combat_actions()
	arena.stop_battle_flow()
	_cleanup_fighters()
	_cleanup_temporary_loot()
	_spawn_fighters()
	_set_fighters_controls(false)
	camera.global_position = arena.world_center()
	camera.zoom = Vector2(0.72, 0.72)
	controls_label.text = "A/D mover • W saltar • F atacar • Q esquivar • R defender • G impulso • E agarrar\nESC pausa • 1/2/3 dificuldade"
	state_label.text = "LIAN WU VS RIVAL DE TREINO • IA %s" % _difficulty_label()
	_telemetry.set_round_metadata({
		"experience": "first_playable",
		"match_generation": _match_generation,
		"difficulty_id": String(difficulty_controller.selected_difficulty_id),
		"difficulty_label": _difficulty_label(),
		"time_limit_seconds": match_time_limit_seconds,
		"player_character": "Lian Wu",
		"cpu_character": "Rival de Treino",
		"arena": "Ruínas do Caminho Triplo"
	})
	_telemetry.record_event(&"p1", &"match_started", difficulty_controller.selected_difficulty_id)

	for value in range(COUNTDOWN_SECONDS, 0, -1):
		if generation != _match_generation:
			return
		center_label.text = str(value)
		await get_tree().create_timer(countdown_step_seconds, false).timeout

	if generation != _match_generation:
		return
	center_label.text = "LUTEM"
	await get_tree().create_timer(fight_command_seconds, false).timeout
	if generation != _match_generation:
		return

	_set_fighters_controls(true)
	arena.start_battle_flow()
	bot_runtime.difficulty_id = difficulty_controller.selected_difficulty_id
	bot_runtime.personality_id = &"aggressive"
	bot_runtime.enabled = true
	_state = MatchState.BATTLE
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO"
	_telemetry.record_event(&"p1", &"battle_started", difficulty_controller.selected_difficulty_id)

func _spawn_fighters() -> void:
	player_one = _spawn_fighter(1, PLAYER_PRESET, Color(0.16, 0.42, 0.82))
	player_two = _spawn_fighter(2, CPU_PRESET, Color(0.48, 0.12, 0.07))
	player_one.facing = 1.0
	player_two.facing = -1.0

func _spawn_fighter(player_index: int, preset_id: StringName, color: Color) -> FighterController:
	var fighter := FIGHTER_SCENE.instantiate() as FighterController
	fighter.player_index = player_index
	fighter.build_preset = preset_id
	fighter.fighter_color = color
	fighter.position = arena.respawn_point(player_index)
	fighter.defeated.connect(_on_fighter_defeated)
	var identity := CHARACTER_IDENTITY.new() as FirstPlayableCharacterIdentity
	identity.name = "FirstPlayableIdentity"
	fighter.add_child(identity)
	add_child(fighter)
	fighter.queue_redraw()
	return fighter

func _on_fighter_defeated(defeated_fighter: FighterController) -> void:
	if _state != MatchState.BATTLE:
		return
	var winner := player_two if defeated_fighter == player_one else player_one
	_finish_match(winner, "KO")

func _resolve_timeout() -> void:
	if _state != MatchState.BATTLE:
		return
	var p1_score := _timeout_score(player_one)
	var p2_score := _timeout_score(player_two)
	var winner := player_one if p1_score >= p2_score else player_two
	_finish_match(winner, "TEMPO")

func _timeout_score(fighter: FighterController) -> float:
	var health_ratio := fighter.health / maxf(1.0, fighter.build.max_health())
	var posture_ratio := fighter.posture / maxf(1.0, fighter.build.max_posture())
	return health_ratio * 0.8 + posture_ratio * 0.2

func _finish_match(winner: FighterController, reason: String) -> void:
	if _state != MatchState.BATTLE:
		return
	_state = MatchState.RESULT
	bot_runtime.enabled = false
	_release_all_combat_actions()
	_set_fighters_controls(false)
	arena.stop_battle_flow()
	var player_won := winner.player_index == 1
	var winner_profile_id: StringName = &"p1" if player_won else &"p2"
	var result_label := "VITÓRIA" if player_won else "DERROTA"
	var reason_id := StringName(reason.to_lower())
	_telemetry.record_event(winner_profile_id, &"match_won", reason_id)
	_telemetry.record_event(&"p1", &"match_finished", reason_id)
	_last_telemetry_path = _telemetry.finish_round(winner_profile_id, {
		"result_reason": String(reason_id),
		"player_won": player_won,
		"winner_character": winner.build.character_name,
		"difficulty_id": String(difficulty_controller.selected_difficulty_id),
		"difficulty_label": _difficulty_label(),
		"elapsed_seconds": float(Time.get_ticks_msec() - _round_started_msec) / 1000.0,
		"time_remaining_seconds": _time_remaining,
		"p1_final": _fighter_final_state(player_one),
		"p2_final": _fighter_final_state(player_two)
	})
	center_label.text = "%s\n%s VENCE" % [result_label, winner.build.character_name.to_upper()]
	controls_label.text = "ENTER ou botão para revanche • ESC para menu"
	state_label.text = "PARTIDA CONCLUÍDA • %s • IA %s" % [reason, _difficulty_label()]
	hud_controller.show_result(
		winner.build.character_name,
		player_won,
		reason,
		_difficulty_label(),
		_last_telemetry_path.get_file()
	)

func _set_paused(active: bool) -> void:
	if _is_paused == active:
		return
	_is_paused = active
	hud_controller.show_pause(active)
	get_tree().paused = active
	if _state == MatchState.COUNTDOWN or _state == MatchState.BATTLE:
		_telemetry.record_event(&"p1", &"pause" if active else &"resume")

func _resume_match() -> void:
	_set_paused(false)

func _return_to_menu() -> void:
	_set_paused(false)
	if _state == MatchState.RESULT:
		_last_telemetry_path = _telemetry.annotate_last_round({
			"returned_to_menu": true,
			"returned_to_menu_unix": int(Time.get_unix_time_from_system())
		})
	elif _state == MatchState.COUNTDOWN or _state == MatchState.BATTLE:
		_close_abandoned_round()
	get_tree().change_scene_to_file(MENU_SCENE)

func _close_abandoned_round() -> void:
	bot_runtime.enabled = false
	arena.stop_battle_flow()
	_telemetry.record_event(&"p1", &"match_abandoned")
	_last_telemetry_path = _telemetry.finish_round(&"", {
		"result_reason": "abandoned",
		"player_won": false,
		"difficulty_id": String(difficulty_controller.selected_difficulty_id),
		"difficulty_label": _difficulty_label(),
		"elapsed_seconds": float(Time.get_ticks_msec() - _round_started_msec) / 1000.0,
		"time_remaining_seconds": _time_remaining,
		"p1_final": _fighter_final_state(player_one),
		"p2_final": _fighter_final_state(player_two)
	})

func _on_feedback_submitted(rating_id: StringName) -> void:
	if _state != MatchState.RESULT or _feedback_submitted:
		return
	_feedback_submitted = true
	_last_telemetry_path = _telemetry.annotate_last_round({
		"balance_feedback": String(rating_id),
		"feedback_submitted_unix": int(Time.get_unix_time_from_system())
	})
	hud_controller.set_report_status(
		"FEEDBACK SALVO • SESSÃO %s" % _telemetry.session_id()
	)

func _copy_playtest_report() -> void:
	var report := _telemetry.session_json()
	if report == "":
		hud_controller.set_report_status("RELATÓRIO AINDA NÃO DISPONÍVEL")
		return
	DisplayServer.clipboard_set(report)
	hud_controller.set_report_status(
		"RELATÓRIO COPIADO • SESSÃO %s" % _telemetry.session_id()
	)

func _on_difficulty_changed(difficulty_id: StringName, label: String) -> void:
	if _state != MatchState.COUNTDOWN and _state != MatchState.BATTLE:
		return
	_telemetry.set_round_metadata({
		"difficulty_id": String(difficulty_id),
		"difficulty_label": label
	})
	_telemetry.record_event(&"p1", &"difficulty_changed", difficulty_id)

func _fighter_final_state(fighter: FighterController) -> Dictionary:
	if not is_instance_valid(fighter):
		return {}
	return {
		"character": fighter.build.character_name,
		"health": fighter.health,
		"max_health": fighter.build.max_health(),
		"posture": fighter.posture,
		"max_posture": fighter.build.max_posture(),
		"stamina": fighter.stamina,
		"position": {
			"x": fighter.global_position.x,
			"y": fighter.global_position.y
		}
	}

func _set_fighters_controls(active: bool) -> void:
	for fighter in [player_one, player_two]:
		if not is_instance_valid(fighter):
			continue
		if not active:
			fighter.velocity.x = 0.0

func _cleanup_fighters() -> void:
	for fighter in [player_one, player_two]:
		if not is_instance_valid(fighter):
			continue
		if fighter.get_parent() == self:
			remove_child(fighter)
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
	hud_controller.update_fighters(player_one, player_two)
	if _state == MatchState.BATTLE:
		state_label.text = "LIAN WU VS RIVAL • IA %s • TEMPO %02d" % [_difficulty_label(), ceili(_time_remaining)]

func _difficulty_label() -> String:
	if is_instance_valid(difficulty_controller):
		return difficulty_controller.current_label()
	return BotBehaviorCatalog.difficulty_label(bot_runtime.difficulty_id)

func _fighter_summary(fighter: FighterController, prefix: String) -> String:
	return "%s • %s\n%s • %s" % [
		prefix,
		fighter.build.character_name.to_upper(),
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
	_add_key_action(&"first_playable_pause", KEY_ESCAPE)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
