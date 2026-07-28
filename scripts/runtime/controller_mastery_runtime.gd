class_name ControllerMasteryRuntime
extends Node

const PROFILE_PATH := "user://controller-mastery-profiles.json"
const BRIDGE_VERSION := 1
const LINK_WINDOW_MS := 720
const QUEUE_LIFETIME_MS := 420
const PARRY_WINDOW_SECONDS := 0.09
const ACTION_SUFFIXES := ["jump", "dodge", "attack", "push", "grab", "block", "element", "echo", "swap"]
const CANCEL_SUFFIXES := ["dodge", "attack", "echo", "swap"]
const DEFAULT_POINTS := [0.0, 0.16, 0.44, 0.76, 1.0]

var profile: Dictionary = {}
var metrics: Dictionary = {}
var _callbacks: Array = []
var _window: JavaScriptObject
var _fighters: Dictionary = {}
var _connected_fighters: Dictionary = {}
var _queued_cancels: Dictionary = {}
var _last_technique_at: Dictionary = {}
var _current_chain_hits: Dictionary = {}
var _refresh_timer := 0.0
var _alias_timer := 0.0
var _discover_timer := 0.0
var _web_timer := 0.0
var _dojo_active := false
var _dojo_stage := 0
var _canvas: CanvasLayer
var _overlay: ColorRect
var _overlay_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _default_profile()
	metrics = _default_metrics()
	_load_profile()
	_create_overlay()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_register_web_bridge()
	call_deferred("_discover_scene")

func _physics_process(delta: float) -> void:
	_discover_timer -= delta
	_alias_timer -= delta
	_refresh_timer -= delta
	_web_timer -= delta
	if _discover_timer <= 0.0:
		_discover_timer = 0.45
		_discover_scene()
	if _alias_timer <= 0.0:
		_alias_timer = 0.55
		_sync_connected_profiles()
		_apply_trigger_aliases()
	for player_index in [1, 2]:
		_apply_custom_stick(player_index)
		_process_cancel_queue(player_index)
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.05
		_refresh_overlay()
	if _web_timer <= 0.0:
		_web_timer = 0.35
		_sync_web_state()

func _exit_tree() -> void:
	_release_all_curve_actions()

func _default_profile() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"players": {
			"1": {"device": 0, "guid": ""},
			"2": {"device": 1, "guid": ""}
		},
		"devices": {},
		"show_windows": true,
		"combo_dojo_completed": false,
		"best_metrics": {}
	}

func _default_metrics() -> Dictionary:
	return {
		"attempts": 0,
		"hits": 0,
		"max_chain": 0,
		"current_chain": 0,
		"parries": 0,
		"cancel_attempts": 0,
		"cancel_success": 0,
		"link_gaps_ms": [],
		"cancel_latencies_ms": [],
		"last_event": ""
	}

func _default_device_profile(device: int) -> Dictionary:
	var name := Input.get_joy_name(device) if device >= 0 and Input.is_joy_known(device) else "Controle"
	return {
		"name": name,
		"curve_points": DEFAULT_POINTS.duplicate(),
		"left_trigger_action": "element",
		"right_trigger_action": "attack",
		"trigger_threshold": 0.55,
		"cancel_threshold": 0.68,
		"cancel_assist": true
	}

func _sanitize_profile(value: Variant) -> Dictionary:
	var clean := _default_profile()
	if not value is Dictionary:
		return clean
	var source: Dictionary = value
	clean["show_windows"] = bool(source.get("show_windows", true))
	clean["combo_dojo_completed"] = bool(source.get("combo_dojo_completed", false))
	var best = source.get("best_metrics", {})
	clean["best_metrics"] = best.duplicate(true) if best is Dictionary else {}
	var source_players: Dictionary = source.get("players", {})
	for player_index in [1, 2]:
		var key := str(player_index)
		var entry: Dictionary = source_players.get(key, {})
		clean["players"][key] = {
			"device": maxi(-1, int(entry.get("device", player_index - 1))),
			"guid": String(entry.get("guid", ""))
		}
	var source_devices: Dictionary = source.get("devices", {})
	for guid in source_devices.keys():
		var device_source = source_devices[guid]
		if device_source is Dictionary:
			clean["devices"][String(guid)] = _sanitize_device_profile(device_source as Dictionary)
	return clean

