class_name WebPlatformBridgeRuntime
extends Node

const BRIDGE_VERSION := 1
const DEFAULT_CODES := {
	"p1_left": "KeyA",
	"p1_right": "KeyD",
	"p1_down": "KeyS",
	"p1_jump": "KeyW",
	"p1_dodge": "KeyQ",
	"p1_attack": "KeyF",
	"p1_push": "KeyG",
	"p1_grab": "KeyE",
	"p1_echo": "KeyH",
	"p1_block": "KeyR",
	"p1_element": "KeyC",
	"p1_swap": "KeyT",
	"p2_left": "ArrowLeft",
	"p2_right": "ArrowRight",
	"p2_down": "ArrowDown",
	"p2_jump": "ArrowUp",
	"p2_dodge": "Numpad0",
	"p2_attack": "Numpad1",
	"p2_push": "Numpad2",
	"p2_block": "Numpad3",
	"p2_grab": "Numpad4",
	"p2_echo": "Numpad5",
	"p2_element": "Numpad6",
	"p2_swap": "Numpad7"
}

const CODE_TO_KEY := {
	"KeyA": KEY_A, "KeyB": KEY_B, "KeyC": KEY_C, "KeyD": KEY_D,
	"KeyE": KEY_E, "KeyF": KEY_F, "KeyG": KEY_G, "KeyH": KEY_H,
	"KeyI": KEY_I, "KeyJ": KEY_J, "KeyK": KEY_K, "KeyL": KEY_L,
	"KeyM": KEY_M, "KeyN": KEY_N, "KeyO": KEY_O, "KeyP": KEY_P,
	"KeyQ": KEY_Q, "KeyR": KEY_R, "KeyS": KEY_S, "KeyT": KEY_T,
	"KeyU": KEY_U, "KeyV": KEY_V, "KeyW": KEY_W, "KeyX": KEY_X,
	"KeyY": KEY_Y, "KeyZ": KEY_Z,
	"Digit0": KEY_0, "Digit1": KEY_1, "Digit2": KEY_2, "Digit3": KEY_3,
	"Digit4": KEY_4, "Digit5": KEY_5, "Digit6": KEY_6, "Digit7": KEY_7,
	"Digit8": KEY_8, "Digit9": KEY_9,
	"ArrowLeft": KEY_LEFT, "ArrowRight": KEY_RIGHT,
	"ArrowUp": KEY_UP, "ArrowDown": KEY_DOWN,
	"Numpad0": KEY_KP_0, "Numpad1": KEY_KP_1, "Numpad2": KEY_KP_2,
	"Numpad3": KEY_KP_3, "Numpad4": KEY_KP_4, "Numpad5": KEY_KP_5,
	"Numpad6": KEY_KP_6, "Numpad7": KEY_KP_7, "Numpad8": KEY_KP_8,
	"Numpad9": KEY_KP_9,
	"Space": KEY_SPACE, "Enter": KEY_ENTER, "Tab": KEY_TAB,
	"ShiftLeft": KEY_SHIFT, "ShiftRight": KEY_SHIFT,
	"ControlLeft": KEY_CTRL, "ControlRight": KEY_CTRL,
	"AltLeft": KEY_ALT, "AltRight": KEY_ALT
}

var _callbacks: Array = []
var _window: JavaScriptObject
var _paused_from_web := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_register_web_bridge")

func _exit_tree() -> void:
	if _paused_from_web and is_inside_tree():
		get_tree().paused = false

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var pause_callback := JavaScriptBridge.create_callback(_web_set_paused)
	var apply_callback := JavaScriptBridge.create_callback(_web_apply_bindings)
	var reset_callback := JavaScriptBridge.create_callback(_web_reset_bindings)
	var state_callback := JavaScriptBridge.create_callback(_web_get_state)
	_callbacks = [pause_callback, apply_callback, reset_callback, state_callback]
	_window.taijifuGodotSetPaused = pause_callback
	_window.taijifuGodotApplyBindings = apply_callback
	_window.taijifuGodotResetBindings = reset_callback
	_window.taijifuGodotGetState = state_callback
	_window.taijifuGodotBridgeVersion = BRIDGE_VERSION
	_window.taijifuGodotPaused = get_tree().paused
	_window.taijifuGodotBindingsJson = JSON.stringify(current_keyboard_bindings())
	_window.taijifuGodotBridgeReady = true

func set_paused_from_web(paused: bool) -> bool:
	if not is_inside_tree():
		return false
	_paused_from_web = paused
	get_tree().paused = paused
	_sync_web_state()
	return get_tree().paused == paused

func apply_keyboard_bindings(bindings: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for action_key in bindings.keys():
		var action_id := String(action_key)
		var code := String(bindings[action_key])
		if set_keyboard_binding(StringName(action_id), code):
			applied[action_id] = code
	_sync_web_state()
	return applied

func set_keyboard_binding(action_id: StringName, code: String) -> bool:
	var action_key := String(action_id)
	if not DEFAULT_CODES.has(action_key) or not CODE_TO_KEY.has(code):
		return false
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id).duplicate():
		if existing is InputEventKey:
			InputMap.action_erase_event(action_id, existing)
	var event := InputEventKey.new()
	event.physical_keycode = int(CODE_TO_KEY[code])
	InputMap.action_add_event(action_id, event)
	return true

func reset_keyboard_bindings() -> Dictionary:
	apply_keyboard_bindings(DEFAULT_CODES)
	return current_keyboard_bindings()

func current_keyboard_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action_key in DEFAULT_CODES.keys():
		var action_id := StringName(action_key)
		var resolved := String(DEFAULT_CODES[action_key])
		if InputMap.has_action(action_id):
			for event in InputMap.action_get_events(action_id):
				if event is InputEventKey:
					var code := _code_for_key(int(event.physical_keycode))
					if code != "":
						resolved = code
						break
		result[String(action_key)] = resolved
	return result

func bridge_state() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"paused": get_tree().paused if is_inside_tree() else false,
		"bindings": current_keyboard_bindings()
	}

func _web_set_paused(args: Array) -> bool:
	if args.is_empty():
		return false
	return set_paused_from_web(bool(args[0]))

func _web_apply_bindings(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify({})
	var parsed: Variant = JSON.parse_string(String(args[0]))
	if not (parsed is Dictionary):
		return JSON.stringify({})
	return JSON.stringify(apply_keyboard_bindings(parsed as Dictionary))

func _web_reset_bindings(_args: Array) -> String:
	return JSON.stringify(reset_keyboard_bindings())

func _web_get_state(_args: Array) -> String:
	return JSON.stringify(bridge_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGodotPaused = get_tree().paused
	_window.taijifuGodotBindingsJson = JSON.stringify(current_keyboard_bindings())

func _code_for_key(keycode: int) -> String:
	for code in CODE_TO_KEY.keys():
		if int(CODE_TO_KEY[code]) == keycode:
			return String(code)
	return ""

func set_binding_for_test(action_id: StringName, code: String) -> bool:
	return set_keyboard_binding(action_id, code)

func set_paused_for_test(paused: bool) -> bool:
	return set_paused_from_web(paused)
