class_name GhostSharingRuntime
extends Node

const BRIDGE_VERSION := 1
const PACKAGE_KIND := "taijifu-ghost"
const MAX_FRAMES := 1800
const EXPORT_PATH := "user://taijifu-ghost-export.json"

var _window: JavaScriptObject
var _callbacks: Array = []
var _last_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_web_bridge()

func _ghost_runtime() -> InputGhostMasteryRuntime:
	return get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime

func export_best_package() -> Dictionary:
	var runtime := _ghost_runtime()
	if not is_instance_valid(runtime) or runtime.best_recording.is_empty():
		return _result(false, "Nenhum fantasma disponível para exportação.")
	var recording := _sanitize_recording(runtime.best_recording)
	if recording.is_empty():
		return _result(false, "O fantasma atual não passou pela validação.")
	var package := {
		"kind": PACKAGE_KIND,
		"version": BRIDGE_VERSION,
		"game": "Taijifu Masters",
		"created_unix": int(Time.get_unix_time_from_system()),
		"recording": recording,
		"challenge": _challenge_from_recording(recording)
	}
	package["checksum"] = _checksum_for(package)
	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(package, "  "))
	var code := Marshalls.raw_to_base64(JSON.stringify(package).to_utf8_buffer())
	_last_result = _result(true, "Fantasma exportado com sucesso.", {
		"path": EXPORT_PATH,
		"share_code": code,
		"package": package
	})
	_sync_web_state()
	return _last_result

func import_share_code(code: String, replace_best: bool = false) -> Dictionary:
	if code.strip_edges().is_empty():
		return _result(false, "Código de compartilhamento vazio.")
	var decoded := Marshalls.base64_to_raw(code.strip_edges())
	if decoded.is_empty():
		return _result(false, "Código de compartilhamento inválido.")
	return import_package_json(decoded.get_string_from_utf8(), replace_best)

func import_package_json(payload: String, replace_best: bool = false) -> Dictionary:
	var parsed: Variant = JSON.parse_string(payload)
	if not parsed is Dictionary:
		return _result(false, "Pacote JSON inválido.")
	var package: Dictionary = parsed
	if String(package.get("kind", "")) != PACKAGE_KIND:
		return _result(false, "Pacote incompatível com Taijifu Masters.")
	if int(package.get("version", 0)) > BRIDGE_VERSION:
		return _result(false, "Pacote criado por uma versão mais recente.")
	var expected := String(package.get("checksum", ""))
	var unsigned := package.duplicate(true)
	unsigned.erase("checksum")
	if expected.is_empty() or expected != _checksum_for(unsigned):
		return _result(false, "Checksum inválido; o pacote pode ter sido alterado.")
	var recording := _sanitize_recording(package.get("recording", {}))
	if recording.is_empty():
		return _result(false, "A gravação importada é inválida.")
	var runtime := _ghost_runtime()
	if not is_instance_valid(runtime):
		return _result(false, "Runtime de fantasmas indisponível.")
	var imported_score := float((recording.get("summary", {}) as Dictionary).get("score", 0.0))
	var local_score := float((runtime.profile.get("best_summary", {}) as Dictionary).get("score", 0.0))
	if not replace_best and not runtime.best_recording.is_empty() and imported_score <= local_score:
		_last_result = _result(true, "Fantasma importado para comparação, sem substituir o recorde local.", {
			"imported": recording,
			"replaced_best": false,
			"challenge": package.get("challenge", {})
		})
		_sync_web_state()
		return _last_result
	runtime.best_recording = recording.duplicate(true)
	runtime.profile["best_summary"] = (recording.get("summary", {}) as Dictionary).duplicate(true)
	runtime.call("_save_best_recording")
	runtime.call("_save_profile")
	runtime.call("_sync_web_state")
	_last_result = _result(true, "Fantasma importado e definido como melhor replay.", {
		"replaced_best": true,
		"challenge": package.get("challenge", {})
	})
	_sync_web_state()
	return _last_result