func _sanitize_device_profile(value: Dictionary) -> Dictionary:
	var points := _sanitize_points(value.get("curve_points", DEFAULT_POINTS))
	var left_action := String(value.get("left_trigger_action", "element"))
	var right_action := String(value.get("right_trigger_action", "attack"))
	if left_action not in ACTION_SUFFIXES:
		left_action = "element"
	if right_action not in ACTION_SUFFIXES:
		right_action = "attack"
	return {
		"name": String(value.get("name", "Controle")),
		"curve_points": points,
		"left_trigger_action": left_action,
		"right_trigger_action": right_action,
		"trigger_threshold": clampf(float(value.get("trigger_threshold", 0.55)), 0.20, 0.92),
		"cancel_threshold": clampf(float(value.get("cancel_threshold", 0.68)), 0.35, 0.95),
		"cancel_assist": bool(value.get("cancel_assist", true))
	}

func _sanitize_points(value: Variant) -> Array:
	var source: Array = value if value is Array else DEFAULT_POINTS
	var result := [0.0, 0.16, 0.44, 0.76, 1.0]
	for index in range(mini(source.size(), 5)):
		result[index] = clampf(float(source[index]), 0.0, 1.0)
	result[0] = 0.0
	result[4] = 1.0
	for index in range(1, 5):
		result[index] = maxf(result[index], result[index - 1])
	return result

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

func _device_guid(device: int) -> String:
	if device < 0 or not Input.is_joy_known(device):
		return ""
	var guid := Input.get_joy_guid(device)
	if guid == "":
		guid = "name:%s" % Input.get_joy_name(device)
	return guid

func _player_entry(player_index: int) -> Dictionary:
	var players: Dictionary = profile.get("players", {})
	var value = players.get(str(player_index), {})
	return value if value is Dictionary else {}

func _player_device(player_index: int) -> int:
	return int(_player_entry(player_index).get("device", player_index - 1))

func _player_guid(player_index: int) -> String:
	var entry := _player_entry(player_index)
	var guid := String(entry.get("guid", ""))
	if guid == "":
		guid = _device_guid(int(entry.get("device", player_index - 1)))
	return guid

func _device_profile_for_player(player_index: int) -> Dictionary:
	var guid := _player_guid(player_index)
	if guid == "":
		return _default_device_profile(_player_device(player_index))
	var devices: Dictionary = profile.get("devices", {})
	if not devices.has(guid):
		devices[guid] = _default_device_profile(_player_device(player_index))
		profile["devices"] = devices
	return devices[guid]

func assign_device(player_index: int, device: int) -> bool:
	if player_index < 1 or player_index > 2 or device < -1:
		return false
	var entry := _player_entry(player_index)
	entry["device"] = device
	entry["guid"] = _device_guid(device)
	profile["players"][str(player_index)] = entry
	if entry["guid"] != "" and not profile["devices"].has(entry["guid"]):
		profile["devices"][entry["guid"]] = _default_device_profile(device)
	var base := _base_runtime()
	if is_instance_valid(base) and base.has_method("set_player_device"):
		base.set_player_device(player_index, device)
	_save_profile()
	_apply_trigger_aliases()
	return true

func set_curve_points(player_index: int, points: Variant) -> bool:
	if player_index < 1 or player_index > 2:
		return false
	var guid := _ensure_player_profile(player_index)
	if guid == "":
		return false
	var device_profile: Dictionary = profile["devices"][guid]
	device_profile["curve_points"] = _sanitize_points(points)
	profile["devices"][guid] = device_profile
	_save_profile()
	return true

