extends SceneTree

# Assinatura: Tehkné Solutions

const SCENE_PATH := "res://scenes/vertical_slice/first_playable_visual_review_lab.tscn"
const REQUIRED_ANIMATIONS := [
    "idle", "run", "jump_start", "airborne", "fall",
    "attack_light", "guard", "dodge", "hit", "ko"
]

func _init() -> void:
    var packed := load(SCENE_PATH) as PackedScene
    assert(packed != null, "Cena da bancada visual ausente")
    var lab := packed.instantiate()
    root.add_child(lab)
    await process_frame

    assert(lab.has_node("Stage/LianWu"), "Preview de Lian Wu ausente")
    assert(lab.has_node("Stage/TrainingRival"), "Preview do Rival ausente")
    assert(lab.has_node("UI/Panel/VBox/AnimationPicker"), "Seletor de animações ausente")

    var picker := lab.get_node("UI/Panel/VBox/AnimationPicker") as OptionButton
    assert(picker.item_count == REQUIRED_ANIMATIONS.size(), "Quantidade de animações divergente")
    for index in range(REQUIRED_ANIMATIONS.size()):
        assert(picker.get_item_text(index) == REQUIRED_ANIMATIONS[index], "Ordem de animações divergente")

    var script_text := FileAccess.get_file_as_string("res://scripts/vertical_slice/first_playable_visual_review_lab.gd")
    assert(script_text.contains("lian_wu_first_playable_frames.tres"), "Caminho canônico de Lian Wu ausente")
    assert(script_text.contains("training_rival_first_playable_frames.tres"), "Caminho canônico do Rival ausente")
    assert(script_text.contains("Tehkné Solutions"), "Assinatura ausente")

    print("FIRST_PLAYABLE_VISUAL_REVIEW_LAB_CONTRACT_OK")
    quit(0)
