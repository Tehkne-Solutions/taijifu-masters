extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var bridge := root.get_node_or_null("TaijifuWebBridge") as WebPlatformBridgeRuntime
	if not is_instance_valid(bridge):
		failures.append("Autoload TaijifuWebBridge ausente")
		_finish(failures)
		return

	bridge.reset_keyboard_bindings()
	var defaults := bridge.current_keyboard_bindings()
	if String(defaults.get("p1_attack", "")) != "KeyF":
		failures.append("Golpe P1 não iniciou em KeyF")
	if String(defaults.get("p1_swap", "")) != "KeyT":
		failures.append("Troca de arma P1 não iniciou em KeyT")
	if String(defaults.get("p2_attack", "")) != "Numpad1":
		failures.append("Golpe P2 não iniciou em Numpad1")

	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_X
	joy_event.device = 0
	InputMap.action_add_event(&"p1_attack", joy_event)
	if not bridge.set_binding_for_test(&"p1_attack", "KeyJ"):
		failures.append("Remapeamento válido para KeyJ foi rejeitado")
	if String(bridge.current_keyboard_bindings().get("p1_attack", "")) != "KeyJ":
		failures.append("Golpe P1 não foi remapeado para KeyJ")
	if not _has_keyboard_key(&"p1_attack", KEY_J):
		failures.append("InputMap não recebeu KEY_J")
	if not _has_joy_button(&"p1_attack", JOY_BUTTON_X, 0):
		failures.append("Remapeamento de teclado removeu o gamepad")
	if bridge.set_binding_for_test(&"p1_attack", "Escape"):
		failures.append("Tecla não suportada foi aceita")
	if bridge.set_binding_for_test(&"unknown_action", "KeyK"):
		failures.append("Ação desconhecida foi aceita")

	var applied := bridge.apply_keyboard_bindings({
		"p1_jump": "Space",
		"p2_jump": "Numpad8",
		"invalid": "KeyZ"
	})
	if String(applied.get("p1_jump", "")) != "Space":
		failures.append("Aplicação em lote não remapeou o salto P1")
	if String(applied.get("p2_jump", "")) != "Numpad8":
		failures.append("Aplicação em lote não remapeou o salto P2")
	if applied.has("invalid"):
		failures.append("Aplicação em lote aceitou ação inválida")

	if not bridge.set_paused_for_test(true) or not paused:
		failures.append("Ponte não pausou a SceneTree")
	if not bridge.set_paused_for_test(false) or paused:
		failures.append("Ponte não retomou a SceneTree")

	var state := bridge.bridge_state()
	if int(state.get("version", 0)) != WebPlatformBridgeRuntime.BRIDGE_VERSION:
		failures.append("Versão da ponte inválida")
	if bool(state.get("paused", true)):
		failures.append("Estado final permaneceu pausado")

	bridge.reset_keyboard_bindings()
	if String(bridge.current_keyboard_bindings().get("p1_attack", "")) != "KeyF":
		failures.append("Restauração não recuperou KeyF")
	if String(bridge.current_keyboard_bindings().get("p1_swap", "")) != "KeyT":
		failures.append("Restauração não recuperou KeyT")

	_finish(failures)

func _has_keyboard_key(action_id: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _has_joy_button(action_id: StringName, button: JoyButton, device: int) -> bool:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventJoypadButton and event.button_index == button and event.device == device:
			return true
	return false

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TAIJIFU CI: ponte Web, pausa e remapeamento válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)
