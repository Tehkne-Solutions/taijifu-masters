extends Node2D

# Bancada visual dos lotes do First Playable.
# Assinatura: Tehkné Solutions

const ANIMATIONS := [
    "idle", "run", "jump_start", "airborne", "fall",
    "attack_light", "guard", "dodge", "hit", "ko"
]
const LIAN_WU_FRAMES := "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres"
const RIVAL_FRAMES := "res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres"

@onready var lian_wu: AnimatedSprite2D = $Stage/LianWu
@onready var rival: AnimatedSprite2D = $Stage/TrainingRival
@onready var animation_picker: OptionButton = $UI/Panel/VBox/AnimationPicker
@onready var status_label: Label = $UI/Panel/VBox/Status
@onready var guides: Node2D = $Stage/Guides

var current_animation := "idle"

func _ready() -> void:
    for animation_name in ANIMATIONS:
        animation_picker.add_item(animation_name)
    animation_picker.item_selected.connect(_on_animation_selected)
    _load_character_frames(lian_wu, LIAN_WU_FRAMES, "Lian Wu")
    _load_character_frames(rival, RIVAL_FRAMES, "Rival de Treino")
    _play_selected_animation()
    _update_status()

func _load_character_frames(target: AnimatedSprite2D, path: String, label: String) -> void:
    if not ResourceLoader.exists(path):
        target.visible = false
        target.set_meta("review_error", "%s: SpriteFrames ausente" % label)
        return
    var frames := load(path) as SpriteFrames
    if frames == null:
        target.visible = false
        target.set_meta("review_error", "%s: recurso inválido" % label)
        return
    target.sprite_frames = frames
    target.visible = true
    target.set_meta("review_error", "")

func _on_animation_selected(index: int) -> void:
    current_animation = animation_picker.get_item_text(index)
    _play_selected_animation()
    _update_status()

func _play_selected_animation() -> void:
    for sprite in [lian_wu, rival]:
        if not sprite.visible or sprite.sprite_frames == null:
            continue
        if sprite.sprite_frames.has_animation(current_animation):
            sprite.play(current_animation)
        else:
            sprite.stop()

func _update_status() -> void:
    var lines: Array[String] = []
    for pair in [["Lian Wu", lian_wu], ["Rival", rival]]:
        var label: String = pair[0]
        var sprite: AnimatedSprite2D = pair[1]
        var error := String(sprite.get_meta("review_error", ""))
        if not error.is_empty():
            lines.append(error)
            continue
        var count := 0
        if sprite.sprite_frames.has_animation(current_animation):
            count = sprite.sprite_frames.get_frame_count(current_animation)
        lines.append("%s — %s: %d frames" % [label, current_animation, count])
    status_label.text = "\n".join(lines)

func _draw() -> void:
    # Linha dos pés e eixo central para inspeção de pivô/escala.
    draw_line(Vector2(120, 500), Vector2(1030, 500), Color(0.85, 0.72, 0.35, 0.8), 2.0)
    draw_line(Vector2(360, 160), Vector2(360, 560), Color(0.35, 0.85, 0.75, 0.45), 1.0)
    draw_line(Vector2(790, 160), Vector2(790, 560), Color(0.85, 0.35, 0.25, 0.45), 1.0)
