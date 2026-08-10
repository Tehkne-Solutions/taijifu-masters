class_name ModularFighterCreatorScene
extends ModularFighterCreatorShell

## Reviewed 1280x720 Character Creator composition.
## BASE-01 identity remains owned by the base shell; BASE-02 Hair, BASE-03
## Uniform and BASE-04 Armor are exposed only through atomic public controls.
## Tehkné Solutions

const REVIEWED_PREVIEW_SCALE := 0.20
const REVIEWED_PREVIEW_POSITION := Vector2(235.0, 650.0)
const ARMOR_CONTROL_POSITION := Vector2(590.0, 38.0)
const ARMOR_CONTROL_SIZE := Vector2(200.0, 42.0)
const UNIFORM_CONTROL_POSITION := Vector2(820.0, 38.0)
const UNIFORM_CONTROL_SIZE := Vector2(200.0, 42.0)
const HAIR_CONTROL_POSITION := Vector2(1040.0, 38.0)
const HAIR_CONTROL_SIZE := Vector2(220.0, 42.0)

var _hair_style_option: OptionButton
var _hair_syncing := false
var _hair_skip_next_state_reassembly := false
var _uniform_set_option: OptionButton
var _uniform_syncing := false
var _uniform_skip_next_state_reassembly := false
var _armor_set_option: OptionButton
var _armor_syncing := false
var _armor_skip_next_state_reassembly := false

func _ready() -> void:
	super._ready()
	preset_saved.connect(_on_preset_selected_for_battle)
	preset_loaded.connect(_on_preset_selected_for_battle)
	creator_state_changed.connect(_on_creator_state_changed_hair)
	creator_state_changed.connect(_on_creator_state_changed_uniform)
	creator_state_changed.connect(_on_creator_state_changed_armor)
	_build_hair_control()
	_build_uniform_control()
	_build_armor_control()
	_sync_hair_control_and_preview()
	_sync_uniform_control_and_preview()
	_sync_armor_control_and_preview()
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
		ModularFighterHairRuntime.set_profile_style(profile, previous)
		ModularFighterHairRuntime.assemble_profile(profile, assembler)
		_sync_hair_option_selection()
		_set_status("Cabelo não aplicado", true)
		return failures

	_sync_hair_option_selection()
	_set_status("Cabelo atualizado: %s" % ModularFighterHairRuntime.style_label(style_id), false)
	_hair_skip_next_state_reassembly = true
	_uniform_skip_next_state_reassembly = true
	_armor_skip_next_state_reassembly = true
	creator_state_changed.emit()
	return failures

