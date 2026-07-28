class_name GamepadTrainingRuntime
extends Node

const PROFILE_PATH := "user://gamepad-training-profile.json"
const DEFAULT_DEADZONE := 0.25
const MIN_DEADZONE := 0.15
const MAX_DEADZONE := 0.55
const ATTACK_INTERVAL := 1.45
const TRAINING_TECHNIQUE := &"ji_body_hook"

const BUTTON_ACTIONS := [
	{"suffix": "jump", "label": "Pular", "button": JOY_BUTTON_A},
	{"suffix": "dodge", "label": "Esquiva", "button": JOY_BUTTON_B},
	{"suffix": "attack", "label": "Golpe", "button": JOY_BUTTON_X},
	{"suffix": "push", "label": "Empurrão", "button": JOY_BUTTON_Y},
	{"suffix": "grab", "label": "Agarrão", "button": JOY_BUTTON_LEFT_SHOULDER},
	{"suffix": "block", "label": "Guarda/aparo", "button": JOY_BUTTON_RIGHT_SHOULDER},
	{"suffix": "element", "label": "Elemento", "button": JOY_BUTTON_LEFT_STICK},
	{"suffix": "echo", "label": "Eco", "button": JOY_BUTTON_RIGHT_STICK},
	{"suffix": "swap", "label": "Trocar arma", "button": JOY_BUTTON_BACK}
]

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A / Cruz",
	JOY_BUTTON_B: "B / Círculo",
	JOY_BUTTON_X: "X / Quadrado",
	JOY_BUTTON_Y: "Y / Triângulo",
	JOY_BUTTON_BACK: "Select / View",
	JOY_BUTTON_START: "Start / Menu",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB / L1",
	JOY_BUTTON_RIGHT_SHOULDER: "RB / R1",
	JOY_BUTTON_DPAD_UP: "D-pad ↑",
	JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←",
	JOY_BUTTON_DPAD_RIGHT: "D-pad →"
}

var profile: Dictionary = {}
var _canvas: CanvasLayer
var _panel: ColorRect
var _panel_label: Label
var _practice_panel: ColorRect
var _practice_label: Label
var _selected_player := 1
var _selected_action := 0
var _capturing := false
var _capture_ready_at := 0
var _feedback := ""
var _refresh_timer := 0.0
var _practice_active := false
var _practice_stage := 0
var _attack_timer := 0.0
var _scene: Node
var _player_one: FighterController
var _player_two: FighterController
var _saved_p2_events: Dictionary = {}
var _connected_fighters: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _default_profile()
	_load_profile()
	_register_toggle_action()
	_create_interface()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	call_deferred("_apply_after_scene_ready")

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _panel.visible and _refresh_timer <= 0.0:
		_refresh_timer = 0.12
		_refresh_panel()
	if _practice_active:
		_process_practice(delta)

func _input(event: InputEvent) -> void:
	if _capturing:
		_capture_event(event)
		return
	if _practice_active:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			stop_real_practice("Treino encerrado pelo jogador.")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"gamepad_lab_toggle"):
		_panel.visible = not _panel.visible
		_refresh_panel()
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_panel_key(event.physical_keycode)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_up"):
		_selected_action = wrapi(_selected_action - 1, 0, BUTTON_ACTIONS.size())
	elif event.is_action_pressed(&"ui_down"):
		_selected_action = wrapi(_selected_action + 1, 0, BUTTON_ACTIONS.size())
	elif event.is_action_pressed(&"ui_left"):
		_adjust_deadzone(-0.02)
	elif event.is_action_pressed(&"ui_right"):
		_adjust_deadzone(0.02)
	elif event.is_action_pressed(&"ui_accept"):
		_begin_capture()
	elif event.is_action_pressed(&"ui_cancel"):
		_panel.visible = false
	else:
		return
	_refresh_panel()
	get_viewport().set_input_as_handled()

func _handle_panel_key(keycode: Key) -> void:
	match keycode:
		KEY_1:
			_selected_player = 1
			_feedback = "Jogador 1 selecionado."
		KEY_2:
			_selected_player = 2
			_feedback = "Jogador 2 selecionado."
		KEY_UP:
			_selected_action = wrapi(_selected_action - 1, 0, BUTTON_ACTIONS.size())
		KEY_DOWN:
			_selected_action = wrapi(_selected_action + 1, 0, BUTTON_ACTIONS.size())
		KEY_LEFT:
			_adjust_deadzone(-0.02)
		KEY_RIGHT:
			_adjust_deadzone(0.02)
		KEY_ENTER, KEY_SPACE:
			_begin_capture()
		KEY_D:
			_auto_calibrate()
		KEY_P:
			start_real_practice()
		KEY_R:
			reset_profile()
		KEY_ESCAPE:
			_panel.visible = false
	_refresh_panel()

