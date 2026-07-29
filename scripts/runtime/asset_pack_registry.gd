extends Node

signal pack_loaded(pack_id: String, manifest: Dictionary)
signal pack_failed(pack_path: String, reason: String)
signal legacy_fallback_used(pack_id: String)

const PACK_ROOT := "res://assets/packs"
const REQUIRED_PACK_KEYS := ["id", "name", "version", "status", "signature"]

@export var prefer_tgap: bool = true
@export var scan_legacy_packs: bool = true

var packs: Dictionary = {}

func _ready() -> void:
	reload_packs()

func reload_packs() -> void:
	packs.clear()
	if scan_legacy_packs:
		_scan_pack_directory(PACK_ROOT)

func get_pack(pack_id: String) -> Dictionary:
	if prefer_tgap and is_instance_valid(TgapAssetLoader):
		var tgap_pack := TgapAssetLoader.get_pack(pack_id)
		if not tgap_pack.is_empty():
			return _to_legacy_manifest(tgap_pack)
	if packs.has(pack_id):
		legacy_fallback_used.emit(pack_id)
	return packs.get(pack_id, {})

func has_pack(pack_id: String) -> bool:
	if prefer_tgap and is_instance_valid(TgapAssetLoader) and TgapAssetLoader.has_pack(pack_id):
		return true
	return packs.has(pack_id)

func list_pack_ids() -> PackedStringArray:
	var unique := {}
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
	if prefer_tgap and is_instance_valid(TgapAssetLoader):
		var resolved := TgapAssetLoader.resolve(pack_id, relative_or_logical_path, expected_version)
		if not resolved.is_empty():
			return resolved
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
	var path := resolve_asset(pack_id, relative_or_logical_path, expected_version)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

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
