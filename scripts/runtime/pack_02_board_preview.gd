extends Node2D

const PACK_ROOT := "res://assets/packs/pack_02_board_system/runtime/hd"
const TILE_SIZE := 256.0

var board_assets := [
    "TM_BOARD_PATH_STRAIGHT_EW_002.png",
    "TM_BOARD_PATH_CROSS_011.png",
    "TM_BOARD_ZONE_CAPTURE_CIRCLE_003.png",
    "TM_BOARD_SOCKET_OBJECTIVE_007.png",
    "TM_BOARD_INDICATOR_ARROW_E_002.png"
]

func _ready() -> void:
    _build_preview()

func _build_preview() -> void:
    for child in get_children():
        child.queue_free()

    var positions := [
        Vector2(128, 256),
        Vector2(384, 256),
        Vector2(384, 256),
        Vector2(384, 256),
        Vector2(640, 256)
    ]

    for index in board_assets.size():
        var path := PACK_ROOT.path_join(board_assets[index])
        if not ResourceLoader.exists(path):
            push_warning("PACK 02 asset ausente: %s" % path)
            continue

        var texture := load(path) as Texture2D
        if texture == null:
            push_warning("PACK 02 asset inválido: %s" % path)
            continue

        var sprite := Sprite2D.new()
        sprite.texture = texture
        sprite.position = positions[index]
        sprite.scale = Vector2(TILE_SIZE / texture.get_width(), TILE_SIZE / texture.get_height())
        sprite.z_index = index + 10
        add_child(sprite)