func _sanitize_recording(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var frames_value: Variant = source.get("frames", [])
	if not frames_value is Array:
		return {}
	var frames: Array = frames_value
	if frames.size() < 2 or frames.size() > MAX_FRAMES:
		return {}
	var clean_frames: Array = []
	var last_time := -1
	for frame_value in frames:
		if not frame_value is Dictionary:
			return {}
		var frame: Dictionary = frame_value
		var t := maxi(0, int(frame.get("t", 0)))
		if t < last_time:
			return {}
		last_time = t
		var position: Array = frame.get("position", [])
		if position.size() != 2:
			return {}
		clean_frames.append({
			"t": t,
			"position": [clampf(float(position[0]), -10000.0, 10000.0), clampf(float(position[1]), -10000.0, 10000.0)],
			"velocity": frame.get("velocity", [0.0, 0.0]),
			"facing": clampf(float(frame.get("facing", 1.0)), -1.0, 1.0),
			"phase": clampi(int(frame.get("phase", 0)), 0, 4),
			"technique": String(frame.get("technique", "")).left(80),
			"weapon": String(frame.get("weapon", "")).left(80),
			"inputs": frame.get("inputs", {}) if frame.get("inputs", {}) is Dictionary else {}
		})
	var summary := source.get("summary", {})
	if not summary is Dictionary:
		summary = {}
	return {
		"version": mini(BRIDGE_VERSION, int(source.get("version", BRIDGE_VERSION))),
		"created_unix": maxi(0, int(source.get("created_unix", 0))),
		"duration_ms": maxi(last_time, int(source.get("duration_ms", last_time))),
		"frames": clean_frames,
		"events": [],
		"summary": (summary as Dictionary).duplicate(true),
		"message": "Fantasma importado"
	}

func _challenge_from_recording(recording: Dictionary) -> Dictionary:
	var summary: Dictionary = recording.get("summary", {})
	return {
		"id": "ghost-%s" % String.num_int64(int(recording.get("created_unix", 0)), 16),
		"score": int(summary.get("score", 0)),
		"accuracy": float(summary.get("accuracy", 0.0)),
		"max_chain": int(summary.get("max_chain", 0)),
		"duration_ms": int(recording.get("duration_ms", 0)),
		"rules": "Supere a pontuação mantendo as mesmas regras físicas e sem bônus ocultos."
	}

func _checksum_for(package: Dictionary) -> String:
	return JSON.stringify(package).sha256_text()

func _result(ok: bool, message: String, data: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "message": message, "data": data}

func current_state() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"export_path": EXPORT_PATH,
		"has_best": is_instance_valid(_ghost_runtime()) and not _ghost_runtime().best_recording.is_empty(),
		"last_result": _last_result.duplicate(true)
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"export_best":
			return export_best_package()
		&"import_code":
			return import_share_code(String(request.get("code", "")), bool(request.get("replace_best", false)))
		&"import_json":
			return import_package_json(String(request.get("payload", "")), bool(request.get("replace_best", false)))
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
	_window.taijifuGhostSharingCommand = command_callback
	_window.taijifuGhostSharingState = state_callback
	_window.taijifuGhostSharingVersion = BRIDGE_VERSION
	_window.taijifuGhostSharingReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify(current_state())
	var parsed: Variant = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return JSON.stringify(_result(false, "Comando inválido."))
	return JSON.stringify(command(parsed as Dictionary))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGhostSharingStateJson = JSON.stringify(current_state())
	_window.taijifuGhostSharingReady = true

func package_for_test(recording: Dictionary) -> Dictionary:
	var clean := _sanitize_recording(recording)
	if clean.is_empty():
		return {}
	var package := {"kind": PACKAGE_KIND, "version": BRIDGE_VERSION, "recording": clean, "challenge": _challenge_from_recording(clean)}
	package["checksum"] = _checksum_for(package)
	return package
