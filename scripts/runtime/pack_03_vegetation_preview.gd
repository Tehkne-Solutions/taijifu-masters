extends Node2D

const PACK_ROOT := "res://assets/packs/pack_03_vegetation/runtime/hd"
const SAMPLE_ASSETS := [
    "TM_VEGETATION_TREE_OAK_GREEN_001.png",
    "TM_VEGETATION_TREE_SAKURA_013.png",
    "TM_VEGETATION_TREE_PINE_DARK_009.png",
    "TM_VEGETATION_BUSH_FLOWERING_005.png",
    "TM_VEGETATION_GRASS_TALL_001.png",
    "TM_VEGETATION_FLOWERS_COOL_001.png",
    "TM_VEGETATION_REEDS_WATER_001.png"
]

const SAMPLE_POSITIONS := [
    Vector2(70, 120),
    Vector2(350, 90),
    Vector2(760, 110),
    Vector2(610, 320),
    Vector2(180, 390),
    Vector2(430, 420),
    Vector2(900, 390)
]

func _ready() -> void:
    _build_preview()

func _build_preview() -> void:
    for index in SAMPLE_ASSETS.size():
        var path := PACK_ROOT.path_join(SAMPLE_ASSETS[index])
        var sprite := Sprite2D.new()
        sprite.position = SAMPLE_POSITIONS[index]
        sprite.centered = false
        sprite.scale = Vector2(0.7, 0.7)
        if ResourceLoader.exists(path):
            sprite.texture = load(path)
        else:
            sprite.texture = _fallback_texture(index)
        add_child(sprite)

func _fallback_texture(index: int) -> Texture2D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.12, 0.24 + index * 0.015, 0.14, 0.75))
    return ImageTexture.create_from_image(image)