func _apply_after_scene_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	apply_profile()

func _default_profile() -> Dictionary:
	var players := {}
	for player_index in [1, 2]:
		var buttons := {}
		for action in BUTTON_ACTIONS:
			buttons[String(action["suffix"])] = int(action["button"])
		players[str(player_index)] = {
			"device": player_index - 1,
			"deadzone": DEFAULT_DEADZONE,
			"buttons": buttons
		}
	return {
		"version": 1,
		"players": players,
		"real_training_completed": false
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
		clean_player["device"] = maxi(-1, int(source_player.get("device", player_index - 1)))
		clean_player["deadzone"] = clampf(float(source_player.get("deadzone", DEFAULT_DEADZONE)), MIN_DEADZONE, MAX_DEADZONE)
		var clean_buttons: Dictionary = clean_player["buttons"]
		var source_buttons: Dictionary = source_player.get("buttons", {})
		for action in BUTTON_ACTIONS:
			var suffix := String(action["suffix"])
			clean_buttons[suffix] = clampi(int(source_buttons.get(suffix, action["button"])), JOY_BUTTON_A, JOY_BUTTON_MAX - 1)
		clean_player["buttons"] = clean_buttons
		clean["players"][key] = clean_player
	clean["real_training_completed"] = bool(source.get("real_training_completed", false))
	return clean

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file != null:
		profile = _sanitize_profile(JSON.parse_string(file.get_as_text()))

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		_feedback = "Não foi possível salvar o perfil."
		return
	file.store_string(JSON.stringify(profile, "  "))

func current_profile() -> Dictionary:
	return profile.duplicate(true)

func apply_profile() -> Dictionary:
	profile = _sanitize_profile(profile)
	for player_index in [1, 2]:
		var player := _player_profile(player_index)
		var device := int(player.get("device", player_index - 1))
		var deadzone := float(player.get("deadzone", DEFAULT_DEADZONE))
		var buttons: Dictionary = player.get("buttons", {})
		for action in BUTTON_ACTIONS:
			var suffix := String(action["suffix"])
			_apply_button(_player_action(player_index, suffix), int(buttons.get(suffix, action["button"])), device, deadzone)
		for suffix in ["left", "right", "down"]:
			var movement_action := _player_action(player_index, suffix)
			if InputMap.has_action(movement_action):
				InputMap.action_set_deadzone(movement_action, deadzone)
	return current_profile()

func reset_profile() -> Dictionary:
	var completed := bool(profile.get("real_training_completed", false))
	profile = _default_profile()
	profile["real_training_completed"] = completed
	apply_profile()
	_save_profile()
	_feedback = "Perfil padrão restaurado."
	_refresh_panel()
	return current_profile()

func set_button_binding(player_index: int, suffix: String, button_index: int, device: int = -2) -> bool:
	if player_index < 1 or player_index > 2 or not _valid_suffix(suffix):
		return false
	if button_index < JOY_BUTTON_A or button_index >= JOY_BUTTON_MAX:
		return false
	var player := _player_profile(player_index)
	if device != -2:
		player["device"] = maxi(-1, device)
	var buttons: Dictionary = player.get("buttons", {})
	var previous := int(buttons.get(suffix, button_index))
	var conflict := ""
	for action in BUTTON_ACTIONS:
		var other := String(action["suffix"])
		if other != suffix and int(buttons.get(other, -1)) == button_index:
			conflict = other
			break
	buttons[suffix] = button_index
	if conflict != "":
		buttons[conflict] = previous
	player["buttons"] = buttons
	profile["players"][str(player_index)] = player
	apply_profile()
	_save_profile()
	return true

func set_deadzone(player_index: int, value: float) -> bool:
	if player_index < 1 or player_index > 2:
		return false
	var player := _player_profile(player_index)
	player["deadzone"] = clampf(value, MIN_DEADZONE, MAX_DEADZONE)
	profile["players"][str(player_index)] = player
	apply_profile()
	_save_profile()
	return true

func _apply_button(action_id: StringName, button_index: int, device: int, deadzone: float) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, deadzone)
	for event in InputMap.action_get_events(action_id).duplicate():
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action_id, event)
	var new_event := InputEventJoypadButton.new()
	new_event.button_index = button_index
	new_event.device = device
	InputMap.action_add_event(action_id, new_event)
	InputMap.action_set_deadzone(action_id, deadzone)