func set_trigger_actions(player_index: int, left_action: String, right_action: String, threshold: float) -> bool:
	if player_index < 1 or player_index > 2 or left_action not in ACTION_SUFFIXES or right_action not in ACTION_SUFFIXES:
		return false
	var guid := _ensure_player_profile(player_index)
	if guid == "":
		return false
	var device_profile: Dictionary = profile["devices"][guid]
	device_profile["left_trigger_action"] = left_action
	device_profile["right_trigger_action"] = right_action
	device_profile["trigger_threshold"] = clampf(threshold, 0.20, 0.92)
	profile["devices"][guid] = device_profile
	_save_profile()
	_apply_trigger_aliases()
	return true

func set_cancel_options(player_index: int, threshold: float, enabled: bool) -> bool:
	if player_index < 1 or player_index > 2:
		return false
	var guid := _ensure_player_profile(player_index)
	if guid == "":
		return false
	var device_profile: Dictionary = profile["devices"][guid]
	device_profile["cancel_threshold"] = clampf(threshold, 0.35, 0.95)
	device_profile["cancel_assist"] = enabled
	profile["devices"][guid] = device_profile
	_save_profile()
	return true

func set_show_windows(enabled: bool) -> void:
	profile["show_windows"] = enabled
	_save_profile()

func reset_device_profile(player_index: int) -> bool:
	var guid := _ensure_player_profile(player_index)
	if guid == "":
		return false
	profile["devices"][guid] = _default_device_profile(_player_device(player_index))
	_save_profile()
	_apply_trigger_aliases()
	return true

func _ensure_player_profile(player_index: int) -> String:
	var guid := _player_guid(player_index)
	if guid == "":
		var device := _player_device(player_index)
		guid = "slot:%d" % player_index if device < 0 else _device_guid(device)
		var entry := _player_entry(player_index)
		entry["guid"] = guid
		profile["players"][str(player_index)] = entry
	if not profile["devices"].has(guid):
		profile["devices"][guid] = _default_device_profile(_player_device(player_index))
	return guid

func _sync_connected_profiles() -> void:
	var connected := Input.get_connected_joypads()
	for device in connected:
		var guid := _device_guid(device)
		if guid != "" and not profile["devices"].has(guid):
			profile["devices"][guid] = _default_device_profile(device)
	for player_index in [1, 2]:
		var entry := _player_entry(player_index)
		var stored_guid := String(entry.get("guid", ""))
		if stored_guid == "":
			var current_device := int(entry.get("device", player_index - 1))
			if current_device in connected:
				assign_device(player_index, current_device)
			continue
		for device in connected:
			if _device_guid(device) == stored_guid and int(entry.get("device", -1)) != device:
				entry["device"] = device
				profile["players"][str(player_index)] = entry
				var base := _base_runtime()
				if is_instance_valid(base) and base.has_method("set_player_device"):
					base.set_player_device(player_index, device)
	_save_profile()

func evaluate_curve(raw: float, deadzone: float, points: Array) -> float:
	var magnitude := absf(raw)
	if magnitude <= deadzone:
		return 0.0
	var normalized := clampf((magnitude - deadzone) / maxf(0.001, 1.0 - deadzone), 0.0, 1.0)
	var scaled := normalized * 4.0
	var segment := mini(3, int(floor(scaled)))
	var local_t := scaled - float(segment)
	var output := lerpf(float(points[segment]), float(points[segment + 1]), local_t)
	return signf(raw) * output

func _apply_custom_stick(player_index: int) -> void:
	var device := _player_device(player_index)
	if device < 0 or not Input.is_joy_known(device):
		_release_player_curve_actions(player_index)
		return
	var device_profile := _device_profile_for_player(player_index)
	var points: Array = device_profile.get("curve_points", DEFAULT_POINTS)
	var deadzone := _player_deadzone(player_index)
	var horizontal := evaluate_curve(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), deadzone, points)
	var vertical := evaluate_curve(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), deadzone, points)
	_apply_action_strength(_player_action(player_index, "left"), maxf(0.0, -horizontal))
	_apply_action_strength(_player_action(player_index, "right"), maxf(0.0, horizontal))
	_apply_action_strength(_player_action(player_index, "down"), maxf(0.0, vertical))

