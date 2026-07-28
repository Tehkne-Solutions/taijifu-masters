class_name GamepadTrainingRuntime
extends Node

const PROFILE_PATH := "user://gamepad-training-profile.json"
const DEFAULT_DEADZONE := 0.25
const MIN_DEADZONE := 0.15
const MAX_DEADZONE := 0.55
const PRACTICE_ATTACK_INTERVAL := 1.45
const PRACTICE_TECHNIQUE := &"ji_body_hook"

const BUTTON_ACTIONS := [
	{"suffix": "jump", "label": "Pular", "default": JOY_BUTTON_A},
	{"suffix": "dodge", "label": "Esquiva", "default": JOY_BUTTON_B},
	{"suffix": "attack", "label": "Golpe", "default": JOY_BUTTON_X},
	{"suffix": "push", "label": "Empurrão", "default": JOY_BUTTON_Y},
	{"suffix": "grab", "label": "Agarrão", "default": JOY_BUTTON_LEFT_SHOULDER},
	{"suffix": "block", "label": "Guarda/aparo", "default": JOY_BUTTON_RIGHT_SHOULDER},
	{"suffix": "element", "label": "Elemento", "default": JOY_BUTTON_LEFT_STICK},
	{"suffix": "echo", "label": "Eco", "default": JOY_BUTTON_RIGHT_STICK},
	{"suffix": "swap", "label": "Trocar arma", "default": JOY_BUTTON_BACK}
]

const BUTTON_LABELS := {
	JOY_BUTTON_A: "A / Cruz",
	JOY_BUTTON_B: "B / Círculo",
	JOY_BUTTON_X: "X / Quadrado",
	JOY_BUTTON_Y: "Y / Triângulo",
	JOY_BUTTON_BACK: "Select / View",
	JOY_BUTTON_GUIDE: "Guide",
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
var _title_label: Label
var _body_label: Label
var _footer_label: Label
var _practice_panel: ColorRect
var _practice_title: Label
var _practice_body: Label
var _practice_footer: Label
var _selected_player := 1
var _selected_action_index := 0
var _capturing := false
var _capture_armed_at := 0
var _feedback := ""
var _refresh_timer := 0.0
var _practice_active := false
var _practice_stage := 0
var _practice_attack_timer := 0.0
var _practice_scene: Node
var _player_one: FighterController
var _player_two: FighterController
var _saved_player_two_events: Dictionary = {}
var _connected_fighter_ids: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _default_profile()
	_load_profile()
	_register_runtime_inputs()
	_create_interface()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	call_deferred("_deferred_apply_profile")

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _panel.visible and _refresh_timer <= 0.0:
		_refresh_timer = 0.12
		_update_panel()
	if _practice_active:
		_update_practice(delta)

func _input(event: InputEvent) -> void:
	if _capturing:
		_handle_capture_input(event)
		return

	if _practice_active:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			stop_real_practice("Treino encerrado pelo jogador.")
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"gamepad_lab_toggle"):
		_panel.visible = not _panel.visible
		_update_panel()
		get_viewport().set_input_as_handled()
		return

	if not _panel.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_selected_player = 1
				_feedback = "Jogador 1 selecionado."
			KEY_2:
				_selected_player = 2
				_feedback = "Jogador 2 selecionado."
			KEY_UP:
				_selected_action_index = wrapi(_selected_action_index - 1, 0, BUTTON_ACTIONS.size())
			KEY_DOWN:
				_selected_action_index = wrapi(_selected_action_index + 1, 0, BUTTON_ACTIONS.size())
			KEY_LEFT:
				_adjust_deadzone(-0.02)
			KEY_RIGHT:
				_adjust_deadzone(0.02)
			KEY_ENTER, KEY_SPACE:
				_begin_capture()
			KEY_D:
				_auto_calibrate_deadzone()
			KEY_P:
				start_real_practice()
			KEY_R:
				reset_profile()
			KEY_ESCAPE:
				_panel.visible = false
		_update_panel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_up"):
		_selected_action_index = wrapi(_selected_action_index - 1, 0, BUTTON_ACTIONS.size())
	elif event.is_action_pressed(&"ui_down"):
		_selected_action_index = wrapi(_selected_action_index + 1, 0, BUTTON_ACTIONS.size())
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
	_update_panel()
	get_viewport().set_input_as_handled()

