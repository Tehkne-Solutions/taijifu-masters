extends Node2D

const PACK_ROOT := "res://assets/packs/pack_05_structures_buildings/runtime/hd"
const PACK_PIVOT := Vector2(0.5, 0.92)
const SAMPLE_ASSETS := [
    "TM_STRUCTURE_HOUSE_VILLAGE_RED_001.png",
    "TM_STRUCTURE_TOWER_WATCH_001.png",
    "TM_STRUCTURE_TEMPLE_PORTAL_001.png",
    "TM_STRUCTURE_BRIDGE_STONE_001.png",
    "TM_STRUCTURE_RUIN_ARCH_001.png",
    "TM_STRUCTURE_GATE_SPIRIT_001.png"
]

const SAMPLE_POSITIONS := [
    Vector2(170, 560),
    Vector2(390, 560),
    Vector2(610, 560),
    Vector2(820, 560),
    Vector2(1020, 560),
    Vector2(1180, 560)
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
        var texture_size := sprite.texture.get_size()
        sprite.offset = -Vector2(texture_size.x * PACK_PIVOT.x, texture_size.y * PACK_PIVOT.y)
        add_child(sprite)

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.25 + index * 0.02, 0.22, 0.16, 0.82))
    return ImageTexture.create_from_image(image)
