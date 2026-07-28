class_name GamepadExperienceRuntime
extends Node

const PROFILE_PATH := "user://gamepad-experience-profile.json"
const BRIDGE_VERSION := 1
const DEFAULT_TRIGGER_THRESHOLD := 0.55
const MIN_TRIGGER_THRESHOLD := 0.25
const MAX_TRIGGER_THRESHOLD := 0.90
const ADVANCED_GRAB_TECHNIQUE := &"ji_clinch_grab"
const ADVANCED_ECHO_TECHNIQUE := &"ji_body_hook"
const CURVE_IDS := [&"linear", &"precision", &"aggressive"]

var profile: Dictionary = {}
var _callbacks: Array = []
var _window: JavaScriptObject
var _connected_fighters: Dictionary = {}
var _discover_timer := 0.0

var _canvas: CanvasLayer
var _advanced_panel: ColorRect
var _advanced_label: Label
var _advanced_active := false
var _advanced_stage := 0
var _advanced_timer := 0.0
var _escape_grab_started := false
var _scene: Node
var _player_one: FighterController
var _player_two: FighterController
var _saved_player_two_events: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _default_profile()
	_load_profile()
	_create_advanced_interface()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	call_deferred("_deferred_initialize")

func _deferred_initialize() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	apply_profile()
	_register_web_bridge()

func _process(delta: float) -> void:
	_discover_timer -= delta
	if _discover_timer <= 0.0:
		_discover_timer = 0.25
		_discover_fighters()
		_sync_web_state()
	if _advanced_active:
		_process_advanced_dojo(delta)

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		_release_curve_actions()
		return
	for player_index in [1, 2]:
		if _advanced_active and player_index == 2:
			_release_player_curve_actions(player_index)
		else:
			_inject_curved_stick(player_index)

func _exit_tree() -> void:
	_release_curve_actions()
	if _advanced_active:
		_restore_player_two_inputs()

func _default_profile() -> Dictionary:
	var players := {}
	for player_index in [1, 2]:
		players[str(player_index)] = {
			"response_curve": "linear",
			"trigger_threshold": DEFAULT_TRIGGER_THRESHOLD,
			"haptics_enabled": true,
			"vibration_scale": 0.85
		}
	return {
		"version": 1,
		"players": players,
		"advanced_training_completed": false
	}

func _sanitize_profile(value: Variant) -> Dictionary:
	var clean := _default_profile()
	if not value is Dictionary:
		return clean
	var source: Dictionary = value
	var source_players: Dictionary = source.get("players", {})
	for player_index in [1, 2]:
		var key := str(player_index)
		var clean_player: Dictionary = clean["players"][key]
		var source_player: Dictionary = source_players.get(key, {})
		var curve_id := StringName(source_player.get("response_curve", &"linear"))
		clean_player["response_curve"] = String(curve_id if curve_id in CURVE_IDS else &"linear")
		clean_player["trigger_threshold"] = clampf(
			float(source_player.get("trigger_threshold", DEFAULT_TRIGGER_THRESHOLD)),
			MIN_TRIGGER_THRESHOLD,
			MAX_TRIGGER_THRESHOLD
		)
		clean_player["haptics_enabled"] = bool(source_player.get("haptics_enabled", true))
		clean_player["vibration_scale"] = clampf(float(source_player.get("vibration_scale", 0.85)), 0.0, 1.0)
		clean["players"][key] = clean_player
	clean["advanced_training_completed"] = bool(source.get("advanced_training_completed", false))
	return clean

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file != null:
		profile = _sanitize_profile(JSON.parse_string(file.get_as_text()))

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile, "  "))

func current_profile() -> Dictionary:
	return profile.duplicate(true)

func apply_profile() -> Dictionary:
	profile = _sanitize_profile(profile)
	for player_index in [1, 2]:
		_remove_native_stick_events(player_index)
		_apply_trigger_aliases(player_index)
	_sync_web_state()
	return current_state()