func _player_deadzone(player_index: int) -> float:
	var base := _base_runtime()
	if is_instance_valid(base) and base.has_method("current_profile"):
		var base_profile: Dictionary = base.current_profile()
		var player: Dictionary = base_profile.get("players", {}).get(str(player_index), {})
		return clampf(float(player.get("deadzone", 0.25)), 0.0, 0.95)
	return 0.25

func _apply_action_strength(action_id: StringName, strength: float) -> void:
	if not InputMap.has_action(action_id):
		return
	if strength > 0.001:
		Input.action_press(action_id, strength)
	else:
		Input.action_release(action_id)

func _release_player_curve_actions(player_index: int) -> void:
	for suffix in ["left", "right", "down"]:
		var action_id := _player_action(player_index, suffix)
		if InputMap.has_action(action_id):
			Input.action_release(action_id)

func _release_all_curve_actions() -> void:
	for player_index in [1, 2]:
		_release_player_curve_actions(player_index)

func _apply_trigger_aliases() -> void:
	for player_index in [1, 2]:
		var device := _player_device(player_index)
		var device_profile := _device_profile_for_player(player_index)
		for suffix in ACTION_SUFFIXES:
			var action_id := _player_action(player_index, suffix)
			if not InputMap.has_action(action_id):
				continue
			for event in InputMap.action_get_events(action_id).duplicate():
				if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
					InputMap.action_erase_event(action_id, event)
		_add_trigger_event(player_index, String(device_profile.get("left_trigger_action", "element")), JOY_AXIS_TRIGGER_LEFT, device, float(device_profile.get("trigger_threshold", 0.55)))
		_add_trigger_event(player_index, String(device_profile.get("right_trigger_action", "attack")), JOY_AXIS_TRIGGER_RIGHT, device, float(device_profile.get("trigger_threshold", 0.55)))

func _add_trigger_event(player_index: int, suffix: String, axis: JoyAxis, device: int, threshold: float) -> void:
	var action_id := _player_action(player_index, suffix)
	if not InputMap.has_action(action_id):
		return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = 1.0
	event.device = device
	InputMap.action_add_event(action_id, event)
	InputMap.action_set_deadzone(action_id, threshold)

func _process_cancel_queue(player_index: int) -> void:
	var fighter = _fighters.get(player_index)
	if not is_instance_valid(fighter):
		return
	var device_profile := _device_profile_for_player(player_index)
	var phase := int(fighter.get("_attack_phase"))
	var now := Time.get_ticks_msec()
	if phase == FighterController.AttackPhase.RECOVERY and bool(device_profile.get("cancel_assist", true)):
		var progress := _recovery_progress(fighter)
		if progress >= float(device_profile.get("cancel_threshold", 0.68)) and not _queued_cancels.has(player_index):
			for suffix in CANCEL_SUFFIXES:
				var action_id := _player_action(player_index, suffix)
				if InputMap.has_action(action_id) and Input.is_action_just_pressed(action_id):
					_queued_cancels[player_index] = {"suffix": suffix, "queued_at": now, "deadline": now + QUEUE_LIFETIME_MS}
					metrics["cancel_attempts"] = int(metrics.get("cancel_attempts", 0)) + 1
					metrics["last_event"] = "Cancelamento em fila: %s" % suffix
					break
	if not _queued_cancels.has(player_index):
		return
	var queued: Dictionary = _queued_cancels[player_index]
	if now > int(queued.get("deadline", 0)):
		_queued_cancels.erase(player_index)
		return
	if phase == FighterController.AttackPhase.NONE:
		_execute_queued_cancel(player_index, fighter, queued)