func _register_toggle_action() -> void:
	if not InputMap.has_action(&"gamepad_lab_toggle"):
		InputMap.add_action(&"gamepad_lab_toggle", 0.5)
	var has_key := false
	var has_start := false
	for event in InputMap.action_get_events(&"gamepad_lab_toggle"):
		if event is InputEventKey and event.physical_keycode == KEY_F10:
			has_key = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
			has_start = true
	if not has_key:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_F10
		InputMap.action_add_event(&"gamepad_lab_toggle", key_event)
	if not has_start:
		var start_event := InputEventJoypadButton.new()
		start_event.button_index = JOY_BUTTON_START
		start_event.device = -1
		InputMap.action_add_event(&"gamepad_lab_toggle", start_event)

func _create_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 120
	add_child(_canvas)
	_panel = ColorRect.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.color = Color(0.01, 0.018, 0.032, 0.95)
	_panel.visible = false
	_canvas.add_child(_panel)
	_panel_label = Label.new()
	_panel_label.anchor_left = 0.16
	_panel_label.anchor_top = 0.08
	_panel_label.anchor_right = 0.84
	_panel_label.anchor_bottom = 0.92
	_panel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_label.add_theme_font_size_override("font_size", 16)
	_panel_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_panel.add_child(_panel_label)
	_practice_panel = ColorRect.new()
	_practice_panel.anchor_left = 0.20
	_practice_panel.anchor_top = 0.03
	_practice_panel.anchor_right = 0.80
	_practice_panel.anchor_bottom = 0.23
	_practice_panel.color = Color(0.025, 0.045, 0.072, 0.95)
	_practice_panel.visible = false
	_canvas.add_child(_practice_panel)
	_practice_label = Label.new()
	_practice_label.anchor_left = 0.04
	_practice_label.anchor_top = 0.08
	_practice_label.anchor_right = 0.96
	_practice_label.anchor_bottom = 0.92
	_practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_practice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_practice_label.add_theme_font_size_override("font_size", 15)
	_practice_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	_practice_panel.add_child(_practice_label)
	_refresh_panel()

func _refresh_panel() -> void:
	if not is_instance_valid(_panel_label):
		return
	var player := _player_profile(_selected_player)
	var device := int(player.get("device", _selected_player - 1))
	var deadzone := float(player.get("deadzone", DEFAULT_DEADZONE))
	var device_name := Input.get_joy_name(device) if Input.is_joy_known(device) else "não detectado"
	var lines := [
		"LABORATÓRIO DE GAMEPAD • JOGADOR %d" % _selected_player,
		"Dispositivo %d: %s" % [device, device_name],
		"Zona morta %.2f • desvio %.3f" % [deadzone, _stick_drift(device)],
		""
	]
	var buttons: Dictionary = player.get("buttons", {})
	for index in range(BUTTON_ACTIONS.size()):
		var action: Dictionary = BUTTON_ACTIONS[index]
		var suffix := String(action["suffix"])
		var marker := "▶" if index == _selected_action else " "
		lines.append("%s %-16s  %s" % [marker, String(action["label"]), _button_name(int(buttons.get(suffix, action["button"])))])
	if _capturing:
		lines.append("")
		lines.append("PRESSIONE O NOVO BOTÃO NO CONTROLE. ESC CANCELA.")
	lines.append("")
	lines.append("1/2 jogador • ↑↓ ação • Enter remapear • ←→ zona morta")
	lines.append("D calibrar • P treino real • R restaurar • Esc fechar")
	lines.append("Treino real: %s" % ("concluído" if bool(profile.get("real_training_completed", false)) else "pendente"))
	if _feedback != "":
		lines.append(_feedback)
	_panel_label.text = "\n".join(lines)

func _begin_capture() -> void:
	_capturing = true
	_capture_ready_at = Time.get_ticks_msec() + 180
	_feedback = "Aguardando botão do gamepad."
	_refresh_panel()

