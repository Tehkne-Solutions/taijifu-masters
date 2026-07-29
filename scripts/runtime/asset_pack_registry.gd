extends Node

signal pack_loaded(pack_id: String, manifest: Dictionary)
signal pack_failed(pack_path: String, reason: String)
signal legacy_fallback_used(pack_id: String)
signal legacy_api_used(method_name: String, pack_id: String, usage_count: int)
signal legacy_disabled(method_name: String, pack_id: String)

const PACK_ROOT := "res://assets/packs"
const REQUIRED_PACK_KEYS := ["id", "name", "version", "status", "signature"]
const LEGACY_SETTING := "taijifu/tgap/legacy_adapter_enabled"
const LEGACY_SCAN_SETTING := "taijifu/tgap/legacy_pack_scan_enabled"

@export var prefer_tgap: bool = true
@export var legacy_adapter_enabled: bool = false
@export var scan_legacy_packs: bool = false
@export var warn_once_per_method: bool = true

var packs: Dictionary = {}
var _usage_counts: Dictionary = {}
var _warned_methods: Dictionary = {}

func _ready() -> void:
	_apply_project_settings()
	reload_packs()

func _apply_project_settings() -> void:
	if ProjectSettings.has_setting(LEGACY_SETTING):
		legacy_adapter_enabled = bool(ProjectSettings.get_setting(LEGACY_SETTING))
	if ProjectSettings.has_setting(LEGACY_SCAN_SETTING):
		scan_legacy_packs = bool(ProjectSettings.get_setting(LEGACY_SCAN_SETTING))

func reload_packs() -> void:
	packs.clear()
	if legacy_adapter_enabled and scan_legacy_packs:
		_scan_pack_directory(PACK_ROOT)

func get_pack(pack_id: String) -> Dictionary:
	_record_usage("get_pack", pack_id)
	if prefer_tgap and is_instance_valid(TgapAssetLoader):
		var tgap_pack := TgapAssetLoader.get_pack(pack_id)
		if not tgap_pack.is_empty():
			return _to_legacy_manifest(tgap_pack)
	if not legacy_adapter_enabled:
		legacy_disabled.emit("get_pack", pack_id)
		return {}
	if packs.has(pack_id):
		legacy_fallback_used.emit(pack_id)
	return packs.get(pack_id, {})

func has_pack(pack_id: String) -> bool:
	_record_usage("has_pack", pack_id)
	if prefer_tgap and is_instance_valid(TgapAssetLoader) and TgapAssetLoader.has_pack(pack_id):
		return true
	if not legacy_adapter_enabled:
		legacy_disabled.emit("has_pack", pack_id)
		return false
	return packs.has(pack_id)

func list_pack_ids() -> PackedStringArray:
	_record_usage("list_pack_ids", "")
	var unique := {}
	if legacy_adapter_enabled:
		for pack_id in packs.keys():
			unique[String(pack_id)] = true
	if prefer_tgap and is_instance_valid(TgapAssetLoader):
		for pack in TgapAssetLoader._catalog.get("packs", []):
			if typeof(pack) == TYPE_DICTIONARY:
				unique[str(pack.get("pack_id", ""))] = true
	var ids := PackedStringArray()
	for pack_id in unique.keys():
		if not str(pack_id).is_empty():
			ids.append(str(pack_id))
	ids.sort()
	return ids

func resolve_asset(pack_id: String, relative_or_logical_path: String, expected_version: String = "") -> String:
	_record_usage("resolve_asset", pack_id)
	if prefer_tgap and is_instance_valid(TgapAssetLoader):
		var resolved := TgapAssetLoader.resolve(pack_id, relative_or_logical_path, expected_version)
		if not resolved.is_empty():
			return resolved
	if not legacy_adapter_enabled:
		legacy_disabled.emit("resolve_asset", pack_id)
		return ""
	var legacy := get_pack(pack_id)
	var root := str(legacy.get("root", ""))
	if root.is_empty() or relative_or_logical_path.contains(".."):
		return ""
	var candidate := root.path_join(relative_or_logical_path)
	if FileAccess.file_exists(candidate):
		legacy_fallback_used.emit(pack_id)
		return candidate
	return ""

func load_asset(pack_id: String, relative_or_logical_path: String, expected_version: String = "") -> Resource:
	_record_usage("load_asset", pack_id)
	var path := resolve_asset(pack_id, relative_or_logical_path, expected_version)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

func usage_snapshot() -> Dictionary:
	return _usage_counts.duplicate(true)

func reset_usage_telemetry() -> void:
	_usage_counts.clear()
	_warned_methods.clear()

func _record_usage(method_name: String, pack_id: String) -> void:
	var key := "%s:%s" % [method_name, pack_id]
	var count := int(_usage_counts.get(key, 0)) + 1
	_usage_counts[key] = count
	legacy_api_used.emit(method_name, pack_id, count)
	if warn_once_per_method and not _warned_methods.has(method_name):
		_warned_methods[method_name] = true
		push_warning("AssetPackRegistry.%s está depreciado; use TgapAssetLoader." % method_name)

func _to_legacy_manifest(pack: Dictionary) -> Dictionary:
	return {
		"id": str(pack.get("pack_id", "")),
		"name": str(pack.get("display_name", pack.get("pack_id", ""))),
		"version": str(pack.get("version", "")),
		"status": str(pack.get("state", "integrated")),
		"signature": "Tehkné Solutions",
		"root": TgapAssetLoader.active_root().path_join("packs").path_join(str(pack.get("pack_id", ""))),
		"source": "tgap"
	}

func _scan_pack_directory(root_path: String) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		pack_failed.emit(root_path, "pack root not found")
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if directory.current_is_dir() and not entry.begins_with("."):
			_load_manifest(root_path.path_join(entry).path_join("pack.json"))
		entry = directory.get_next()
	directory.list_dir_end()

func _load_manifest(manifest_path: String) -> void:
	if not FileAccess.file_exists(manifest_path):
		return
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		pack_failed.emit(manifest_path, "manifest unreadable")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		pack_failed.emit(manifest_path, "manifest is not a JSON object")
		return
	var manifest: Dictionary = parsed
	for key in REQUIRED_PACK_KEYS:
		if not manifest.has(key):
			pack_failed.emit(manifest_path, "missing key: %s" % key)
			return
	if manifest.get("signature", "") != "Tehkné Solutions":
		pack_failed.emit(manifest_path, "invalid signature")
		return
	manifest["root"] = manifest_path.get_base_dir()
	var pack_id := String(manifest["id"])
	packs[pack_id] = manifest
	pack_loaded.emit(pack_id, manifest)
