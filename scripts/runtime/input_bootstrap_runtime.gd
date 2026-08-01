extends Node

const KEY_BINDINGS := {
	&"p1_left": KEY_A,
	&"p1_right": KEY_D,
	&"p1_down": KEY_S,
	&"p1_jump": KEY_W,
	&"p1_dodge": KEY_Q,
	&"p1_attack": KEY_F,
	&"p1_push": KEY_G,
	&"p1_grab": KEY_E,
	&"p1_echo": KEY_H,
	&"p1_block": KEY_R,
	&"p1_element": KEY_C,
	&"p1_swap": KEY_T,
	&"first_playable_restart": KEY_ENTER,
	&"first_playable_pause": KEY_ESCAPE,
}

const CPU_ACTION_SUFFIXES := [
	"left", "right", "down", "jump", "dodge", "attack",
	"push", "grab", "echo", "block", "element", "swap"
]

func _ready() -> void:
	register_required_actions()

func register_required_actions() -> void:
	for action in KEY_BINDINGS:
		_register_key_action(action, KEY_BINDINGS[action])
	for suffix in CPU_ACTION_SUFFIXES:
		_register_action(StringName("p2_%s" % suffix))

func _register_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)

func _register_key_action(action: StringName, keycode: Key) -> void:
	_register_action(action)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