func set_tuning(
	player_index: int,
	curve_id: StringName,
	trigger_threshold: float,
	haptics_enabled: bool,
	vibration_scale: float
) -> bool:
	if player_index < 1 or player_index > 2 or curve_id not in CURVE_IDS:
		return false
	var player := _experience_player(player_index)
	player["response_curve"] = String(curve_id)
	player["trigger_threshold"] = clampf(trigger_threshold, MIN_TRIGGER_THRESHOLD, MAX_TRIGGER_THRESHOLD)
	player["haptics_enabled"] = haptics_enabled
	player["vibration_scale"] = clampf(vibration_scale, 0.0, 1.0)
	profile["players"][str(player_index)] = player
	apply_profile()
	_save_profile()
	return true

func set_player_device(player_index: int, device: int) -> bool:
	var base := _base_runtime()
	if not is_instance_valid(base) or player_index < 1 or player_index > 2:
		return false
	var base_profile: Dictionary = base.current_profile()
	var players: Dictionary = base_profile.get("players", {})
	var player: Dictionary = players.get(str(player_index), {})
	player["device"] = maxi(-1, device)
	players[str(player_index)] = player
	base_profile["players"] = players
	base.profile = base_profile
	base.apply_profile()
	base.call("_save_profile")
	apply_profile()
	return true

func set_player_deadzone(player_index: int, deadzone: float) -> bool:
	var base := _base_runtime()
	if not is_instance_valid(base):
		return false
	var applied := bool(base.set_deadzone(player_index, deadzone))
	if applied:
		apply_profile()
	return applied

func set_player_button(player_index: int, suffix: String, button_index: int, device: int = -2) -> bool:
	var base := _base_runtime()
	if not is_instance_valid(base):
		return false
	var applied := bool(base.set_button_binding(player_index, suffix, button_index, device))
	if applied:
		apply_profile()
	return applied

func reset_all_profiles() -> Dictionary:
	var base := _base_runtime()
	if is_instance_valid(base):
		base.reset_profile()
	var completed := bool(profile.get("advanced_training_completed", false))
	profile = _default_profile()
	profile["advanced_training_completed"] = completed
	apply_profile()
	_save_profile()
	return current_state()

func calibrate_stick(player_index: int) -> Dictionary:
	var device := _player_device(player_index)
	var drift := _stick_drift(device)
	var suggested := clampf(drift + 0.08, 0.15, 0.55)
	set_player_deadzone(player_index, suggested)
	return {"device": device, "drift": drift, "deadzone": suggested}

func calibrate_triggers(player_index: int) -> Dictionary:
	var device := _player_device(player_index)
	var left := _normalized_trigger(device, JOY_AXIS_TRIGGER_LEFT)
	var right := _normalized_trigger(device, JOY_AXIS_TRIGGER_RIGHT)
	var suggested := clampf(maxf(left, right) + 0.18, MIN_TRIGGER_THRESHOLD, MAX_TRIGGER_THRESHOLD)
	var player := _experience_player(player_index)
	set_tuning(
		player_index,
		StringName(player.get("response_curve", "linear")),
		suggested,
		bool(player.get("haptics_enabled", true)),
		float(player.get("vibration_scale", 0.85))
	)
	return {"device": device, "left": left, "right": right, "threshold": suggested}

func horizontal_axis(player_index: int) -> float:
	var left_action := _player_action(player_index, "left")
	var right_action := _player_action(player_index, "right")
	var fallback := 0.0
	if InputMap.has_action(left_action) and InputMap.has_action(right_action):
		fallback = Input.get_axis(left_action, right_action)
	var device := _player_device(player_index)
	if device < 0 or not Input.is_joy_known(device):
		return fallback
	var raw := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var deadzone := _player_deadzone(player_index)
	if absf(raw) <= deadzone:
		return fallback
	return _curve_value(raw, deadzone, StringName(_experience_player(player_index).get("response_curve", "linear")))

func _inject_curved_stick(player_index: int) -> void:
	if not _movement_actions_exist(player_index):
		return
	var device := _player_device(player_index)
	if device < 0 or not Input.is_joy_known(device):
		_release_player_curve_actions(player_index)
		return
	var deadzone := _player_deadzone(player_index)
	var curve_id := StringName(_experience_player(player_index).get("response_curve", "linear"))
	var horizontal := _curve_value(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), deadzone, curve_id)
	var vertical := _curve_value(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), deadzone, curve_id)
	_apply_action_strength(_player_action(player_index, "left"), maxf(0.0, -horizontal))
	_apply_action_strength(_player_action(player_index, "right"), maxf(0.0, horizontal))
	_apply_action_strength(_player_action(player_index, "down"), maxf(0.0, vertical))

