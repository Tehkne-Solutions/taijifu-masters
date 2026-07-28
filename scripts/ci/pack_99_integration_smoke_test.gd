extends SceneTree

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
    AssetPackRegistry.reload_packs()
    for pack_id in REQUIRED_PACKS:
        assert(AssetPackRegistry.has_pack(pack_id), "%s must be registered" % pack_id)
        var manifest: Dictionary = AssetPackRegistry.get_pack(pack_id)
        assert(String(manifest.get("signature", "")) == "Tehkné Solutions")
        assert(int(manifest.get("asset_count", -1)) == EXPECTED_COUNTS[pack_id])
        for dependency in manifest.get("depends_on", []):
            assert(AssetPackRegistry.has_pack(String(dependency)), "%s dependency missing: %s" % [pack_id, dependency])
    var total := 0
    for pack_id in ["PACK_07", "PACK_08", "PACK_09", "PACK_10"]:
        total += int(AssetPackRegistry.get_pack(pack_id).get("asset_count", 0))
    assert(total == int(AssetPackRegistry.get_pack("PACK_99").get("asset_count", -1)))
    print("PACK 99 integration smoke test passed: %s assets" % total)
    quit(0)