func _deferred_apply_profile() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	apply_profile()

func _default_profile() -> Dictionary:
	var players: Dictionary = {}
	for player_index in [1, 2]:
		var buttons: Dictionary = {}
		for action in BUTTON_ACTIONS:
			buttons[String(action["suffix"])] = int(action["default"])
		players[String(player_index)] = {
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
	var sanitized := _default_profile()
	if not (value is Dictionary):
		return sanitized
	var source := value as Dictionary
	var source_players: Dictionary = source.get("players", {})
	for player_index in [1, 2]:
		var key := String(player_index)
		var default_player: Dictionary = sanitized["players"][key]
		var source_player: Dictionary = source_players.get(key, {})
		default_player["device"] = maxi(-1, int(source_player.get("device", player_index - 1)))
		default_player["deadzone"] = clampf(
			float(source_player.get("deadzone", DEFAULT_DEADZONE)),
			MIN_DEADZONE,
			MAX_DEADZONE
		)
		var source_buttons: Dictionary = source_player.get("buttons", {})
		var buttons: Dictionary = default_player["buttons"]
		for action in BUTTON_ACTIONS:
			var suffix := String(action["suffix"])
			buttons[suffix] = clampi(
				int(source_buttons.get(suffix, action["default"])),
				JOY_BUTTON_A,
				JOY_BUTTON_MAX - 1
			)
		default_player["buttons"] = buttons
		sanitized["players"][key] = default_player
	sanitized["real_training_completed"] = bool(source.get("real_training_completed", false))
	return sanitized

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	profile = _sanitize_profile(JSON.parse_string(file.get_as_text()))

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		_feedback = "Não foi possível salvar o perfil de gamepad."
		return
	file.store_string(JSON.stringify(profile, "  "))

func apply_profile() -> Dictionary:
	profile = _sanitize_profile(profile)
	for player_index in [1, 2]:
		var player := _player_profile(player_index)
		var device := int(player.get("device", player_index - 1))
		var deadzone := float(player.get("deadzone", DEFAULT_DEADZONE))
		var buttons: Dictionary = player.get("buttons", {})
		for action in BUTTON_ACTIONS:
			var suffix := String(action["suffix"])
			_set_joy_button_binding(
				_player_action(player_index, suffix),
				int(buttons.get(suffix, action["default"])),
				device,
				deadzone
			)
		for movement_suffix in ["left", "right", "down"]:
			var movement_action := _player_action(player_index, movement_suffix)
			if InputMap.has_action(movement_action):
				InputMap.action_set_deadzone(movement_action, deadzone)
	return current_profile()

func reset_profile() -> Dictionary:
	var completed := bool(profile.get("real_training_completed", false))
	profile = _default_profile()
	profile["real_training_completed"] = completed
	apply_profile()
	_save_profile()
	_feedback = "Mapeamento e zonas mortas restaurados."
	_update_panel()
	return current_profile()

func current_profile() -> Dictionary:
	return profile.duplicate(true)

func set_button_binding(player_index: int, suffix: String, button_index: int, device: int = -2) -> bool:
	if player_index < 1 or player_index > 2 or not _is_button_suffix(suffix):
		return false
	if button_index < JOY_BUTTON_A or button_index >= JOY_BUTTON_MAX:
		return false
	var player := _player_profile(player_index)
	if device != -2:
		player["device"] = maxi(-1, device)
	var buttons: Dictionary = player.get("buttons", {})
	var previous_button := int(buttons.get(suffix, button_index))
	var conflicting_suffix := ""
	for action in BUTTON_ACTIONS:
		var other_suffix := String(action["suffix"])
		if other_suffix != suffix and int(buttons.get(other_suffix, -1)) == button_index:
			conflicting_suffix = other_suffix
			break
	buttons[suffix] = button_index
	if conflicting_suffix != "":
		buttons[conflicting_suffix] = previous_button
	player["buttons"] = buttons
	profile["players"][String(player_index)] = player
	apply_profile()
	_save_profile()
	return true

func set_deadzone(player_index: int, value: float) -> bool:
	if player_index < 1 or player_index > 2:
		return false
	var player := _player_profile(player_index)
	player["deadzone"] = clampf(value, MIN_DEADZONE, MAX_DEADZONE)
	profile["players"][String(player_index)] = player
	apply_profile()
	_save_profile()
	return true

func _set_joy_button_binding(action_id: StringName, button_index: int, device: int, deadzone: float) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, deadzone)
	for existing in InputMap.action_get_events(action_id).duplicate():
		if existing is InputEventJoypadButton:
			InputMap.action_erase_event(action_id, existing)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	InputMap.action_add_event(action_id, event)
	InputMap.action_set_deadzone(action_id, deadzone)

