extends Node

signal pack_loaded(pack_id: String, manifest: Dictionary)
signal pack_failed(pack_path: String, reason: String)

const PACK_ROOT := "res://assets/packs"
const REQUIRED_PACK_KEYS := ["id", "name", "version", "status", "signature"]

var packs: Dictionary = {}

func _ready() -> void:
    reload_packs()

func reload_packs() -> void:
    packs.clear()
    _scan_pack_directory(PACK_ROOT)

func get_pack(pack_id: String) -> Dictionary:
    return packs.get(pack_id, {})

func has_pack(pack_id: String) -> bool:
    return packs.has(pack_id)

func list_pack_ids() -> PackedStringArray:
    var ids := PackedStringArray()
    for pack_id in packs.keys():
        ids.append(String(pack_id))
    ids.sort()
    return ids

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

    var pack_id := String(manifest["id"])
    packs[pack_id] = manifest
    pack_loaded.emit(pack_id, manifest)
