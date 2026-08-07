extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var keyboard_bridge := root.get_node_or_null("TaijifuWebBridge") as WebPlatformBridgeRuntime
	if not is_instance_valid(keyboard_bridge):
		failures.append("Autoload TaijifuWebBridge ausente")
		_finish(failures)
		return

	# Sprint 0 forbids these runtimes as permanent autoloads. Mount the real
	# dependency graph temporarily so ControllerMasteryRuntime can resolve it.
	var base := GamepadTrainingRuntime.new()
	base.name = "TaijifuGamepadTraining"
	root.add_child(base)
	var mastery := ControllerMasteryRuntime.new()
	mastery.name = "TaijifuControllerMastery"
	root.add_child(mastery)
	if not is_instance_valid(base) or not is_instance_valid(mastery):
		failures.append("Runtimes temporários de maestria não puderam ser montados")
		_cleanup(base, mastery)
		_finish(failures)
		return

	keyboard_bridge.reset_keyboard_bindings()
	mastery.assign_device(1, -1)
	var points := [0.0, 0.08, 0.28, 0.74, 1.0]
	if not mastery.set_curve_points(1, points):
		failures.append("Curva personalizada válida foi rejeitada")
	var low := mastery.curve_value_for_test(0.35, 0.20, points)
	var high := mastery.curve_value_for_test(0.80, 0.20, points)
	if not low > 0.0 or not high > low:
		failures.append("Curva personalizada não manteve progressão monotônica")
	if mastery.curve_value_for_test(0.10, 0.20, points) != 0.0:
		failures.append("Zona morta não anulou entrada pequena")
	if not is_equal_approx(mastery.curve_value_for_test(1.0, 0.20, points), 1.0):
		failures.append("Curva não alcançou força máxima")

	if not mastery.set_trigger_actions(1, "block", "swap", 0.62):
		failures.append("Remapeamento livre de L2/R2 foi rejeitado")
	mastery.call("_apply_trigger_aliases")
	if not _has_trigger_axis(&"p1_block", JOY_AXIS_TRIGGER_LEFT, -1):
		failures.append("L2 não foi aplicado em Guarda")
	if not _has_trigger_axis(&"p1_swap", JOY_AXIS_TRIGGER_RIGHT, -1):
		failures.append("R2 não foi aplicado em Trocar arma")
	if _has_trigger_axis(&"p1_element", JOY_AXIS_TRIGGER_LEFT, -1):
		failures.append("Alias antigo de L2 permaneceu em Elemento")
	if not _has_keyboard_key(&"p1_attack", KEY_F):
		failures.append("Configuração de maestria removeu o teclado de Golpe")

	if not mastery.set_cancel_options(1, 0.73, true):
		failures.append("Limiar de cancelamento válido foi rejeitado")
	mastery.set_show_windows(false)
	var state := mastery.current_state()
	var player: Dictionary = state.get("players", {}).get("1", {})
	var device_profile: Dictionary = player.get("profile", {})
	if String(player.get("guid", "")) != "slot:1":
		failures.append("Perfil sem controle não recebeu identificador de slot")
	if String(device_profile.get("left_trigger_action", "")) != "block":
		failures.append("Ação de L2 não foi persistida")
	if String(device_profile.get("right_trigger_action", "")) != "swap":
		failures.append("Ação de R2 não foi persistida")
	if not is_equal_approx(float(device_profile.get("trigger_threshold", 0.0)), 0.62):
		failures.append("Limiar dos gatilhos não foi persistido")
	if not is_equal_approx(float(device_profile.get("cancel_threshold", 0.0)), 0.73):
		failures.append("Limiar de cancelamento não foi persistido")
	if bool(state.get("show_windows", true)):
		failures.append("Preferência das janelas técnicas não foi persistida")

	mastery.start_combo_dojo()
	if mastery.record_combo_event_for_test(&"chain", 3) != 1:
		failures.append("Dojo não avançou após elo de três técnicas")
	if mastery.record_combo_event_for_test(&"hits", 2) != 2:
		failures.append("Dojo não avançou após dois acertos")
	if mastery.record_combo_event_for_test(&"parry") != 3:
		failures.append("Dojo não avançou após aparo")
	if mastery.record_combo_event_for_test(&"cancel") != 4:
		failures.append("Dojo não concluiu após cancelamento")
	var completed := mastery.current_state()
	if not bool(completed.get("dojo", {}).get("completed", false)):
		failures.append("Conclusão do dojo não foi persistida")

	mastery.reset_device_profile(1)
	var reset_profile: Dictionary = mastery.current_state().get("players", {}).get("1", {}).get("profile", {})
	var reset_points: Array = reset_profile.get("curve_points", [])
	if reset_points.size() != 5 or not is_equal_approx(float(reset_points[2]), 0.44):
		failures.append("Restauração não recuperou a curva padrão")
	if String(reset_profile.get("left_trigger_action", "")) != "element":
		failures.append("Restauração não recuperou L2 em Elemento")
	if String(reset_profile.get("right_trigger_action", "")) != "attack":
		failures.append("Restauração não recuperou R2 em Golpe")

	_cleanup(base, mastery)
	_finish(failures)

func _cleanup(base: Node, mastery: Node) -> void:
	if is_instance_valid(mastery):
		mastery.free()
	if is_instance_valid(base):
		base.free()

func _has_trigger_axis(action_id: StringName, axis: JoyAxis, device: int) -> bool:
	if not InputMap.has_action(action_id):
		return false
	for event in InputMap.action_get_events(action_id):
		if event is InputEventJoypadMotion and event.axis == axis and event.device == device:
			return true
	return false

func _has_keyboard_key(action_id: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action_id):
		return false
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TAIJIFU CI: perfis GUID, curva visual, gatilhos livres, janelas e combo dojo válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)