func _register_runtime_inputs() -> void:
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
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_START
		joy_event.device = -1
		InputMap.action_add_event(&"gamepad_lab_toggle", joy_event)

func _create_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 120
	add_child(_canvas)

	_panel = ColorRect.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.color = Color(0.01, 0.018, 0.032, 0.94)
	_panel.visible = false
	_canvas.add_child(_panel)

	var card := ColorRect.new()
	card.anchor_left = 0.14
	card.anchor_top = 0.08
	card.anchor_right = 0.86
	card.anchor_bottom = 0.92
	card.color = Color(0.035, 0.055, 0.085, 0.98)
	_panel.add_child(card)

	_title_label = Label.new()
	_title_label.anchor_left = 0.04
	_title_label.anchor_top = 0.03
	_title_label.anchor_right = 0.96
	_title_label.anchor_bottom = 0.14
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 25)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
	card.add_child(_title_label)

	_body_label = Label.new()
	_body_label.anchor_left = 0.05
	_body_label.anchor_top = 0.15
	_body_label.anchor_right = 0.95
	_body_label.anchor_bottom = 0.80
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	card.add_child(_body_label)

	_footer_label = Label.new()
	_footer_label.anchor_left = 0.04
	_footer_label.anchor_top = 0.81
	_footer_label.anchor_right = 0.96
	_footer_label.anchor_bottom = 0.97
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_label.add_theme_font_size_override("font_size", 13)
	_footer_label.add_theme_color_override("font_color", Color(0.60, 0.78, 0.92))
	card.add_child(_footer_label)

	_practice_panel = ColorRect.new()
	_practice_panel.anchor_left = 0.23
	_practice_panel.anchor_top = 0.03
	_practice_panel.anchor_right = 0.77
	_practice_panel.anchor_bottom = 0.22
	_practice_panel.color = Color(0.025, 0.045, 0.072, 0.94)
	_practice_panel.visible = false
	_canvas.add_child(_practice_panel)

	_practice_title = Label.new()
	_practice_title.anchor_left = 0.04
	_practice_title.anchor_top = 0.05
	_practice_title.anchor_right = 0.96
	_practice_title.anchor_bottom = 0.36
	_practice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_title.add_theme_font_size_override("font_size", 20)
	_practice_title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
	_practice_panel.add_child(_practice_title)

	_practice_body = Label.new()
	_practice_body.anchor_left = 0.05
	_practice_body.anchor_top = 0.36
	_practice_body.anchor_right = 0.95
	_practice_body.anchor_bottom = 0.74
	_practice_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_practice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_practice_body.add_theme_font_size_override("font_size", 14)
	_practice_body.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_practice_panel.add_child(_practice_body)

	_practice_footer = Label.new()
	_practice_footer.anchor_left = 0.05
	_practice_footer.anchor_top = 0.75
	_practice_footer.anchor_right = 0.95
	_practice_footer.anchor_bottom = 0.96
	_practice_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_footer.add_theme_font_size_override("font_size", 12)
	_practice_footer.add_theme_color_override("font_color", Color(0.55, 0.78, 0.95))
	_practice_panel.add_child(_practice_footer)

	_update_panel()

