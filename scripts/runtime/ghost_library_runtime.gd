class_name GhostLibraryRuntime
extends Node

const BRIDGE_VERSION := 1
const LIBRARY_PATH := "user://taijifu-ghost-library.json"
const MAX_ITEMS := 24

var items: Array = []
var selected_id := ""
var _window: JavaScriptObject
var _callbacks: Array = []
var _last_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_library()
	_register_web_bridge()

func import_share_code(code: String) -> Dictionary:
	var clean_code := code.strip_edges()
	if clean_code.is_empty():
		return _result(false, "Código de compartilhamento vazio.")
	var sharing := get_node_or_null("/root/TaijifuGhostSharing") as GhostSharingRuntime
	if not is_instance_valid(sharing):
		return _result(false, "Runtime de compartilhamento indisponível.")
	var validation := sharing.import_share_code(clean_code, false)
	if not bool(validation.get("ok", false)):
		return validation
	var decoded := Marshalls.base64_to_raw(clean_code)
	var parsed = JSON.parse_string(decoded.get_string_from_utf8())
	if not parsed is Dictionary:
		return _result(false, "Pacote validado, mas não pôde ser lido pela biblioteca.")
	return add_package(parsed as Dictionary)

func add_package(package: Dictionary) -> Dictionary:
	var recording = package.get("recording", {})
	if not recording is Dictionary or (recording as Dictionary).is_empty():
		return _result(false, "Pacote sem gravação válida.")
	var challenge = package.get("challenge", {})
	if not challenge is Dictionary:
		challenge = {}
	var checksum := String(package.get("checksum", ""))
	var item_id := String((challenge as Dictionary).get("id", ""))
	if item_id.is_empty():
		item_id = "ghost-%s" % checksum.left(12)
	var entry := {
		"id": item_id,
		"name": _display_name(challenge as Dictionary, item_id),
		"imported_unix": int(Time.get_unix_time_from_system()),
		"checksum": checksum,
		"challenge": (challenge as Dictionary).duplicate(true),
		"recording": (recording as Dictionary).duplicate(true)
	}
	var existing := _index_of(item_id)
	if existing >= 0:
		items[existing] = entry
	else:
		items.push_front(entry)
		if items.size() > MAX_ITEMS:
			items.resize(MAX_ITEMS)
	selected_id = item_id
	_save_library()
	_last_result = _result(true, "Fantasma salvo na biblioteca.", {"item": _public_item(entry), "selected_id": selected_id})
	_sync_web_state()
	return _last_result

func select_item(item_id: String) -> Dictionary:
	if _index_of(item_id) < 0:
		return _result(false, "Fantasma não encontrado.")
	selected_id = item_id
	_save_library()
	_last_result = _result(true, "Fantasma selecionado.", {"selected_id": selected_id})
	_sync_web_state()
	return _last_result

func remove_item(item_id: String) -> Dictionary:
	var index := _index_of(item_id)
	if index < 0:
		return _result(false, "Fantasma não encontrado.")
	items.remove_at(index)
	if selected_id == item_id:
		selected_id = String((items[0] as Dictionary).get("id", "")) if not items.is_empty() else ""
	_save_library()
	_last_result = _result(true, "Fantasma removido da biblioteca.")
	_sync_web_state()
	return _last_result

func play_selected() -> Dictionary:
	var index := _index_of(selected_id)
	if index < 0:
		return _result(false, "Selecione um fantasma da biblioteca.")
	var runtime := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(runtime):
		return _result(false, "Runtime de fantasmas indisponível.")
	var original := runtime.best_recording
	runtime.best_recording = ((items[index] as Dictionary).get("recording", {}) as Dictionary).duplicate(true)
	var started := runtime.play_best_recording()
	runtime.best_recording = original
	_last_result = _result(started, "Corrida contra fantasma iniciada." if started else "Não foi possível iniciar o fantasma.", {"selected_id": selected_id})
	_sync_web_state()
	return _last_result

func current_state() -> Dictionary:
	var public_items: Array = []
	for item in items:
		if item is Dictionary:
			public_items.append(_public_item(item as Dictionary))
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"count": public_items.size(),
		"max_items": MAX_ITEMS,
		"selected_id": selected_id,
		"items": public_items,
		"last_result": _last_result.duplicate(true)
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"import_code": return import_share_code(String(request.get("code", "")))
		&"select": return select_item(String(request.get("id", "")))
		&"remove": return remove_item(String(request.get("id", "")))
		&"play_selected": return play_selected()
	return current_state()

func _display_name(challenge: Dictionary, fallback: String) -> String:
	var score := int(challenge.get("score", 0))
	var chain := int(challenge.get("max_chain", 0))
	return "Desafio %d pts · elo %d" % [score, chain] if score > 0 else fallback

func _public_item(item: Dictionary) -> Dictionary:
	return {
		"id": String(item.get("id", "")),
		"name": String(item.get("name", "Fantasma")),
		"imported_unix": int(item.get("imported_unix", 0)),
		"checksum": String(item.get("checksum", "")).left(12),
		"challenge": (item.get("challenge", {}) as Dictionary).duplicate(true)
	}

func _index_of(item_id: String) -> int:
	for index in items.size():
		if String((items[index] as Dictionary).get("id", "")) == item_id:
			return index
	return -1

func _load_library() -> void:
	if not FileAccess.file_exists(LIBRARY_PATH):
		return
	var file := FileAccess.open(LIBRARY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var loaded_items = (parsed as Dictionary).get("items", [])
	items = loaded_items if loaded_items is Array else []
	if items.size() > MAX_ITEMS:
		items.resize(MAX_ITEMS)
	selected_id = String((parsed as Dictionary).get("selected_id", ""))
	if _index_of(selected_id) < 0:
		selected_id = String((items[0] as Dictionary).get("id", "")) if not items.is_empty() else ""

func _save_library() -> void:
	var file := FileAccess.open(LIBRARY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": BRIDGE_VERSION, "selected_id": selected_id, "items": items}, "  "))

func _result(ok: bool, message: String, data: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "message": message, "data": data}

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var command_callback := JavaScriptBridge.create_callback(_web_command)
	var state_callback := JavaScriptBridge.create_callback(_web_state)
	_callbacks = [command_callback, state_callback]
	_window.taijifuGhostLibraryCommand = command_callback
	_window.taijifuGhostLibraryState = state_callback
	_window.taijifuGhostLibraryReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify(current_state())
	var parsed = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return JSON.stringify(_result(false, "Comando inválido."))
	return JSON.stringify(command(parsed as Dictionary))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGhostLibraryStateJson = JSON.stringify(current_state())
	_window.taijifuGhostLibraryReady = true