func _movement_actions_exist(player_index: int) -> bool:
	for suffix in ["left", "right", "down"]:
		if not InputMap.has_action(_player_action(player_index, suffix)):
			return false
	return true

func _apply_action_strength(action_id: StringName, strength: float) -> void:
	if not InputMap.has_action(action_id):
		return
	if strength > 0.001:
		Input.action_press(action_id, strength)
	else:
		Input.action_release(action_id)

func _release_curve_actions() -> void:
	for player_index in [1, 2]:
		_release_player_curve_actions(player_index)

func _release_player_curve_actions(player_index: int) -> void:
	for suffix in ["left", "right", "down"]:
		var action_id := _player_action(player_index, suffix)
		if InputMap.has_action(action_id):
			Input.action_release(action_id)

func _curve_value(raw: float, deadzone: float, curve_id: StringName) -> float:
	var magnitude := absf(raw)
	if magnitude <= deadzone:
		return 0.0
	var normalized := clampf((magnitude - deadzone) / maxf(0.001, 1.0 - deadzone), 0.0, 1.0)
	var exponent := 1.0
	match curve_id:
		&"precision":
			exponent = 1.65
		&"aggressive":
			exponent = 0.68
	return signf(raw) * pow(normalized, exponent)

func _remove_native_stick_events(player_index: int) -> void:
	for suffix in ["left", "right", "down"]:
		var action_id := _player_action(player_index, suffix)
		if not InputMap.has_action(action_id):
			continue
		for event in InputMap.action_get_events(action_id).duplicate():
			if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
				InputMap.action_erase_event(action_id, event)

func _apply_trigger_aliases(player_index: int) -> void:
	var device := _player_device(player_index)
	var threshold := float(_experience_player(player_index).get("trigger_threshold", DEFAULT_TRIGGER_THRESHOLD))
	_apply_trigger_event(_player_action(player_index, "element"), JOY_AXIS_TRIGGER_LEFT, device, threshold)
	_apply_trigger_event(_player_action(player_index, "attack"), JOY_AXIS_TRIGGER_RIGHT, device, threshold)

func _apply_trigger_event(action_id: StringName, axis: JoyAxis, device: int, threshold: float) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, threshold)
	for event in InputMap.action_get_events(action_id).duplicate():
		if event is InputEventJoypadMotion and event.axis == axis:
			InputMap.action_erase_event(action_id, event)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = axis
	trigger.axis_value = 1.0
	trigger.device = device
	InputMap.action_add_event(action_id, trigger)
	InputMap.action_set_deadzone(action_id, threshold)

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not node is FighterController:
			continue
		var fighter := node as FighterController
		var fighter_id := fighter.get_instance_id()
		if _connected_fighters.has(fighter_id):
			continue
		_connected_fighters[fighter_id] = true
		_connect_if_available(fighter, "technique_experienced", "_on_technique_experienced")
		_connect_if_available(fighter, "parry_performed", "_on_parry_performed")
		_connect_if_available(fighter, "posture_broken", "_on_posture_broken")
		_connect_if_available(fighter, "grab_started", "_on_grab_started")
		_connect_if_available(fighter, "grab_finished", "_on_grab_finished")
		_connect_if_available(fighter, "grab_escaped", "_on_grab_escaped")
		_connect_if_available(fighter, "weapon_swapped", "_on_weapon_swapped")
		_connect_if_available(fighter, "technique_reproduced", "_on_technique_reproduced")

func _connect_if_available(fighter: FighterController, signal_name: StringName, method_name: StringName) -> void:
	if not fighter.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not fighter.is_connected(signal_name, callback):
		fighter.connect(signal_name, callback)