func _execute_queued_cancel(player_index: int, fighter: FighterController, queued: Dictionary) -> void:
	var suffix := String(queued.get("suffix", ""))
	var before_phase := int(fighter.get("_attack_phase"))
	var before_weapon := String(fighter.get("equipped_weapon_id"))
	match suffix:
		"dodge":
			fighter.call("_try_dodge")
		"attack":
			fighter.call("_try_contextual_attack")
		"echo":
			fighter.call("_try_borrowed_technique")
		"swap":
			if fighter.has_method("_try_swap_weapon"):
				fighter.call("_try_swap_weapon")
	var success := int(fighter.get("_attack_phase")) != before_phase or float(fighter.get("_dodge_timer")) > 0.0 or String(fighter.get("equipped_weapon_id")) != before_weapon
	if success:
		var latency := Time.get_ticks_msec() - int(queued.get("queued_at", Time.get_ticks_msec()))
		metrics["cancel_success"] = int(metrics.get("cancel_success", 0)) + 1
		metrics["cancel_latencies_ms"].append(latency)
		metrics["last_event"] = "Cancelamento confirmado em %d ms" % latency
		if _dojo_active and _dojo_stage == 3:
			_complete_dojo()
	_queued_cancels.erase(player_index)

func _recovery_progress(fighter: FighterController) -> float:
	if int(fighter.get("_attack_phase")) != FighterController.AttackPhase.RECOVERY:
		return 0.0
	var technique = fighter.get("_current_technique")
	if not is_instance_valid(technique):
		return 0.0
	var total := maxf(0.001, technique.recovery_seconds())
	return clampf(1.0 - float(fighter.get("_attack_phase_timer")) / total, 0.0, 1.0)

func _discover_scene() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	for player_index in [1, 2]:
		var fighter = scene.get("player_one") if player_index == 1 else scene.get("player_two")
		if fighter is FighterController:
			_fighters[player_index] = fighter
			_connect_fighter(fighter)

func _connect_fighter(fighter: FighterController) -> void:
	var id := fighter.get_instance_id()
	if _connected_fighters.has(id):
		return
	_connected_fighters[id] = true
	if fighter.has_signal("technique_started"):
		fighter.connect("technique_started", Callable(self, "_on_technique_started"))
	if fighter.has_signal("technique_experienced"):
		fighter.connect("technique_experienced", Callable(self, "_on_technique_experienced"))
	if fighter.has_signal("parry_performed"):
		fighter.connect("parry_performed", Callable(self, "_on_parry_performed"))

func _on_technique_started(fighter: FighterController, technique_id: StringName) -> void:
	if fighter.player_index != 1:
		return
	var now := Time.get_ticks_msec()
	var last := int(_last_technique_at.get(1, 0))
	var gap := now - last if last > 0 else LINK_WINDOW_MS + 1
	var chain := int(metrics.get("current_chain", 0))
	if gap <= LINK_WINDOW_MS:
		chain += 1
		metrics["link_gaps_ms"].append(gap)
	else:
		chain = 1
		_current_chain_hits[1] = 0
	metrics["current_chain"] = chain
	metrics["max_chain"] = maxi(int(metrics.get("max_chain", 0)), chain)
	metrics["attempts"] = int(metrics.get("attempts", 0)) + 1
	metrics["last_event"] = "%s • elo %d • %d ms" % [String(technique_id), chain, gap]
	_last_technique_at[1] = now
	if _dojo_active and _dojo_stage == 0 and chain >= 3:
		_set_dojo_stage(1)

func _on_technique_experienced(defender: FighterController, attacker: FighterController, _technique_id: StringName, outcome_id: StringName) -> void:
	if not is_instance_valid(attacker) or attacker.player_index != 1:
		return
	if outcome_id == &"hit":
		metrics["hits"] = int(metrics.get("hits", 0)) + 1
		_current_chain_hits[1] = int(_current_chain_hits.get(1, 0)) + 1
		metrics["last_event"] = "Acerto confirmado • cadeia %d" % int(_current_chain_hits[1])
		if _dojo_active and _dojo_stage == 1 and int(_current_chain_hits[1]) >= 2:
			_set_dojo_stage(2)