func _update_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var player := _player_profile(_selected_player)
	var device := int(player.get("device", _selected_player - 1))
	var deadzone := float(player.get("deadzone", DEFAULT_DEADZONE))
	var drift := _current_stick_drift(device)
	var device_name := Input.get_joy_name(device) if Input.is_joy_known(device) else "não detectado"
	_title_label.text = "LABORATÓRIO DE GAMEPAD • JOGADOR %d" % _selected_player
	var lines: Array[String] = []
	lines.append("Dispositivo %d: %s" % [device, device_name])
	lines.append("Zona morta: %.2f • desvio atual: %.3f" % [deadzone, drift])
	lines.append("")
	var buttons: Dictionary = player.get("buttons", {})
	for index in range(BUTTON_ACTIONS.size()):
		var action: Dictionary = BUTTON_ACTIONS[index]
		var marker := "▶" if index == _selected_action_index else " "
		var suffix := String(action["suffix"])
		var button_index := int(buttons.get(suffix, action["default"]))
		lines.append("%s %-16s  %s" % [marker, String(action["label"]), _button_label(button_index)])
	if _capturing:
		lines.append("")
		lines.append("PRESSIONE AGORA O BOTÃO DESEJADO NO CONTROLE.")
	_body_label.text = "\n".join(lines)
	var completed := "concluído" if bool(profile.get("real_training_completed", false)) else "pendente"
	_footer_label.text = "1/2 jogador • ↑↓ ação • Enter remapear • ←→ zona morta • D calibrar • P treino real • R restaurar • Esc fechar\nTreino real: %s%s" % [completed, "\n%s" % _feedback if _feedback != "" else ""]

func _begin_capture() -> void:
	_capturing = true
	_capture_armed_at = Time.get_ticks_msec() + 180
	_feedback = "Aguardando botão do gamepad. Esc cancela."
	_update_panel()

func _handle_capture_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_capturing = false
		_feedback = "Remapeamento cancelado."
		_update_panel()
		get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() < _capture_armed_at:
		return
	if event is not InputEventJoypadButton:
		return
	var joy_event := event as InputEventJoypadButton
	if not joy_event.pressed or joy_event.button_index in [JOY_BUTTON_GUIDE, JOY_BUTTON_START]:
		return
	var action: Dictionary = BUTTON_ACTIONS[_selected_action_index]
	var suffix := String(action["suffix"])
	set_button_binding(_selected_player, suffix, joy_event.button_index, joy_event.device)
	_capturing = false
	_feedback = "%s passou a usar %s no dispositivo %d." % [String(action["label"]), _button_label(joy_event.button_index), joy_event.device]
	_update_panel()
	get_viewport().set_input_as_handled()

func _adjust_deadzone(delta: float) -> void:
	var player := _player_profile(_selected_player)
	set_deadzone(_selected_player, float(player.get("deadzone", DEFAULT_DEADZONE)) + delta)
	_feedback = "Zona morta ajustada para %.2f." % float(_player_profile(_selected_player).get("deadzone", DEFAULT_DEADZONE))

func _auto_calibrate_deadzone() -> void:
	var player := _player_profile(_selected_player)
	var device := int(player.get("device", _selected_player - 1))
	var drift := _current_stick_drift(device)
	var suggested := clampf(drift + 0.08, MIN_DEADZONE, MAX_DEADZONE)
	set_deadzone(_selected_player, suggested)
	_feedback = "Calibração automática: desvio %.3f, zona morta %.2f." % [drift, suggested]

func _current_stick_drift(device: int) -> float:
	if device < 0 or not Input.is_joy_known(device):
		return 0.0
	return maxf(
		absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)),
		absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	)

