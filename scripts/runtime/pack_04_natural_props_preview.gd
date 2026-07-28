extends Node2D

const PACK_ROOT := "res://assets/packs/pack_04_natural_props/runtime/hd"
const SAMPLE_ASSETS := [
    "TM_NATURAL_ROCK_MOSSY_005.png",
    "TM_NATURAL_ROCK_CRYSTAL_013.png",
    "TM_NATURAL_LOG_BRANCHING_001.png",
    "TM_NATURAL_MUSHROOM_SPIRIT_005.png",
    "TM_NATURAL_FORMATION_SPIRES_001.png"
]

const SAMPLE_POSITIONS := [
    Vector2(60, 250),
    Vector2(310, 200),
    Vector2(610, 280),
    Vector2(840, 280),
    Vector2(980, 130)
]

func _ready() -> void:
    _build_preview()

func _build_preview() -> void:
    for index in SAMPLE_ASSETS.size():
        var path := PACK_ROOT.path_join(SAMPLE_ASSETS[index])
        var sprite := Sprite2D.new()
        sprite.position = SAMPLE_POSITIONS[index]
        sprite.centered = false
        sprite.scale = Vector2(0.68, 0.68)
        if ResourceLoader.exists(path):
            sprite.texture = load(path)
        else:
            sprite.texture = _fallback_texture(index)
        add_child(sprite)

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.20 + index * 0.02, 0.22, 0.20, 0.78))
    return ImageTexture.create_from_image(image)
