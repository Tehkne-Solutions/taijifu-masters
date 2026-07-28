extends Node2D

const PACK_ROOT := "res://assets/packs/pack_05_structures_buildings/runtime/hd"
const SAMPLE_ASSETS := [
    "TM_STRUCTURE_HOUSE_VILLAGE_RED_001.png",
    "TM_STRUCTURE_TOWER_WATCH_001.png",
    "TM_STRUCTURE_TEMPLE_PORTAL_001.png",
    "TM_STRUCTURE_BRIDGE_STONE_001.png",
    "TM_STRUCTURE_RUIN_ARCH_001.png"
]

const SAMPLE_POSITIONS := [
    Vector2(20, 220),
    Vector2(270, 120),
    Vector2(520, 120),
    Vector2(760, 300),
    Vector2(930, 200)
]

func _ready() -> void:
    _build_preview()

func _build_preview() -> void:
    for index in SAMPLE_ASSETS.size():
        var sprite := Sprite2D.new()
        sprite.position = SAMPLE_POSITIONS[index]
        sprite.centered = false
        sprite.scale = Vector2(0.68, 0.68)
        var path := PACK_ROOT.path_join(SAMPLE_ASSETS[index])
        if ResourceLoader.exists(path):
            sprite.texture = load(path)
        else:
            sprite.texture = _fallback_texture(index)
        add_child(sprite)

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.25 + index * 0.02, 0.22, 0.16, 0.82))
    return ImageTexture.create_from_image(image)