func _capture_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_capturing = false
		_feedback = "Captura cancelada."
		_refresh_panel()
		return
	if Time.get_ticks_msec() < _capture_ready_at or not event is InputEventJoypadButton:
		return
	var joy_event := event as InputEventJoypadButton
	if not joy_event.pressed or joy_event.button_index in [JOY_BUTTON_GUIDE, JOY_BUTTON_START]:
		return
	var action: Dictionary = BUTTON_ACTIONS[_selected_action]
	set_button_binding(_selected_player, String(action["suffix"]), joy_event.button_index, joy_event.device)
	_capturing = false
	_feedback = "%s = %s no dispositivo %d." % [String(action["label"]), _button_name(joy_event.button_index), joy_event.device]
	_refresh_panel()
	get_viewport().set_input_as_handled()

func _adjust_deadzone(delta: float) -> void:
	var current := float(_player_profile(_selected_player).get("deadzone", DEFAULT_DEADZONE))
	set_deadzone(_selected_player, current + delta)
	_feedback = "Zona morta ajustada para %.2f." % float(_player_profile(_selected_player).get("deadzone", DEFAULT_DEADZONE))

func _auto_calibrate() -> void:
	var player := _player_profile(_selected_player)
	var device := int(player.get("device", _selected_player - 1))
	var drift := _stick_drift(device)
	var suggested := clampf(drift + 0.08, MIN_DEADZONE, MAX_DEADZONE)
	set_deadzone(_selected_player, suggested)
	_feedback = "Calibração: desvio %.3f, zona morta %.2f." % [drift, suggested]

func _stick_drift(device: int) -> float:
	if device < 0 or not Input.is_joy_known(device):
		return 0.0
	return maxf(absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)), absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))

func start_real_practice() -> bool:
	if _practice_active:
		return true
	_scene = get_tree().current_scene
	if not is_instance_valid(_scene):
		_feedback = "Cena principal indisponível."
		return false
	_prepare_scene()
	await get_tree().process_frame
	await get_tree().physics_frame
	_player_one = _scene.get("player_one") as FighterController
	_player_two = _scene.get("player_two") as FighterController
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		_feedback = "Não foi possível preparar os lutadores."
		_refresh_panel()
		return false
	_practice_active = true
	_panel.visible = false
	_practice_panel.visible = true
	_disable_p2_inputs()
	_connect_fighter(_player_one)
	_connect_fighter(_player_two)
	_set_stage(0)
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
		center.text = "DOJO DE RESPOSTA REAL"
	if is_instance_valid(controls):
		controls.text = "Acerte, defenda e esquive. Esc encerra o treino."

func _connect_fighter(fighter: FighterController) -> void:
	var id := fighter.get_instance_id()
	if _connected_fighters.has(id):
		return
	_connected_fighters[id] = true
	if fighter.has_signal("technique_experienced"):
		fighter.connect("technique_experienced", Callable(self, "_on_technique_experienced"))

func _set_stage(stage: int) -> void:
	_practice_stage = stage
	_attack_timer = 0.55
	_reset_positions()
	match stage:
		0:
			_practice_label.text = "1/3 • ACERTO CONFIRMADO\nAcerte o alvo com uma técnica principal.\nA etapa só avança quando o hurtbox registrar hit real."
		1:
			_practice_label.text = "2/3 • DEFESA CONFIRMADA\nSegure Guarda diante do ataque do alvo.\nBlocked ou parried conclui esta etapa."
		2:
			_practice_label.text = "3/3 • ESQUIVA CONFIRMADA\nUse Esquiva durante o ataque do alvo.\nA etapa exige o resultado evaded."

func _process_practice(delta: float) -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		stop_real_practice("Lutadores indisponíveis.")
		return
	if _practice_stage == 0:
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_INTERVAL
		_scripted_attack()

func _scripted_attack() -> void:
	if int(_player_two.get("_attack_phase")) != FighterController.AttackPhase.NONE:
		return
	_player_one.facing = 1.0
	_player_two.facing = -1.0
	_player_two.global_position = Vector2(_player_one.global_position.x + 50.0, _player_one.global_position.y)
	_player_two.velocity = Vector2.ZERO
	_player_two.stamina = 100.0
	_player_two.call("_begin_technique", TRAINING_TECHNIQUE)

