extends Node
class_name TgapAssetLoader

signal catalog_reloaded(previous_generation: int, current_generation: int)
signal pack_invalidated(pack_id: String, version: String)
signal asset_resolved(pack_id: String, relative_path: String, absolute_path: String)
signal reload_rejected(reason: String)

@export var runtime_root: String = "user://tgap"
@export var catalog_filename: String = "tgap-catalog.json"
@export var active_directory: String = "tgap-current"
@export var hot_reload_enabled: bool = false
@export var poll_interval_seconds: float = 1.0

var _catalog: Dictionary = {}
var _generation: int = -1
var _catalog_mtime: int = 0
var _cache: Dictionary = {}
var _poll_accumulator: float = 0.0

func _ready() -> void:
	load_catalog(true)
	set_process(hot_reload_enabled)

func _process(delta: float) -> void:
	if not hot_reload_enabled:
		return
	_poll_accumulator += delta
	if _poll_accumulator < poll_interval_seconds:
		return
	_poll_accumulator = 0.0
	poll_catalog()

func catalog_path() -> String:
	return runtime_root.path_join(catalog_filename)

func active_root() -> String:
	return runtime_root.path_join(active_directory)

func load_catalog(force: bool = false) -> bool:
	var path := catalog_path()
	if not FileAccess.file_exists(path):
		reload_rejected.emit("catalog_missing")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		reload_rejected.emit("catalog_unreadable")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		reload_rejected.emit("catalog_invalid_json")
		return false
	var next_catalog: Dictionary = parsed
	if next_catalog.get("schema", "") != "tgap/install-catalog/v1":
		reload_rejected.emit("catalog_schema_mismatch")
		return false
	var next_generation := int(next_catalog.get("generation", -1))
	if not force and next_generation <= _generation:
		return false
	var previous_generation := _generation
	var previous_packs := _pack_versions(_catalog)
	var next_packs := _pack_versions(next_catalog)
	_catalog = next_catalog
	_generation = next_generation
	_catalog_mtime = FileAccess.get_modified_time(path)
	_invalidate_changed_packs(previous_packs, next_packs)
	catalog_reloaded.emit(previous_generation, _generation)
	return true

func poll_catalog() -> bool:
	var path := catalog_path()
	if not FileAccess.file_exists(path):
		return false
	var mtime := FileAccess.get_modified_time(path)
	if mtime <= _catalog_mtime:
		return false
	return load_catalog(false)

func resolve(pack_id: String, relative_path: String, expected_version: String = "") -> String:
	if not _is_safe_relative_path(relative_path):
		push_error("TGAP path inválido: %s" % relative_path)
		return ""
	var pack := get_pack(pack_id)
	if pack.is_empty():
		return ""
	var version := str(pack.get("version", ""))
	if not expected_version.is_empty() and version != expected_version:
		return ""
	var cache_key := "%s@%s:%s" % [pack_id, version, relative_path]
	if _cache.has(cache_key):
		return str(_cache[cache_key])
	var candidate := active_root().path_join("packs").path_join(pack_id).path_join(relative_path)
	if not FileAccess.file_exists(candidate):
		return ""
	_cache[cache_key] = candidate
	asset_resolved.emit(pack_id, relative_path, candidate)
	return candidate

func load_resource(pack_id: String, relative_path: String, expected_version: String = "") -> Resource:
	var path := resolve(pack_id, relative_path, expected_version)
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

func get_pack(pack_id: String) -> Dictionary:
	for pack in _catalog.get("packs", []):
		if typeof(pack) == TYPE_DICTIONARY and str(pack.get("pack_id", "")) == pack_id:
			return pack
	return {}

func generation() -> int:
	return _generation

func invalidate_pack(pack_id: String) -> void:
	var prefix := pack_id + "@"
	for key in _cache.keys():
		if str(key).begins_with(prefix):
			_cache.erase(key)

func invalidate_all() -> void:
	_cache.clear()

func _pack_versions(catalog: Dictionary) -> Dictionary:
	var result := {}
	for pack in catalog.get("packs", []):
		if typeof(pack) == TYPE_DICTIONARY:
			result[str(pack.get("pack_id", ""))] = str(pack.get("version", ""))
	return result

func _invalidate_changed_packs(previous: Dictionary, current: Dictionary) -> void:
	for pack_id in previous.keys():
		if not current.has(pack_id) or current[pack_id] != previous[pack_id]:
			invalidate_pack(str(pack_id))
			pack_invalidated.emit(str(pack_id), str(previous[pack_id]))
	for pack_id in current.keys():
		if not previous.has(pack_id):
			invalidate_pack(str(pack_id))

func _is_safe_relative_path(value: String) -> bool:
	if value.is_empty() or value.is_absolute_path():
		return false
	var normalized := value.replace("\\", "/")
	for segment in normalized.split("/"):
		if segment == ".." or segment == "":
			return false
	return true