func _on_parry_performed(fighter: FighterController) -> void:
	if fighter.player_index != 1:
		return
	metrics["parries"] = int(metrics.get("parries", 0)) + 1
	var elapsed_ms := int((PARRY_WINDOW_SECONDS - clampf(float(fighter.get("_parry_timer")), 0.0, PARRY_WINDOW_SECONDS)) * 1000.0)
	metrics["last_event"] = "Aparo confirmado em %d ms" % elapsed_ms
	if _dojo_active and _dojo_stage == 2:
		_set_dojo_stage(3)

func start_combo_dojo() -> bool:
	metrics = _default_metrics()
	_last_technique_at.clear()
	_current_chain_hits.clear()
	_queued_cancels.clear()
	_dojo_active = true
	_set_dojo_stage(0)
	return true

func stop_combo_dojo(message: String = "") -> void:
	_dojo_active = false
	metrics["last_event"] = message

func _set_dojo_stage(stage: int) -> void:
	_dojo_stage = stage
	match stage:
		0:
			metrics["last_event"] = "Dojo 1/4: conecte três técnicas em até 720 ms."
		1:
			metrics["last_event"] = "Dojo 2/4: confirme dois acertos na mesma cadeia."
		2:
			metrics["last_event"] = "Dojo 3/4: realize um aparo dentro da janela real."
		3:
			metrics["last_event"] = "Dojo 4/4: use ataque, esquiva, eco ou arma na janela de cancelamento."

func _complete_dojo() -> void:
	_dojo_active = false
	_dojo_stage = 4
	profile["combo_dojo_completed"] = true
	profile["best_metrics"] = _metric_summary()
	metrics["last_event"] = "Dojo de combos concluído."
	_save_profile()

func _metric_summary() -> Dictionary:
	var attempts := int(metrics.get("attempts", 0))
	var hits := int(metrics.get("hits", 0))
	var gaps: Array = metrics.get("link_gaps_ms", [])
	var cancels: Array = metrics.get("cancel_latencies_ms", [])
	return {
		"attempts": attempts,
		"hits": hits,
		"accuracy": float(hits) / float(maxi(1, attempts)),
		"max_chain": int(metrics.get("max_chain", 0)),
		"parries": int(metrics.get("parries", 0)),
		"cancel_success": int(metrics.get("cancel_success", 0)),
		"average_link_ms": _average(gaps),
		"consistency_ms": _standard_deviation(gaps),
		"average_cancel_ms": _average(cancels)
	}

func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