func _on_technique_experienced(
	defender: FighterController,
	attacker: FighterController,
	_technique_id: StringName,
	outcome_id: StringName
) -> void:
	match outcome_id:
		&"hit":
			_vibrate_fighter(defender, 0.42, 0.72, 0.18)
			_vibrate_fighter(attacker, 0.18, 0.08, 0.08)
		&"blocked":
			_vibrate_fighter(defender, 0.24, 0.18, 0.11)
			_vibrate_fighter(attacker, 0.12, 0.20, 0.09)
		&"parried":
			_vibrate_fighter(defender, 0.20, 0.86, 0.15)
			_vibrate_fighter(attacker, 0.44, 0.28, 0.18)
		&"evaded":
			_vibrate_fighter(attacker, 0.10, 0.14, 0.07)

func _on_parry_performed(fighter: FighterController) -> void:
	_vibrate_fighter(fighter, 0.18, 1.0, 0.17)

func _on_posture_broken(fighter: FighterController, _region_id: StringName) -> void:
	_vibrate_fighter(fighter, 0.75, 1.0, 0.36)

func _on_grab_started(attacker: FighterController, target: FighterController) -> void:
	_vibrate_fighter(attacker, 0.28, 0.20, 0.12)
	_vibrate_fighter(target, 0.48, 0.36, 0.16)
	if not _advanced_active:
		return
	if _advanced_stage == 0 and attacker == _player_one and target == _player_two:
		attacker.call("_release_grab_without_throw")
		_set_advanced_stage(1)
	elif _advanced_stage == 1 and attacker == _player_two and target == _player_one:
		_player_two.set("_grab_timer", 6.0)
		_escape_grab_started = true
		_advanced_label.text = "2/4 • FUGA REAL\nAlterne esquerda/direita e combine Esquiva, Golpe ou Guarda.\nA etapa exige o sinal grab_escaped."

func _on_grab_finished(attacker: FighterController, target: FighterController) -> void:
	_vibrate_fighter(attacker, 0.22, 0.34, 0.12)
	_vibrate_fighter(target, 0.34, 0.58, 0.16)

func _on_grab_escaped(fighter: FighterController, attacker: FighterController) -> void:
	_vibrate_fighter(fighter, 0.18, 0.78, 0.18)
	if _advanced_active and _advanced_stage == 1 and fighter == _player_one and attacker == _player_two:
		_set_advanced_stage(2)

func _on_weapon_swapped(
	fighter: WeaponKitFighterController,
	_from_weapon_id: StringName,
	_to_weapon_id: StringName,
	_slot_id: int
) -> void:
	_vibrate_fighter(fighter, 0.16, 0.12, 0.08)
	if _advanced_active and _advanced_stage == 2 and fighter == _player_one:
		_set_advanced_stage(3)

func _on_technique_reproduced(fighter: FighterController, _technique_id: StringName) -> void:
	_vibrate_fighter(fighter, 0.30, 0.70, 0.20)
	if _advanced_active and _advanced_stage == 3 and fighter == _player_one:
		_complete_advanced_dojo()

func _vibrate_fighter(fighter: FighterController, weak: float, strong: float, duration: float) -> bool:
	if not is_instance_valid(fighter):
		return false
	return vibrate_player(fighter.player_index, weak, strong, duration)

func vibrate_player(player_index: int, weak: float, strong: float, duration: float) -> bool:
	var tuning := _experience_player(player_index)
	if not bool(tuning.get("haptics_enabled", true)):
		return false
	var device := _player_device(player_index)
	if device < 0 or not Input.is_joy_known(device):
		return false
	var scale := float(tuning.get("vibration_scale", 0.85))
	Input.start_joy_vibration(
		device,
		clampf(weak * scale, 0.0, 1.0),
		clampf(strong * scale, 0.0, 1.0),
		maxf(0.02, duration)
	)
	return true

func start_advanced_dojo() -> bool:
	if _advanced_active:
		return true
	var base_training := _base_runtime()
	if is_instance_valid(base_training):
		base_training.stop_real_practice("Dojo avançado iniciado.")
	_scene = get_tree().current_scene
	if not is_instance_valid(_scene):
		return false
	_prepare_scene()
	await get_tree().process_frame
	await get_tree().physics_frame
	_player_one = _scene.get("player_one") as FighterController
	_player_two = _scene.get("player_two") as FighterController
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return false
	_advanced_active = true
	_disable_player_two_inputs()
	_discover_fighters()
	_advanced_panel.visible = true
	_set_advanced_stage(0)
	_sync_web_state()
	return true