func _reset_positions() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return
	var base := _player_one.global_position
	var arena = _scene.get("arena")
	if is_instance_valid(arena) and arena.has_method("respawn_point"):
		base = arena.call("respawn_point", 1)
	_player_one.reset_fighter(base)
	_player_two.reset_fighter(base + Vector2(72.0, 0.0))
	_player_one.facing = 1.0
	_player_two.facing = -1.0

func _on_technique_experienced(defender: FighterController, attacker: FighterController, _technique_id: StringName, outcome_id: StringName) -> void:
	if not _practice_active:
		return
	if _practice_stage == 0 and defender == _player_two and attacker == _player_one and outcome_id == &"hit":
		_set_stage(1)
	elif _practice_stage == 1 and defender == _player_one and attacker == _player_two and outcome_id in [&"blocked", &"parried"]:
		_set_stage(2)
	elif _practice_stage == 2 and defender == _player_one and attacker == _player_two and outcome_id == &"evaded":
		_complete_practice()

func _complete_practice() -> void:
	profile["real_training_completed"] = true
	_save_profile()
	_practice_label.text = "TREINO REAL CONCLUÍDO\nO Godot confirmou hit, defesa e esquiva pelo sistema de combate."
	await get_tree().create_timer(1.8, true, false, true).timeout
	stop_real_practice("Treino real concluído.")

func stop_real_practice(message: String = "") -> void:
	if not _practice_active:
		return
	_practice_active = false
	_practice_panel.visible = false
	_restore_p2_inputs()
	if is_instance_valid(_player_one) and is_instance_valid(_player_two):
		_reset_positions()
	if is_instance_valid(_scene):
		var arena = _scene.get("arena")
		if is_instance_valid(arena) and arena.has_method("start_battle_flow"):
			arena.call("start_battle_flow")
		var center = _scene.get("center_label")
		var controls = _scene.get("controls_label")
		if is_instance_valid(center):
			center.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
		if is_instance_valid(controls):
			controls.text = "F10 abre o laboratório de gamepad e treino real."
	_feedback = message
	apply_profile()

func _disable_p2_inputs() -> void:
	_saved_p2_events.clear()
	for suffix in ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "echo", "block", "element", "swap"]:
		var action_id := _player_action(2, suffix)
		if not InputMap.has_action(action_id):
			continue
		var events := []
		for event in InputMap.action_get_events(action_id):
			events.append(event.duplicate())
		_saved_p2_events[String(action_id)] = events
		InputMap.action_erase_events(action_id)

func _restore_p2_inputs() -> void:
	for action_key in _saved_p2_events.keys():
		var action_id := StringName(action_key)
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id, DEFAULT_DEADZONE)
		InputMap.action_erase_events(action_id)
		for event in _saved_p2_events[action_key]:
			InputMap.action_add_event(action_id, event)
	_saved_p2_events.clear()

func _player_profile(player_index: int) -> Dictionary:
	var players: Dictionary = profile.get("players", {})
	var value = players.get(str(player_index), {})
	return value if value is Dictionary else {}

func _player_action(player_index: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _valid_suffix(suffix: String) -> bool:
	for action in BUTTON_ACTIONS:
		if String(action["suffix"]) == suffix:
			return true
	return false

func _button_name(button_index: int) -> String:
	return String(BUTTON_NAMES.get(button_index, "Botão %d" % button_index))

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_feedback = "Controle %d %s." % [device, "conectado" if connected else "desconectado"]
	_refresh_panel()

func set_button_binding_for_test(player_index: int, suffix: String, button_index: int, device: int) -> bool:
	return set_button_binding(player_index, suffix, button_index, device)

func set_deadzone_for_test(player_index: int, value: float) -> bool:
	return set_deadzone(player_index, value)

func record_outcome_for_test(defender_player: int, attacker_player: int, outcome_id: StringName) -> int:
	if defender_player == 2 and attacker_player == 1 and _practice_stage == 0 and outcome_id == &"hit":
		_practice_stage = 1
	elif defender_player == 1 and attacker_player == 2 and _practice_stage == 1 and outcome_id in [&"blocked", &"parried"]:
		_practice_stage = 2
	elif defender_player == 1 and attacker_player == 2 and _practice_stage == 2 and outcome_id == &"evaded":
		_practice_stage = 3
	return _practice_stage
