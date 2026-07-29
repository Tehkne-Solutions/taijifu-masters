extends Node
class_name TgapAssetLoader

signal catalog_reloaded(previous_generation: int, current_generation: int)
signal pack_invalidated(pack_id: String, version: String)
signal asset_resolved(pack_id: String, relative_path: String, absolute_path: String)
signal alias_resolved(alias: String, pack_id: String)
signal fallback_used(pack_id: String, logical_path: String, fallback_path: String)
signal deprecated_alias_used(alias: String, replacement: String)
signal reload_rejected(reason: String)

@export var runtime_root: String = "user://tgap"
@export var catalog_filename: String = "tgap-catalog.json"
@export var active_directory: String = "tgap-current"
@export var aliases_path: String = "res://assets/tgap/aliases.json"
@export var allow_fallbacks: bool = true
@export var hot_reload_enabled: bool = false
@export var poll_interval_seconds: float = 1.0

var _catalog: Dictionary = {}
var _aliases: Dictionary = {}
var _generation: int = -1
var _catalog_mtime: int = 0
var _cache: Dictionary = {}
var _poll_accumulator: float = 0.0

func _ready() -> void:
	load_aliases()
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

func load_aliases() -> bool:
	_aliases = {}
	if not FileAccess.file_exists(aliases_path):
		return false
	var file := FileAccess.open(aliases_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema", "") != "tgap/aliases/v1":
		return false
	_aliases = parsed
	return true

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

func canonical_pack_id(pack_or_alias: String) -> String:
	if not get_pack_direct(pack_or_alias).is_empty():
		return pack_or_alias
	var aliases: Dictionary = _aliases.get("aliases", {})
	var entry = aliases.get(pack_or_alias, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return pack_or_alias
	var pack_id := str(entry.get("pack_id", pack_or_alias))
	alias_resolved.emit(pack_or_alias, pack_id)
	if bool(entry.get("deprecated", false)):
		deprecated_alias_used.emit(pack_or_alias, str(entry.get("replacement", pack_id)))
	return pack_id

func resolve(pack_or_alias: String, relative_or_logical_path: String, expected_version: String = "") -> String:
	var pack_id := canonical_pack_id(pack_or_alias)
	var relative_path := resolve_path_alias(pack_id, relative_or_logical_path)
	if not _is_safe_relative_path(relative_path):
		push_error("TGAP path inválido: %s" % relative_path)
		return ""
	var pack := get_pack_direct(pack_id)
	if not pack.is_empty():
		var version := str(pack.get("version", ""))
		if expected_version.is_empty() or version == expected_version:
			var cache_key := "%s@%s:%s" % [pack_id, version, relative_path]
			if _cache.has(cache_key):
				return str(_cache[cache_key])
			var candidate := active_root().path_join("packs").path_join(pack_id).path_join(relative_path)
			if FileAccess.file_exists(candidate):
				_cache[cache_key] = candidate
				asset_resolved.emit(pack_id, relative_path, candidate)
				return candidate
	return _resolve_fallback(pack_id, relative_or_logical_path)

func resolve_path_alias(pack_id: String, logical_or_relative: String) -> String:
	var pack_aliases = _aliases.get("path_aliases", {}).get(pack_id, {})
	if typeof(pack_aliases) == TYPE_DICTIONARY and pack_aliases.has(logical_or_relative):
		return str(pack_aliases[logical_or_relative])
	return logical_or_relative

func load_resource(pack_or_alias: String, relative_or_logical_path: String, expected_version: String = "") -> Resource:
	var path := resolve(pack_or_alias, relative_or_logical_path, expected_version)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

func get_pack(pack_or_alias: String) -> Dictionary:
	return get_pack_direct(canonical_pack_id(pack_or_alias))

func get_pack_direct(pack_id: String) -> Dictionary:
	for pack in _catalog.get("packs", []):
		if typeof(pack) == TYPE_DICTIONARY and str(pack.get("pack_id", "")) == pack_id:
			return pack
	return {}

func has_pack(pack_or_alias: String) -> bool:
	return not get_pack(pack_or_alias).is_empty()

func generation() -> int:
	return _generation

func invalidate_pack(pack_or_alias: String) -> void:
	var pack_id := canonical_pack_id(pack_or_alias)
	var prefix := pack_id + "@"
	for key in _cache.keys():
		if str(key).begins_with(prefix):
			_cache.erase(key)

func invalidate_all() -> void:
	_cache.clear()

func _resolve_fallback(pack_id: String, logical_path: String) -> String:
	if not allow_fallbacks:
		return ""
	var fallback = _aliases.get("fallbacks", {}).get(pack_id, {})
	if typeof(fallback) != TYPE_DICTIONARY:
		return ""
	var pack_state := str(get_pack_direct(pack_id).get("state", "specified"))
	var allowed: Array = fallback.get("allowed_states", [])
	if not allowed.has(pack_state):
		return ""
	var paths = fallback.get("paths", {})
	if typeof(paths) != TYPE_DICTIONARY or not paths.has(logical_path):
		return ""
	var candidate := str(paths[logical_path])
	if not candidate.begins_with("res://") or not FileAccess.file_exists(candidate):
		return ""
	fallback_used.emit(pack_id, logical_path, candidate)
	return candidate

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
