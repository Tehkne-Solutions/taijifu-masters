extends Node2D

const TILE_SIZE := 256
const GRID_SIZE := Vector2i(5, 4)
const TILE_IDS := [
    "TM_TERRAIN_GRASS_BASE_001",
    "TM_TERRAIN_GRASS_BASE_002",
    "TM_TERRAIN_GRASS_BASE_003"
]

var loaded_textures: Array[Texture2D] = []

func _ready() -> void:
    _load_grass_tiles()
    queue_redraw()

func _load_grass_tiles() -> void:
    loaded_textures.clear()
    for tile_id in TILE_IDS:
        var path := "res://assets/packs/pack_01_terrain_core/runtime/mobile/grass/%s.webp" % tile_id
        if not ResourceLoader.exists(path):
            push_warning("Tile ausente: %s" % path)
            continue
        var texture := load(path) as Texture2D
        if texture != null:
            loaded_textures.append(texture)

func _draw() -> void:
    if loaded_textures.is_empty():
        _draw_missing_state()
        return

    for y in range(GRID_SIZE.y):
        for x in range(GRID_SIZE.x):
            var texture := loaded_textures[(x + y) % loaded_textures.size()]
            draw_texture_rect(
                texture,
                Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
                false
            )

func _draw_missing_state() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(GRID_SIZE) * TILE_SIZE), Color("17202a"), true)
    draw_string(
        ThemeDB.fallback_font,
        Vector2(40, 80),
        "Importe os arquivos WebP do PACK 01 para visualizar os tiles.",
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        24,
        Color("f4d77d")
    )

# Assinatura: Tehkné Solutions