func _standard_deviation(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var mean := _average(values)
	var total := 0.0
	for value in values:
		var difference := float(value) - mean
		total += difference * difference
	return sqrt(total / float(values.size()))

func _create_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 126
	add_child(_canvas)
	_overlay = ColorRect.new()
	_overlay.anchor_left = 0.26
	_overlay.anchor_top = 0.02
	_overlay.anchor_right = 0.74
	_overlay.anchor_bottom = 0.145
	_overlay.color = Color(0.018, 0.026, 0.046, 0.90)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.add_theme_font_size_override("font_size", 13)
	_overlay_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_overlay.add_child(_overlay_label)

func _refresh_overlay() -> void:
	if not is_instance_valid(_overlay):
		return
	_overlay.visible = bool(profile.get("show_windows", true)) or _dojo_active
	if not _overlay.visible:
		return
	var fighter = _fighters.get(1)
	if not is_instance_valid(fighter):
		_overlay_label.text = "MAESTRIA DE CONTROLE • aguardando lutador P1"
		return
	var parry_ratio := clampf(float(fighter.get("_parry_timer")) / PARRY_WINDOW_SECONDS, 0.0, 1.0)
	var recovery := _recovery_progress(fighter)
	var device_profile := _device_profile_for_player(1)
	var threshold := float(device_profile.get("cancel_threshold", 0.68))
	var phase_names := ["LIVRE", "STARTUP", "ATIVO", "RECUPERAÇÃO"]
	var phase := clampi(int(fighter.get("_attack_phase")), 0, 3)
	var parry_bar := _bar(parry_ratio)
	var cancel_bar := _bar(recovery)
	var cancel_state := "ABERTA" if recovery >= threshold and phase == FighterController.AttackPhase.RECOVERY else "fechada"
	var summary := _metric_summary()
	_overlay_label.text = "APARO %s  %3d%%  •  %s\nCANCEL %s  %3d%% (%s)  •  ELO %d  •  PRECISÃO %d%%  •  %s" % [
		parry_bar,
		int(round(parry_ratio * 100.0)),
		phase_names[phase],
		cancel_bar,
		int(round(recovery * 100.0)),
		cancel_state,
		int(metrics.get("current_chain", 0)),
		int(round(float(summary.get("accuracy", 0.0)) * 100.0)),
		String(metrics.get("last_event", ""))
	]

func _bar(value: float) -> String:
	var filled := clampi(int(round(value * 8.0)), 0, 8)
	return "[" + "■".repeat(filled) + "·".repeat(8 - filled) + "]"

func connected_devices() -> Array:
	var result := []
	for device in Input.get_connected_joypads():
		var guid := _device_guid(device)
		result.append({
			"id": device,
			"guid": guid,
			"name": Input.get_joy_name(device),
			"profile": profile.get("devices", {}).get(guid, _default_device_profile(device))
		})
	return result

func current_state() -> Dictionary:
	var players := {}
	for player_index in [1, 2]:
		players[str(player_index)] = {
			"device": _player_device(player_index),
			"guid": _player_guid(player_index),
			"profile": _device_profile_for_player(player_index)
		}
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"players": players,
		"devices": connected_devices(),
		"show_windows": bool(profile.get("show_windows", true)),
		"dojo": {
			"active": _dojo_active,
			"stage": _dojo_stage,
			"completed": bool(profile.get("combo_dojo_completed", false))
		},
		"metrics": _metric_summary(),
		"raw_metrics": metrics.duplicate(true),
		"best_metrics": profile.get("best_metrics", {})
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"assign_device":
			assign_device(int(request.get("player", 1)), int(request.get("device", -1)))
		&"set_curve":
			set_curve_points(int(request.get("player", 1)), request.get("points", DEFAULT_POINTS))
		&"set_triggers":
			set_trigger_actions(
				int(request.get("player", 1)),
				String(request.get("left_action", "element")),
				String(request.get("right_action", "attack")),
				float(request.get("threshold", 0.55))
			)
		&"set_cancel":
			set_cancel_options(int(request.get("player", 1)), float(request.get("threshold", 0.68)), bool(request.get("enabled", true)))
		&"set_windows":
			set_show_windows(bool(request.get("enabled", true)))
		&"start_dojo":
			start_combo_dojo()
		&"stop_dojo":
			stop_combo_dojo("Dojo encerrado pela interface Web.")
		&"reset_device":
			reset_device_profile(int(request.get("player", 1)))
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
	_window.taijifuControllerMasteryCommand = command_callback
	_window.taijifuControllerMasteryState = state_callback
	_window.taijifuControllerMasteryVersion = BRIDGE_VERSION
	_window.taijifuControllerMasteryReady = true
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
	_window.taijifuControllerMasteryStateJson = JSON.stringify(current_state())
	_window.taijifuControllerMasteryReady = true

func _base_runtime() -> Node:
	return get_tree().root.get_node_or_null("TaijifuGamepadTraining")

func _player_action(player_index: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_sync_connected_profiles()
	_apply_trigger_aliases()

func curve_value_for_test(raw: float, deadzone: float, points: Array) -> float:
	return evaluate_curve(raw, deadzone, _sanitize_points(points))

func record_combo_event_for_test(event_id: StringName, value: int = 0) -> int:
	match event_id:
		&"chain":
			metrics["current_chain"] = value
			metrics["max_chain"] = maxi(int(metrics.get("max_chain", 0)), value)
			if _dojo_stage == 0 and value >= 3:
				_set_dojo_stage(1)
		&"hits":
			_current_chain_hits[1] = value
			if _dojo_stage == 1 and value >= 2:
				_set_dojo_stage(2)
		&"parry":
			if _dojo_stage == 2:
				_set_dojo_stage(3)
		&"cancel":
			if _dojo_stage == 3:
				_complete_dojo()
	return _dojo_stage
