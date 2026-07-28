extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var base := root.get_node_or_null("TaijifuGamepadTraining") as GamepadTrainingRuntime
	var experience := root.get_node_or_null("TaijifuGamepadExperience") as GamepadExperienceRuntime
	if not is_instance_valid(base):
		failures.append("Autoload TaijifuGamepadTraining ausente")
	if not is_instance_valid(experience):
		failures.append("Autoload TaijifuGamepadExperience ausente")
	if not failures.is_empty():
		_finish(failures)
		return

	base.reset_profile()
	experience.reset_all_profiles()
	var initial := experience.current_state()
	var player_one: Dictionary = initial.get("profile", {}).get("players", {}).get("1", {})
	if String(player_one.get("response_curve", "")) != "linear":
		failures.append("Curva padrão do P1 não é linear")
	if not is_equal_approx(float(player_one.get("trigger_threshold", 0.0)), 0.55):
		failures.append("Limiar padrão dos gatilhos não é 0.55")
	if not bool(player_one.get("haptics_enabled", false)):
		failures.append("Vibração não iniciou habilitada")

	var linear := absf(experience.curve_value_for_test(0.70, 0.20, &"linear"))
	var precision := absf(experience.curve_value_for_test(0.70, 0.20, &"precision"))
	var aggressive := absf(experience.curve_value_for_test(0.70, 0.20, &"aggressive"))
	if not precision < linear:
		failures.append("Curva de precisão não reduziu a resposta intermediária")
	if not aggressive > linear:
		failures.append("Curva agressiva não ampliou a resposta intermediária")
	if experience.curve_value_for_test(0.10, 0.20, &"linear") != 0.0:
		failures.append("Zona morta não anulou entrada pequena")

	if not experience.set_tuning_for_test(1, &"precision", 0.64, false, 0.40):
		failures.append("Ajuste válido do P1 foi rejeitado")
	var tuned: Dictionary = experience.current_profile().get("players", {}).get("1", {})
	if String(tuned.get("response_curve", "")) != "precision":
		failures.append("Curva de precisão não foi persistida")
	if not is_equal_approx(float(tuned.get("trigger_threshold", 0.0)), 0.64):
		failures.append("Limiar 0.64 não foi persistido")
	if bool(tuned.get("haptics_enabled", true)):
		failures.append("Desativação da vibração não foi persistida")
	if not is_equal_approx(float(tuned.get("vibration_scale", 0.0)), 0.40):
		failures.append("Escala de vibração 0.40 não foi persistida")
	if experience.set_tuning_for_test(3, &"linear", 0.5, true, 1.0):
		failures.append("Jogador inválido foi aceito")
	if experience.set_tuning_for_test(1, &"unknown", 0.5, true, 1.0):
		failures.append("Curva inválida foi aceita")

	if not experience.set_player_device(1, 4):
		failures.append("Dispositivo alternativo não foi aplicado")
	if not experience.set_player_deadzone(1, 0.33):
		failures.append("Zona morta 0.33 não foi aplicada")
	var base_player: Dictionary = base.current_profile().get("players", {}).get("1", {})
	if int(base_player.get("device", -1)) != 4:
		failures.append("Dispositivo 4 não foi persistido no perfil base")
	if not is_equal_approx(float(base_player.get("deadzone", 0.0)), 0.33):
		failures.append("Zona morta 0.33 não foi persistida no perfil base")

	experience.apply_profile()
	if not _has_trigger_axis(&"p1_attack", JOY_AXIS_TRIGGER_RIGHT, 4):
		failures.append("R2 não foi adicionado como alias de Golpe")
	if not _has_trigger_axis(&"p1_element", JOY_AXIS_TRIGGER_LEFT, 4):
		failures.append("L2 não foi adicionado como alias de Elemento")
	if not _has_keyboard_key(&"p1_attack", KEY_F):
		failures.append("Configuração avançada removeu o teclado de Golpe")

	if experience.record_advanced_event_for_test(&"grab_started") != 1:
		failures.append("Dojo não avançou após agarrão real")
	if experience.record_advanced_event_for_test(&"grab_escaped") != 2:
		failures.append("Dojo não avançou após fuga real")
	if experience.record_advanced_event_for_test(&"weapon_swapped") != 3:
		failures.append("Dojo não avançou após troca de arma")
	if experience.record_advanced_event_for_test(&"technique_reproduced") != 4:
		failures.append("Dojo não concluiu após reprodução do eco")

	experience.reset_all_profiles()
	var reset_player: Dictionary = experience.current_profile().get("players", {}).get("1", {})
	if String(reset_player.get("response_curve", "")) != "linear":
		failures.append("Restauração não recuperou a curva linear")
	if not bool(reset_player.get("haptics_enabled", false)):
		failures.append("Restauração não reativou a vibração")

	_finish(failures)

func _has_trigger_axis(action_id: StringName, axis: JoyAxis, device: int) -> bool:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventJoypadMotion and event.axis == axis and event.device == device:
			return true
	return false

func _has_keyboard_key(action_id: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TAIJIFU CI: curvas, gatilhos, vibração e dojo avançado válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)