func set_uniform_set(set_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null:
		failures.append("creator_uniform_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("creator_uniform_assembler_missing")
		return failures
	if not ModularFighterUniformRuntime.creator_exposure_enabled():
		failures.append("creator_uniform_exposure_blocked")
		return failures
	var available := ModularFighterUniformRuntime.creator_set_ids()
	if not available.has(String(set_id)):
		failures.append("creator_uniform_set_not_production_ready:%s" % String(set_id))
		return failures

	var previous := ModularFighterUniformRuntime.profile_set_id(profile)
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, set_id))
	if failures.is_empty():
		failures.append_array(ModularFighterUniformRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		ModularFighterUniformRuntime.set_profile_set(profile, previous)
		ModularFighterUniformRuntime.assemble_profile(profile, assembler)
		_sync_uniform_option_selection()
		_set_status("Uniforme não aplicado", true)
		return failures

	_sync_uniform_option_selection()
	_set_status("Uniforme atualizado: %s" % ModularFighterUniformRuntime.set_label(set_id), false)
	_uniform_skip_next_state_reassembly = true
	_hair_skip_next_state_reassembly = true
	_armor_skip_next_state_reassembly = true
	creator_state_changed.emit()
	return failures

func set_armor_set(set_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null:
		failures.append("creator_armor_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("creator_armor_assembler_missing")
		return failures
	if not ModularFighterArmorRuntime.creator_exposure_enabled():
		failures.append("creator_armor_exposure_blocked")
		return failures
	var available := ModularFighterArmorRuntime.creator_armor_set_ids()
	if not available.has(String(set_id)):
		failures.append("creator_armor_set_not_production_ready:%s" % String(set_id))
		return failures

	var previous := ModularFighterArmorRuntime.profile_armor_set_id(profile)
	failures.append_array(ModularFighterArmorRuntime.set_profile_armor_set(profile, set_id))
	if failures.is_empty():
		failures.append_array(ModularFighterArmorRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		ModularFighterArmorRuntime.set_profile_armor_set(profile, previous)
		ModularFighterArmorRuntime.assemble_profile(profile, assembler)
		_sync_armor_option_selection()
		_set_status("Armadura não aplicada", true)
		return failures

	_sync_armor_option_selection()
	_set_status("Armadura atualizada: %s" % ModularFighterArmorRuntime.armor_set_label(set_id), false)
	_armor_skip_next_state_reassembly = true
	_uniform_skip_next_state_reassembly = true
	_hair_skip_next_state_reassembly = true
	creator_state_changed.emit()
	return failures

func current_hair_style_id() -> StringName:
	return ModularFighterHairRuntime.profile_style_id(current_profile())

func current_uniform_set_id() -> StringName:
	return ModularFighterUniformRuntime.profile_set_id(current_profile())

func current_armor_set_id() -> StringName:
	return ModularFighterArmorRuntime.profile_armor_set_id(current_profile())

func current_back_accessory_id() -> StringName:
	return ModularFighterArmorRuntime.profile_back_accessory_id(current_profile())

func hair_style_option() -> OptionButton:
	return _hair_style_option

func uniform_set_option() -> OptionButton:
	return _uniform_set_option

func armor_set_option() -> OptionButton:
	return _armor_set_option

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
		"signal_reassembly_guard": true,
		"signature": "Tehkné Solutions",
	}

func uniform_creator_signature() -> Dictionary:
	return {
		"stage": "C67.2",
		"control": "uniform_set",
		"atomic_slots": ["torso_inner", "torso_outer", "arms", "hands", "waist", "legs", "feet"],
		"direct_slot_controls": false,
		"cross_set_piece_mixing": false,
		"production_sets": Array(ModularFighterUniformRuntime.creator_set_ids()),
		"current_set": String(current_uniform_set_id()),
		"live_preview": true,
		"selection_transactional": true,
		"preset_roundtrip": true,
		"battle_handoff": true,
		"signal_reassembly_guard": true,
		"cross_pack_reassembly_guard": true,
		"signature": "Tehkné Solutions",
	}

func armor_creator_signature() -> Dictionary:
	return {
		"stage": "C68.2",
		"control": "armor_set",
		"atomic_slots": ["head_accessory", "shoulders"],
		"direct_slot_controls": false,
		"cross_set_piece_mixing": false,
		"production_sets": Array(ModularFighterArmorRuntime.creator_armor_set_ids()),
		"current_set": String(current_armor_set_id()),
		"back_accessory_control_exposed": false,
		"back_accessory_id": String(current_back_accessory_id()),
		"live_preview": true,
		"selection_transactional": true,
		"preset_roundtrip": true,
		"battle_handoff": true,
		"signal_reassembly_guard": true,
		"cross_pack_reassembly_guard": true,
		"signature": "Tehkné Solutions",
	}

func flow_signature() -> Dictionary:
	var signature := super.flow_signature()
	signature["hair_creator_control"] = true
	signature["hair_selection_unit"] = "hair_style"
	signature["hair_internal_slots"] = ["hair_back", "hair_front"]
	signature["hair_direct_slot_controls"] = false
	signature["hair_style_count"] = ModularFighterHairRuntime.creator_style_ids().size()
	signature["uniform_creator_control"] = true
	signature["uniform_selection_unit"] = "uniform_set"
	signature["uniform_internal_slots"] = ["torso_inner", "torso_outer", "arms", "hands", "waist", "legs", "feet"]
	signature["uniform_direct_slot_controls"] = false
	signature["uniform_cross_set_piece_mixing"] = false
	signature["uniform_set_count"] = ModularFighterUniformRuntime.creator_set_ids().size()
	signature["armor_creator_control"] = true
	signature["armor_selection_unit"] = "armor_set"
	signature["armor_internal_slots"] = ["head_accessory", "shoulders"]
	signature["armor_direct_slot_controls"] = false
	signature["armor_cross_set_piece_mixing"] = false
	signature["armor_set_count"] = ModularFighterArmorRuntime.creator_armor_set_ids().size()
	signature["back_accessory_creator_control"] = false
	return signature

func _build_hair_control() -> void:
	if _hair_style_option != null:
		return
	var label := Label.new()
	label.name = "HairStyleLabel"
	label.position = Vector2(1040, 18)
	label.size = Vector2(220, 20)
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
	_refresh_hair_options()

func _build_uniform_control() -> void:
	if _uniform_set_option != null:
		return
	var label := Label.new()
	label.name = "UniformSetLabel"
	label.position = Vector2(820, 18)
	label.size = Vector2(200, 20)
	label.text = "UNIFORME • BASE-03"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("aaa397"))
	add_child(label)
	_uniform_set_option = OptionButton.new()
	_uniform_set_option.name = "UniformSetOption"
	_uniform_set_option.position = UNIFORM_CONTROL_POSITION
	_uniform_set_option.size = UNIFORM_CONTROL_SIZE
	_uniform_set_option.focus_mode = Control.FOCUS_ALL
	_uniform_set_option.item_selected.connect(_on_uniform_set_selected)
	_style_option_button(_uniform_set_option)
	add_child(_uniform_set_option)
	_refresh_uniform_options()

func _build_armor_control() -> void:
	if _armor_set_option != null:
		return
	var label := Label.new()
	label.name = "ArmorSetLabel"
	label.position = Vector2(590, 18)
	label.size = Vector2(200, 20)
	label.text = "ARMADURA • BASE-04"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("aaa397"))
	add_child(label)
	_armor_set_option = OptionButton.new()
	_armor_set_option.name = "ArmorSetOption"
	_armor_set_option.position = ARMOR_CONTROL_POSITION
	_armor_set_option.size = ARMOR_CONTROL_SIZE
	_armor_set_option.focus_mode = Control.FOCUS_ALL
	_armor_set_option.item_selected.connect(_on_armor_set_selected)
	_style_option_button(_armor_set_option)
	add_child(_armor_set_option)
	for child in get_children():
		if child is Label and String((child as Label).text).begins_with("BASE-01"):
			var subtitle := child as Label
			subtitle.text = "BASE-01→04 • identidade • cabelo • uniforme • armadura • presets"
			subtitle.size = Vector2(540, 28)
			break
	_refresh_armor_options()

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

func _refresh_uniform_options() -> void:
	if _uniform_set_option == null:
		return
	_uniform_syncing = true
	_uniform_set_option.clear()
	var sets := ModularFighterUniformRuntime.creator_set_ids()
	for set_text in sets:
		var set_id := StringName(set_text)
		_uniform_set_option.add_item(ModularFighterUniformRuntime.set_label(set_id))
		_uniform_set_option.set_item_metadata(_uniform_set_option.item_count - 1, String(set_id))
	_uniform_set_option.disabled = sets.is_empty()
	_sync_uniform_option_selection()
	_uniform_syncing = false

func _refresh_armor_options() -> void:
	if _armor_set_option == null:
		return
	_armor_syncing = true
	_armor_set_option.clear()
	var sets := ModularFighterArmorRuntime.creator_armor_set_ids()
	for set_text in sets:
		var set_id := StringName(set_text)
		_armor_set_option.add_item(ModularFighterArmorRuntime.armor_set_label(set_id))
		_armor_set_option.set_item_metadata(_armor_set_option.item_count - 1, String(set_id))
	_armor_set_option.disabled = sets.is_empty()
	_sync_armor_option_selection()
	_armor_syncing = false

func _sync_hair_option_selection() -> void:
	if _hair_style_option == null:
		return
	var style_id := String(current_hair_style_id())
	for index in range(_hair_style_option.item_count):
		if String(_hair_style_option.get_item_metadata(index)) == style_id:
			_hair_style_option.select(index)
			return

func _sync_uniform_option_selection() -> void:
	if _uniform_set_option == null:
		return
	var set_id := String(current_uniform_set_id())
	for index in range(_uniform_set_option.item_count):
		if String(_uniform_set_option.get_item_metadata(index)) == set_id:
			_uniform_set_option.select(index)
			return

func _sync_armor_option_selection() -> void:
	if _armor_set_option == null:
		return
	var set_id := String(current_armor_set_id())
	for index in range(_armor_set_option.item_count):
		if String(_armor_set_option.get_item_metadata(index)) == set_id:
			_armor_set_option.select(index)
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

func _sync_uniform_control_and_preview() -> void:
	if _uniform_syncing:
		return
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null or assembler == null or not assembler.is_ready_for_render():
		return
	var set_failures := ModularFighterUniformRuntime.validate_profile_set(profile)
	if not set_failures.is_empty():
		_set_status("Preset contém combinação de uniforme inválida", true)
		return
	var failures := ModularFighterUniformRuntime.assemble_profile(profile, assembler)
	if not failures.is_empty():
		_set_status("Uniforme do preset não pôde ser montado", true)
		return
	_refresh_uniform_options()

func _sync_armor_control_and_preview() -> void:
	if _armor_syncing:
		return
	var profile := current_profile()
	var assembler := current_assembler()
	if profile == null or assembler == null or not assembler.is_ready_for_render():
		return
	var set_failures := ModularFighterArmorRuntime.validate_profile(profile)
	if not set_failures.is_empty():
		_set_status("Preset contém combinação de armadura inválida", true)
		return
	var failures := ModularFighterArmorRuntime.assemble_profile(profile, assembler)
	if not failures.is_empty():
		_set_status("Armadura do preset não pôde ser montada", true)
		return
	_refresh_armor_options()

func _on_hair_style_selected(index: int) -> void:
	if _hair_syncing or _hair_style_option == null:
		return
	if index < 0 or index >= _hair_style_option.item_count:
		return
	var style_id := StringName(String(_hair_style_option.get_item_metadata(index)))
	set_hair_style(style_id)

func _on_uniform_set_selected(index: int) -> void:
	if _uniform_syncing or _uniform_set_option == null:
		return
	if index < 0 or index >= _uniform_set_option.item_count:
		return
	var set_id := StringName(String(_uniform_set_option.get_item_metadata(index)))
	set_uniform_set(set_id)

func _on_armor_set_selected(index: int) -> void:
	if _armor_syncing or _armor_set_option == null:
		return
	if index < 0 or index >= _armor_set_option.item_count:
		return
	var set_id := StringName(String(_armor_set_option.get_item_metadata(index)))
	set_armor_set(set_id)

func _on_creator_state_changed_hair() -> void:
	if _hair_skip_next_state_reassembly:
		_hair_skip_next_state_reassembly = false
		_sync_hair_option_selection()
		return
	_sync_hair_control_and_preview()

func _on_creator_state_changed_uniform() -> void:
	if _uniform_skip_next_state_reassembly:
		_uniform_skip_next_state_reassembly = false
		_sync_uniform_option_selection()
		return
	_sync_uniform_control_and_preview()

func _on_creator_state_changed_armor() -> void:
	if _armor_skip_next_state_reassembly:
		_armor_skip_next_state_reassembly = false
		_sync_armor_option_selection()
		return
	_sync_armor_control_and_preview()

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
	var controls_overlap := false
	if _armor_set_option != null and _uniform_set_option != null and _hair_style_option != null:
		var armor_rect := Rect2(_armor_set_option.position, _armor_set_option.size)
		var uniform_rect := Rect2(_uniform_set_option.position, _uniform_set_option.size)
		var hair_rect := Rect2(_hair_style_option.position, _hair_style_option.size)
		controls_overlap = armor_rect.intersects(uniform_rect) or armor_rect.intersects(hair_rect) or uniform_rect.intersects(hair_rect)
	return {
		"preview_scale": REVIEWED_PREVIEW_SCALE,
		"preview_position": [REVIEWED_PREVIEW_POSITION.x, REVIEWED_PREVIEW_POSITION.y],
		"controls_overlap": controls_overlap,
		"armor_control_position": [ARMOR_CONTROL_POSITION.x, ARMOR_CONTROL_POSITION.y],
		"armor_control_size": [ARMOR_CONTROL_SIZE.x, ARMOR_CONTROL_SIZE.y],
		"uniform_control_position": [UNIFORM_CONTROL_POSITION.x, UNIFORM_CONTROL_POSITION.y],
		"uniform_control_size": [UNIFORM_CONTROL_SIZE.x, UNIFORM_CONTROL_SIZE.y],
		"hair_control_position": [HAIR_CONTROL_POSITION.x, HAIR_CONTROL_POSITION.y],
		"hair_control_size": [HAIR_CONTROL_SIZE.x, HAIR_CONTROL_SIZE.y],
		"signature": "Tehkné Solutions",
	}

func battle_handoff_signature() -> Dictionary:
	var signature := FirstPlayableSession.creator_battle_handoff_signature()
	signature["selection_trigger"] = "preset_saved_or_loaded"
	signature["scene_controller"] = "ModularFighterCreatorScene"
	signature["hair_style_id"] = String(current_hair_style_id())
	signature["uniform_set_id"] = String(current_uniform_set_id())
	signature["armor_set_id"] = String(current_armor_set_id())
	signature["back_accessory_id"] = String(current_back_accessory_id())
	return signature

# Tehkné Solutions
