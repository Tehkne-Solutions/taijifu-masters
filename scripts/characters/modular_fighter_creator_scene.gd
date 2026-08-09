class_name ModularFighterCreatorScene
extends ModularFighterCreatorShell

## Reviewed 1280x720 Character Creator composition.
## BASE-01 identity remains owned by the base shell; BASE-02 Hair is exposed here
## as one atomic hairstyle control, never as direct hair_back/hair_front slots.
## Tehkné Solutions

const REVIEWED_PREVIEW_SCALE := 0.20
const REVIEWED_PREVIEW_POSITION := Vector2(235.0, 650.0)
const HAIR_CONTROL_POSITION := Vector2(930.0, 38.0)
const HAIR_CONTROL_SIZE := Vector2(310.0, 42.0)

var _hair_style_option: OptionButton
var _hair_syncing := false

func _ready() -> void:
	super._ready()
	preset_saved.connect(_on_preset_selected_for_battle)
	preset_loaded.connect(_on_preset_selected_for_battle)
	creator_state_changed.connect(_on_creator_state_changed_hair)
	_build_hair_control()
	_sync_hair_control_and_preview()
	call_deferred("_apply_reviewed_scene_layout")

func set_hair_style(style_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null:
		failures.append("creator_hair_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("creator_hair_assembler_missing")
		return failures
	if not ModularFighterHairRuntime.creator_exposure_enabled():
		failures.append("creator_hair_exposure_blocked")
		return failures
	var available := ModularFighterHairRuntime.creator_style_ids()
	if not available.has(String(style_id)):
		failures.append("creator_hair_style_not_production_ready:%s" % String(style_id))
		return failures

	var previous := ModularFighterHairRuntime.profile_style_id(profile)
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, style_id))
	if failures.is_empty():
		failures.append_array(ModularFighterHairRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		# Keep Creator state transactional: restore both profile slots and preview.
		ModularFighterHairRuntime.set_profile_style(profile, previous)
		ModularFighterHairRuntime.assemble_profile(profile, assembler)
		_sync_hair_option_selection()
		_set_status("Cabelo não aplicado", true)
		return failures

	_sync_hair_option_selection()
	_set_status("Cabelo atualizado: %s" % ModularFighterHairRuntime.style_label(style_id), false)
	creator_state_changed.emit()
	return failures

func current_hair_style_id() -> StringName:
	return ModularFighterHairRuntime.profile_style_id(current_profile())

func hair_style_option() -> OptionButton:
	return _hair_style_option

func hair_creator_signature() -> Dictionary:
	return {
		"stage": "C66.2",
		"control": "hair_style",
		"atomic_slots": ["hair_back", "hair_front"],
		"direct_slot_controls": false,
		"production_styles": Array(ModularFighterHairRuntime.creator_style_ids()),
		"current_style": String(current_hair_style_id()),
		"live_preview": true,
		"preset_roundtrip": true,
		"battle_handoff": true,
		"signature": "Tehkné Solutions",
	}

func flow_signature() -> Dictionary:
	var signature := super.flow_signature()
	# Preserve every historical BASE-01 key and append the C66.2 surface.
	signature["hair_creator_control"] = true
	signature["hair_selection_unit"] = "hair_style"
	signature["hair_internal_slots"] = ["hair_back", "hair_front"]
	signature["hair_direct_slot_controls"] = false
	signature["hair_style_count"] = ModularFighterHairRuntime.creator_style_ids().size()
	return signature

func _build_hair_control() -> void:
	if _hair_style_option != null:
		return

	var label := Label.new()
	label.name = "HairStyleLabel"
	label.position = Vector2(930, 18)
	label.size = Vector2(310, 20)
	label.text = "CABELO • BASE-02"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("aaa397"))
	add_child(label)

	_hair_style_option = OptionButton.new()
	_hair_style_option.name = "HairStyleOption"
	_hair_style_option.position = HAIR_CONTROL_POSITION
	_hair_style_option.size = HAIR_CONTROL_SIZE
	_hair_style_option.focus_mode = Control.FOCUS_ALL
	_hair_style_option.item_selected.connect(_on_hair_style_selected)
	_style_option_button(_hair_style_option)
	add_child(_hair_style_option)

	for child in get_children():
		if child is Label and String((child as Label).text).begins_with("BASE-01 •"):
			(child as Label).text = "BASE-01 + BASE-02 • identidade modular • cabelo • preview ao vivo • presets locais"
			break
	_refresh_hair_options()

func _refresh_hair_options() -> void:
	if _hair_style_option == null:
		return
	_hair_syncing = true
	_hair_style_option.clear()
	var styles := ModularFighterHairRuntime.creator_style_ids()
	for style_text in styles:
		var style_id := StringName(style_text)
		_hair_style_option.add_item(ModularFighterHairRuntime.style_label(style_id))
		_hair_style_option.set_item_metadata(_hair_style_option.item_count - 1, String(style_id))
	_hair_style_option.disabled = styles.is_empty()
	_sync_hair_option_selection()
	_hair_syncing = false

func _sync_hair_option_selection() -> void:
	if _hair_style_option == null:
		return
	var style_id := String(current_hair_style_id())
	for index in range(_hair_style_option.item_count):
		if String(_hair_style_option.get_item_metadata(index)) == style_id:
			_hair_style_option.select(index)
			return

func _sync_hair_control_and_preview() -> void:
	if _hair_syncing:
		return
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null or assembler == null or not assembler.is_ready_for_render():
		return
	var pair_failures := ModularFighterHairRuntime.validate_profile_pair(profile)
	if not pair_failures.is_empty():
		_set_status("Preset contém combinação de cabelo inválida", true)
		return
	var failures := ModularFighterHairRuntime.assemble_profile(profile, assembler)
	if not failures.is_empty():
		_set_status("Cabelo do preset não pôde ser montado", true)
		return
	_refresh_hair_options()

func _on_hair_style_selected(index: int) -> void:
	if _hair_syncing or _hair_style_option == null:
		return
	if index < 0 or index >= _hair_style_option.item_count:
		return
	var style_id := StringName(String(_hair_style_option.get_item_metadata(index)))
	set_hair_style(style_id)

func _on_creator_state_changed_hair() -> void:
	_sync_hair_control_and_preview()

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
		"hair_control_position": [HAIR_CONTROL_POSITION.x, HAIR_CONTROL_POSITION.y],
		"hair_control_size": [HAIR_CONTROL_SIZE.x, HAIR_CONTROL_SIZE.y],
		"signature": "Tehkné Solutions",
	}

func battle_handoff_signature() -> Dictionary:
	var signature := FirstPlayableSession.creator_battle_handoff_signature()
	signature["selection_trigger"] = "preset_saved_or_loaded"
	signature["scene_controller"] = "ModularFighterCreatorScene"
	signature["hair_style_id"] = String(current_hair_style_id())
	return signature