func _prepare_scene() -> void:
	var p1 = _scene.get("player_one")
	var p2 = _scene.get("player_two")
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		var preparation = _scene.get("preparation_runtime")
		if is_instance_valid(preparation) and preparation.has_method("close"):
			preparation.call("close")
		if _scene.has_method("_cleanup_temporary_loot"):
			_scene.call("_cleanup_temporary_loot")
		var arena = _scene.get("arena")
		if is_instance_valid(arena) and arena.has_method("reset_battle_flow"):
			arena.call("reset_battle_flow")
		if _scene.has_method("_spawn_fighters"):
			_scene.call("_spawn_fighters")
		_scene.set("_state", 2)
	var center = _scene.get("center_label")
	var controls = _scene.get("controls_label")
	if is_instance_valid(center):
		center.text = "DOJO AVANÇADO TAI • JI • FU"
	if is_instance_valid(controls):
		controls.text = "Agarrão, fuga, troca de arma e eco. Esc encerra."

func _set_advanced_stage(stage: int) -> void:
	_advanced_stage = stage
	_advanced_timer = 0.55
	_escape_grab_started = false
	_reset_advanced_positions()
	match stage:
		0:
			_advanced_label.text = "1/4 • AGARRÃO CONFIRMADO\nAgarre o alvo com a técnica Ji.\nA etapa só avança pelo sinal grab_started."
		1:
			_advanced_label.text = "2/4 • PREPARE A FUGA\nO alvo iniciará um agarrão real.\nEscape alternando direção e combinando suas ações."
		2:
			_advanced_label.text = "3/4 • ADAPTAÇÃO DE ARMA\nTroque para a arma secundária.\nA etapa exige o sinal weapon_swapped."
		3:
			_player_one.borrowed_technique_id = ADVANCED_ECHO_TECHNIQUE
			_advanced_label.text = "4/4 • ECO CONFIRMADO\nUse Eco para reproduzir a técnica armazenada.\nA etapa exige technique_reproduced."
	_sync_web_state()

func _process_advanced_dojo(delta: float) -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		stop_advanced_dojo("Lutadores indisponíveis.")
		return
	if _advanced_stage != 1 or _escape_grab_started:
		return
	_advanced_timer -= delta
	if _advanced_timer <= 0.0:
		_advanced_timer = 1.1
		_script_player_two_grab()

func _script_player_two_grab() -> void:
	if int(_player_two.get("_attack_phase")) != FighterController.AttackPhase.NONE:
		return
	_player_one.facing = 1.0
	_player_two.facing = -1.0
	_player_two.global_position = Vector2(_player_one.global_position.x + 46.0, _player_one.global_position.y)
	_player_two.velocity = Vector2.ZERO
	_player_two.stamina = 100.0
	_player_two.call("_begin_technique", ADVANCED_GRAB_TECHNIQUE)

func _reset_advanced_positions() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return
	var base_position := _player_one.global_position
	var arena = _scene.get("arena")
	if is_instance_valid(arena) and arena.has_method("respawn_point"):
		base_position = arena.call("respawn_point", 1)
	_player_one.reset_fighter(base_position)
	_player_two.reset_fighter(base_position + Vector2(72.0, 0.0))
	_player_one.facing = 1.0
	_player_two.facing = -1.0

func _complete_advanced_dojo() -> void:
	profile["advanced_training_completed"] = true
	_save_profile()
	_advanced_label.text = "DOJO AVANÇADO CONCLUÍDO\nO Godot confirmou agarrão, fuga, troca de arma e eco."
	await get_tree().create_timer(1.8, true, false, true).timeout
	stop_advanced_dojo("Dojo avançado concluído.")