func start_real_practice() -> bool:
	if _practice_active:
		return true
	_practice_scene = get_tree().current_scene
	if not is_instance_valid(_practice_scene):
		_feedback = "Cena principal indisponível."
		_update_panel()
		return false

	_prepare_practice_scene()
	await get_tree().process_frame
	await get_tree().physics_frame
	_player_one = _practice_scene.get("player_one") as FighterController
	_player_two = _practice_scene.get("player_two") as FighterController
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		_feedback = "Não foi possível preparar os dois lutadores."
		_update_panel()
		return false

	_practice_active = true
	_panel.visible = false
	_practice_panel.visible = true
	_disable_player_two_inputs()
	_connect_practice_fighter(_player_one)
	_connect_practice_fighter(_player_two)
	_set_practice_stage(0)
	return true

func _prepare_practice_scene() -> void:
	var player_one_value = _practice_scene.get("player_one")
	var player_two_value = _practice_scene.get("player_two")
	if not is_instance_valid(player_one_value) or not is_instance_valid(player_two_value):
		var preparation = _practice_scene.get("preparation_runtime")
		if is_instance_valid(preparation) and preparation.has_method("close"):
			preparation.call("close")
		if _practice_scene.has_method("_cleanup_temporary_loot"):
			_practice_scene.call("_cleanup_temporary_loot")
		var arena_value = _practice_scene.get("arena")
		if is_instance_valid(arena_value) and arena_value.has_method("reset_battle_flow"):
			arena_value.call("reset_battle_flow")
		if _practice_scene.has_method("_spawn_fighters"):
			_practice_scene.call("_spawn_fighters")
		_practice_scene.set("_state", 2)
	var center = _practice_scene.get("center_label")
	var controls = _practice_scene.get("controls_label")
	if is_instance_valid(center):
		center.text = "DOJO DE RESPOSTA REAL"
	if is_instance_valid(controls):
		controls.text = "Treino validado pelo combate: acerte, defenda e esquive. Esc encerra."

func _connect_practice_fighter(fighter: FighterController) -> void:
	var instance_id := fighter.get_instance_id()
	if _connected_fighter_ids.has(instance_id):
		return
	_connected_fighter_ids[instance_id] = true
	if fighter.has_signal("technique_experienced"):
		fighter.connect("technique_experienced", Callable(self, "_on_technique_experienced"))

func _set_practice_stage(stage: int) -> void:
	_practice_stage = stage
	_practice_attack_timer = 0.55
	_reset_practice_positions()
	match stage:
		0:
			_practice_title.text = "1/3 • ACERTO CONFIRMADO"
			_practice_body.text = "Acerte o lutador-alvo com uma técnica principal. O avanço só ocorre quando o hurtbox registrar dano real."
			_practice_footer.text = "Use Golpe. O alvo não defenderá."
		1:
			_practice_title.text = "2/3 • DEFESA CONFIRMADA"
			_practice_body.text = "Segure Guarda diante do ataque do alvo. Bloqueio ou aparo real conclui esta etapa."
			_practice_footer.text = "O alvo atacará em intervalos controlados."
		2:
			_practice_title.text = "3/3 • ESQUIVA CONFIRMADA"
			_practice_body.text = "Use Esquiva durante o ataque do alvo. A etapa exige o resultado evaded emitido pelo combate."
			_practice_footer.text = "Leia o início do golpe e saia da trajetória."

func _update_practice(delta: float) -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		stop_real_practice("Lutadores indisponíveis.")
		return
	if _practice_stage < 1:
		return
	_practice_attack_timer -= delta
	if _practice_attack_timer > 0.0:
		return
	_practice_attack_timer = PRACTICE_ATTACK_INTERVAL
	_prepare_scripted_attack()

func _prepare_scripted_attack() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return
	if int(_player_two.get("_attack_phase")) != FighterController.AttackPhase.NONE:
		return
	_player_one.facing = 1.0
	_player_two.facing = -1.0
	_player_two.global_position = Vector2(_player_one.global_position.x + 50.0, _player_one.global_position.y)
	_player_two.velocity = Vector2.ZERO
	_player_two.stamina = 100.0
	_player_two.call("_begin_technique", PRACTICE_TECHNIQUE)

