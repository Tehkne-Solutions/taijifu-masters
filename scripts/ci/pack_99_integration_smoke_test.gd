extends SceneTree

const LEGACY_REGISTRY_SCRIPT := preload("res://scripts/runtime/asset_pack_registry.gd")
const REQUIRED_PACKS := ["PACK_07", "PACK_08", "PACK_09", "PACK_10", "PACK_99"]
const EXPECTED_COUNTS := {
    "PACK_07": 48,
    "PACK_08": 40,
    "PACK_09": 58,
    "PACK_10": 60,
    "PACK_99": 206
}

func _initialize() -> void:
    await process_frame
    var registry := _legacy_registry()
    for pack_id in REQUIRED_PACKS:
        assert(registry.has_pack(pack_id), "%s must be registered" % pack_id)
        var manifest: Dictionary = registry.get_pack(pack_id)
        assert(String(manifest.get("signature", "")) == "Tehkné Solutions")
        assert(int(manifest.get("asset_count", -1)) == EXPECTED_COUNTS[pack_id])
        for dependency in manifest.get("depends_on", []):
            assert(registry.has_pack(String(dependency)), "%s dependency missing: %s" % [pack_id, dependency])
    var total := 0
    for pack_id in ["PACK_07", "PACK_08", "PACK_09", "PACK_10"]:
        total += int(registry.get_pack(pack_id).get("asset_count", 0))
    assert(total == int(registry.get_pack("PACK_99").get("asset_count", -1)))
    registry.free()
    print("PACK 99 integration smoke test passed: %s assets" % total)
    quit(0)

func _legacy_registry() -> Node:
    var registry := LEGACY_REGISTRY_SCRIPT.new()
    registry.legacy_adapter_enabled = true
    registry.scan_legacy_packs = true
    registry.reload_packs()
    return registry
