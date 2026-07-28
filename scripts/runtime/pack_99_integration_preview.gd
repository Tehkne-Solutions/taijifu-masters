extends Node2D

const REQUIRED_PACKS := ["PACK_07", "PACK_08", "PACK_09", "PACK_10", "PACK_99"]
const SAMPLE_ASSETS := {
    "PACK_07": "res://assets/packs/pack_07_heroes_masters/runtime/hd/TM_HERO_WARDEN_SE_BASE_003.png",
    "PACK_08": "res://assets/packs/pack_08_units_champions/runtime/hd/TM_UNIT_SOLDIER_SE_002.png",
    "PACK_09": "res://assets/packs/pack_09_combat_vfx_skills/runtime/hd/TM_VFX_IMPACT_CRITICAL_003.png",
    "PACK_10": "res://assets/packs/pack_10_ui_hud_tcg/runtime/hd/TM_UI_PANEL_BATTLE_001.png"
}

const SAMPLE_POSITIONS := {
    "PACK_07": Vector2(180, 560),
    "PACK_08": Vector2(450, 560),
    "PACK_09": Vector2(760, 420),
    "PACK_10": Vector2(1050, 390)
}

var validation_report: Dictionary = {}

func _ready() -> void:
    validation_report = validate_integration()
    _build_preview()

func validate_integration() -> Dictionary:
    var report := {
        "packs": {},
        "all_registered": true,
        "dependencies_valid": true,
        "binary_assets_available": true
    }
    for pack_id in REQUIRED_PACKS:
        var registered := AssetPackRegistry.has_pack(pack_id)
        report["packs"][pack_id] = {"registered": registered}
        if not registered:
            report["all_registered"] = false
            continue
        var manifest: Dictionary = AssetPackRegistry.get_pack(pack_id)
        for dependency in manifest.get("depends_on", []):
            if not AssetPackRegistry.has_pack(String(dependency)):
                report["dependencies_valid"] = false
                report["packs"][pack_id]["missing_dependency"] = dependency
    for pack_id in SAMPLE_ASSETS:
        var asset_path: String = SAMPLE_ASSETS[pack_id]
        var available := ResourceLoader.exists(asset_path)
        report["packs"][pack_id]["sample_available"] = available
        if not available:
            report["binary_assets_available"] = false
    return report

func _build_preview() -> void:
    var index := 0
    for pack_id in SAMPLE_ASSETS:
        var sprite := Sprite2D.new()
        sprite.position = SAMPLE_POSITIONS[pack_id]
        sprite.scale = Vector2(0.55, 0.55)
        var asset_path: String = SAMPLE_ASSETS[pack_id]
        sprite.texture = load(asset_path) if ResourceLoader.exists(asset_path) else _fallback_texture(index)
        add_child(sprite)
        index += 1

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(320, 320, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.16 + index * 0.035, 0.19, 0.24 + index * 0.025, 0.94))
    return ImageTexture.create_from_image(image)