func _reset_practice_positions() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return
	var arena_value = _practice_scene.get("arena")
	var base_position := _player_one.global_position
	if is_instance_valid(arena_value) and arena_value.has_method("respawn_point"):
		base_position = arena_value.call("respawn_point", 1)
	_player_one.reset_fighter(base_position)
	_player_two.reset_fighter(base_position + Vector2(72.0, 0.0))
	_player_one.facing = 1.0
	_player_two.facing = -1.0

func _on_technique_experienced(
	defender: FighterController,
	attacker: FighterController,
	_technique_id: StringName,
	outcome_id: StringName
) -> void:
	if not _practice_active:
		return
	match _practice_stage:
		0:
			if defender == _player_two and attacker == _player_one and outcome_id == &"hit":
				_set_practice_stage(1)
		1:
			if defender == _player_one and attacker == _player_two and outcome_id in [&"blocked", &"parried"]:
				_set_practice_stage(2)
		2:
			if defender == _player_one and attacker == _player_two and outcome_id == &"evaded":
				_complete_real_practice()

func _complete_real_practice() -> void:
	profile["real_training_completed"] = true
	_save_profile()
	_practice_title.text = "TREINO REAL CONCLUÍDO"
	_practice_body.text = "O Godot confirmou acerto, defesa e esquiva através dos resultados reais do sistema de combate."
	_practice_footer.text = "Retornando à batalha com os controles restaurados."
	await get_tree().create_timer(1.8, true, false, true).timeout
	stop_real_practice("Treino real concluído.")

func stop_real_practice(message: String = "") -> void:
	if not _practice_active:
		return
	_practice_active = false
	_practice_panel.visible = false
	_restore_player_two_inputs()
	if is_instance_valid(_player_one) and is_instance_valid(_player_two):
		_reset_practice_positions()
	if is_instance_valid(_practice_scene):
		var arena_value = _practice_scene.get("arena")
		if is_instance_valid(arena_value) and arena_value.has_method("start_battle_flow"):
			arena_value.call("start_battle_flow")
		var center = _practice_scene.get("center_label")
		var controls = _practice_scene.get("controls_label")
		if is_instance_valid(center):
			center.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
		if is_instance_valid(controls):
			controls.text = "F10 abre o laboratório de gamepad e treino real."
	_feedback = message
	apply_profile()

func _disable_player_two_inputs() -> void:
	_saved_player_two_events.clear()
	for suffix in ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "echo", "block", "element", "swap"]:
		var action_id := _player_action(2, suffix)
		if not InputMap.has_action(action_id):
			continue
		var saved: Array[InputEvent] = []
		for event in InputMap.action_get_events(action_id):
			saved.append(event.duplicate())
		_saved_player_two_events[String(action_id)] = saved
		InputMap.action_erase_events(action_id)

func _restore_player_two_inputs() -> void:
	for action_key in _saved_player_two_events.keys():
		var action_id := StringName(action_key)
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id, DEFAULT_DEADZONE)
		InputMap.action_erase_events(action_id)
		for event in _saved_player_two_events[action_key]:
			InputMap.action_add_event(action_id, event)
	_saved_player_two_events.clear()

func _player_profile(player_index: int) -> Dictionary:
	var players: Dictionary = profile.get("players", {})
	var value = players.get(String(player_index), {})
	return value if value is Dictionary else {}

func _player_action(player_index: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _is_button_suffix(suffix: String) -> bool:
	for action in BUTTON_ACTIONS:
		if String(action["suffix"]) == suffix:
			return true
	return false

func _button_label(button_index: int) -> String:
	return String(BUTTON_LABELS.get(button_index, "Botão %d" % button_index))

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_feedback = "Controle %d %s." % [device, "conectado" if connected else "desconectado"]
	_update_panel()

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