func stop_advanced_dojo(_message: String = "") -> void:
	if not _advanced_active:
		return
	_advanced_active = false
	_advanced_panel.visible = false
	_restore_player_two_inputs()
	if is_instance_valid(_player_one) and is_instance_valid(_player_two):
		_reset_advanced_positions()
	if is_instance_valid(_scene):
		var arena = _scene.get("arena")
		if is_instance_valid(arena) and arena.has_method("start_battle_flow"):
			arena.call("start_battle_flow")
		var center = _scene.get("center_label")
		var controls = _scene.get("controls_label")
		if is_instance_valid(center):
			center.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
		if is_instance_valid(controls):
			controls.text = "F10 abre o laboratório de gamepad."
	apply_profile()
	_sync_web_state()

func _disable_player_two_inputs() -> void:
	_saved_player_two_events.clear()
	for suffix in ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "echo", "block", "element", "swap"]:
		var action_id := _player_action(2, suffix)
		if not InputMap.has_action(action_id):
			continue
		var events := []
		for event in InputMap.action_get_events(action_id):
			events.append(event.duplicate())
		_saved_player_two_events[String(action_id)] = events
		InputMap.action_erase_events(action_id)
	_release_player_curve_actions(2)

func _restore_player_two_inputs() -> void:
	for action_key in _saved_player_two_events.keys():
		var action_id := StringName(action_key)
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id, 0.25)
		InputMap.action_erase_events(action_id)
		for event in _saved_player_two_events[action_key]:
			InputMap.action_add_event(action_id, event)
	_saved_player_two_events.clear()

func _create_advanced_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 121
	add_child(_canvas)
	_advanced_panel = ColorRect.new()
	_advanced_panel.anchor_left = 0.20
	_advanced_panel.anchor_top = 0.03
	_advanced_panel.anchor_right = 0.80
	_advanced_panel.anchor_bottom = 0.24
	_advanced_panel.color = Color(0.035, 0.026, 0.060, 0.96)
	_advanced_panel.visible = false
	_canvas.add_child(_advanced_panel)
	_advanced_label = Label.new()
	_advanced_label.anchor_left = 0.04
	_advanced_label.anchor_top = 0.08
	_advanced_label.anchor_right = 0.96
	_advanced_label.anchor_bottom = 0.92
	_advanced_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advanced_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_advanced_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advanced_label.add_theme_font_size_override("font_size", 15)
	_advanced_label.add_theme_color_override("font_color", Color(0.96, 0.93, 1.0))
	_advanced_panel.add_child(_advanced_label)

func _base_runtime() -> GamepadTrainingRuntime:
	return get_node_or_null("/root/TaijifuGamepadTraining") as GamepadTrainingRuntime

func _base_profile() -> Dictionary:
	var base := _base_runtime()
	return base.current_profile() if is_instance_valid(base) else {"players": {}}

func _base_player(player_index: int) -> Dictionary:
	var players: Dictionary = _base_profile().get("players", {})
	var value = players.get(str(player_index), {})
	return value if value is Dictionary else {}

func _experience_player(player_index: int) -> Dictionary:
	var players: Dictionary = profile.get("players", {})
	var value = players.get(str(player_index), {})
	return value if value is Dictionary else {}

func _player_device(player_index: int) -> int:
	return int(_base_player(player_index).get("device", player_index - 1))

func _player_deadzone(player_index: int) -> float:
	return clampf(float(_base_player(player_index).get("deadzone", 0.25)), 0.0, 0.95)

func _player_action(player_index: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _stick_drift(device: int) -> float:
	if device < 0 or not Input.is_joy_known(device):
		return 0.0
	return maxf(absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)), absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))

func _normalized_trigger(device: int, axis: JoyAxis) -> float:
	if device < 0 or not Input.is_joy_known(device):
		return 0.0
	var raw := Input.get_joy_axis(device, axis)
	var other_axis := JOY_AXIS_TRIGGER_RIGHT if axis == JOY_AXIS_TRIGGER_LEFT else JOY_AXIS_TRIGGER_LEFT
	var other := Input.get_joy_axis(device, other_axis)
	var bipolar := raw < -0.25 or other < -0.25
	return clampf((raw + 1.0) * 0.5 if bipolar else raw, 0.0, 1.0)

