extends Node2D

const PACK_ROOT := "res://assets/packs/pack_06_resources_interactive/runtime/hd"
const PACK_PIVOT := Vector2(0.5, 0.9)
const SAMPLE_ASSETS := [
    "TM_INTERACTIVE_CHEST_RARE_001.png",
    "TM_INTERACTIVE_ALTAR_SPIRIT_007.png",
    "TM_INTERACTIVE_MINE_CRYSTAL_007.png",
    "TM_INTERACTIVE_FOUNTAIN_HEALING_001.png",
    "TM_INTERACTIVE_PORTAL_MAJOR_001.png",
    "TM_INTERACTIVE_RESOURCE_ESSENCE_007.png"
]

const SAMPLE_POSITIONS := [
    Vector2(140, 560),
    Vector2(350, 560),
    Vector2(570, 560),
    Vector2(790, 560),
    Vector2(1010, 560),
    Vector2(1170, 560)
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
        sprite.texture = load(path) if ResourceLoader.exists(path) else _fallback_texture(index)
        var texture_size := sprite.texture.get_size()
        sprite.offset = -Vector2(texture_size.x * PACK_PIVOT.x, texture_size.y * PACK_PIVOT.y)
        add_child(sprite)

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.14 + index * 0.02, 0.24, 0.22, 0.82))
    return ImageTexture.create_from_image(image)
