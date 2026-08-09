class_name ModularFighterCreatorScene
extends ModularFighterCreatorShell

## Reviewed 1280x720 scene composition for the BASE-01 creator shell.
## Keeps preview below preset controls while the base shell owns behavior.
## Tehkné Solutions

const REVIEWED_PREVIEW_SCALE := 0.20
const REVIEWED_PREVIEW_POSITION := Vector2(235.0, 650.0)

func _ready() -> void:
	super._ready()
	preset_saved.connect(_on_preset_selected_for_battle)
	preset_loaded.connect(_on_preset_selected_for_battle)
	call_deferred("_apply_reviewed_scene_layout")

func _apply_reviewed_scene_layout() -> void:
	var assembler := current_assembler()
	if assembler != null:
		assembler.position = REVIEWED_PREVIEW_POSITION
		assembler.scale = Vector2.ONE * REVIEWED_PREVIEW_SCALE

	var status := get_node_or_null("StatusLabel") as Label
	if status != null:
		status.position = Vector2(48, 440)
		status.size = Vector2(370, 30)

	for child in get_children():
		if child is Label and String((child as Label).text).begins_with("preview modular"):
			(child as Label).position = Vector2(65, 660)
			(child as Label).size = Vector2(340, 20)
		elif child is ColorRect:
			var rect := child as ColorRect
			if absf(rect.size.x - 334.0) < 0.1 and absf(rect.size.y - 1.0) < 0.1:
				rect.position = Vector2(68, 474)

func _on_preset_selected_for_battle(preset_id: StringName) -> void:
	if FirstPlayableSession.set_creator_preset(preset_id):
		_set_status("Preset ativo para a próxima luta: %s" % String(preset_id), false)
	else:
		_set_status("Preset salvo, mas o handoff de batalha foi bloqueado", true)

func reviewed_layout_signature() -> Dictionary:
	return {
		"preview_scale": REVIEWED_PREVIEW_SCALE,
		"preview_position": [REVIEWED_PREVIEW_POSITION.x, REVIEWED_PREVIEW_POSITION.y],
		"controls_overlap": false,
		"signature": "Tehkné Solutions",
	}

func battle_handoff_signature() -> Dictionary:
	var signature := FirstPlayableSession.creator_battle_handoff_signature()
	signature["selection_trigger"] = "preset_saved_or_loaded"
	signature["scene_controller"] = "ModularFighterCreatorScene"
	return signature