func connected_devices() -> Array:
	var devices := []
	for device in Input.get_connected_joypads():
		devices.append({
			"id": device,
			"name": Input.get_joy_name(device),
			"guid": Input.get_joy_guid(device),
			"left_x": Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			"left_y": Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
			"left_trigger": _normalized_trigger(device, JOY_AXIS_TRIGGER_LEFT),
			"right_trigger": _normalized_trigger(device, JOY_AXIS_TRIGGER_RIGHT)
		})
	return devices

func current_state() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"profile": current_profile(),
		"base_profile": _base_profile(),
		"devices": connected_devices(),
		"advanced_training": {
			"active": _advanced_active,
			"stage": _advanced_stage,
			"completed": bool(profile.get("advanced_training_completed", false))
		}
	}

func command(request: Dictionary) -> Dictionary:
	var command_id := StringName(request.get("command", "get_state"))
	match command_id:
		&"set_tuning":
			set_tuning(
				int(request.get("player", 1)),
				StringName(request.get("curve", "linear")),
				float(request.get("trigger_threshold", DEFAULT_TRIGGER_THRESHOLD)),
				bool(request.get("haptics_enabled", true)),
				float(request.get("vibration_scale", 0.85))
			)
		&"set_device":
			set_player_device(int(request.get("player", 1)), int(request.get("device", -1)))
		&"set_deadzone":
			set_player_deadzone(int(request.get("player", 1)), float(request.get("deadzone", 0.25)))
		&"set_binding":
			set_player_button(
				int(request.get("player", 1)),
				String(request.get("suffix", "attack")),
				int(request.get("button", JOY_BUTTON_X)),
				int(request.get("device", -2))
			)
		&"calibrate_stick":
			calibrate_stick(int(request.get("player", 1)))
		&"calibrate_triggers":
			calibrate_triggers(int(request.get("player", 1)))
		&"test_vibration":
			vibrate_player(int(request.get("player", 1)), 0.45, 0.75, 0.30)
		&"start_fundamentals":
			var fundamental_runtime := _base_runtime()
			if is_instance_valid(fundamental_runtime):
				fundamental_runtime.call_deferred("start_real_practice")
		&"start_advanced":
			call_deferred("start_advanced_dojo")
		&"stop_training":
			var stop_runtime := _base_runtime()
			if is_instance_valid(stop_runtime):
				stop_runtime.stop_real_practice("Treino encerrado pela interface Web.")
			stop_advanced_dojo("Treino encerrado pela interface Web.")
		&"reset":
			reset_all_profiles()
	return current_state()

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var command_callback := JavaScriptBridge.create_callback(_web_command)
	var state_callback := JavaScriptBridge.create_callback(_web_state)
	_callbacks = [command_callback, state_callback]
	_window.taijifuGamepadExperienceCommand = command_callback
	_window.taijifuGamepadExperienceState = state_callback
	_window.taijifuGamepadExperienceVersion = BRIDGE_VERSION
	_window.taijifuGamepadExperienceReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify(current_state())
	var parsed: Variant = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return JSON.stringify(current_state())
	return JSON.stringify(command(parsed as Dictionary))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGamepadExperienceStateJson = JSON.stringify(current_state())
	_window.taijifuGamepadExperienceReady = true

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	apply_profile()

func curve_value_for_test(raw: float, deadzone: float, curve_id: StringName) -> float:
	return _curve_value(raw, deadzone, curve_id)

func set_tuning_for_test(player_index: int, curve_id: StringName, trigger_threshold: float, haptics_enabled: bool, vibration_scale: float) -> bool:
	return set_tuning(player_index, curve_id, trigger_threshold, haptics_enabled, vibration_scale)

func record_advanced_event_for_test(event_id: StringName) -> int:
	match event_id:
		&"grab_started":
			if _advanced_stage == 0:
				_advanced_stage = 1
		&"grab_escaped":
			if _advanced_stage == 1:
				_advanced_stage = 2
		&"weapon_swapped":
			if _advanced_stage == 2:
				_advanced_stage = 3
		&"technique_reproduced":
			if _advanced_stage == 3:
				_advanced_stage = 4
	return _advanced_stage
