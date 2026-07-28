extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var sharing := root.get_node_or_null("TaijifuGhostSharing") as GhostSharingRuntime
	if not is_instance_valid(sharing):
		failures.append("Autoload TaijifuGhostSharing ausente")
		_finish(failures)
		return

	var recording := {
		"version": 1,
		"created_unix": 123456,
		"duration_ms": 400,
		"frames": [
			{"t": 0, "position": [100.0, 200.0], "velocity": [0.0, 0.0], "facing": 1.0, "phase": 0, "technique": "", "weapon": "staff", "inputs": {}},
			{"t": 400, "position": [140.0, 200.0], "velocity": [100.0, 0.0], "facing": 1.0, "phase": 2, "technique": "horizon_thrust", "weapon": "staff", "inputs": {"attack": 1.0}}
		],
		"summary": {"score": 720, "accuracy": 0.75, "max_chain": 4}
	}
	var package := sharing.package_for_test(recording)
	if package.is_empty():
		failures.append("Pacote de fantasma não foi criado")
	if String(package.get("kind", "")) != "taijifu-ghost":
		failures.append("Tipo do pacote incorreto")
	if String(package.get("checksum", "")).length() != 64:
		failures.append("Checksum SHA-256 ausente")
	var challenge: Dictionary = package.get("challenge", {})
	if int(challenge.get("score", 0)) != 720:
		failures.append("Desafio não preservou a pontuação")

	var code := Marshalls.raw_to_base64(JSON.stringify(package).to_utf8_buffer())
	var result := sharing.import_share_code(code, true)
	if not bool(result.get("ok", false)):
		failures.append("Código válido não pôde ser importado: %s" % String(result.get("message", "")))

	var tampered := package.duplicate(true)
	tampered["recording"]["summary"]["score"] = 9999
	var rejected := sharing.import_package_json(JSON.stringify(tampered), true)
	if bool(rejected.get("ok", false)):
		failures.append("Pacote adulterado não foi rejeitado")

	var invalid_frames := recording.duplicate(true)
	invalid_frames["frames"] = [recording["frames"][1], recording["frames"][0]]
	if not sharing.package_for_test(invalid_frames).is_empty():
		failures.append("Frames fora de ordem não foram rejeitados")

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_SHARING_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
