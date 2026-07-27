class_name BattlePreparationRuntime
extends Node

signal start_requested

@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

var _battle_ledger := BattleLoadoutLedger.new()
var _cosmetic_ledger := CosmeticLoadoutLedger.new()
var _loadouts: Array[Dictionary] = [{}, {}]
var _field_indices: Array[int] = [0, 0]
var _active := false
var _canvas: CanvasLayer
var _background: ColorRect
var _title: Label
var _footer: Label
var _player_titles: Array[Label] = []
var _player_roles: Array[Label] = []
var _player_previews: Array[TextureRect] = []
var _player_stats: Array[Label] = []
var _player_fields: Array[RichTextLabel] = []
var _player_summaries: Array[Label] = []
var _preview_atlases: Array[AtlasTexture] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cosmetic_ledger.load_from_disk()
	var unlocked := _unlocked_by_profile()
	_battle_ledger.load_from_disk(unlocked)
	for player_index in [1, 2]:
		_loadouts[player_index - 1] = _battle_ledger.loadout_for(player_index, unlocked.get("p%d" % player_index, []))
	_build_interface()
	_sync_all_ledgers()
	_refresh()

func open() -> void:
	_active = true
	_canvas.visible = true
	_refresh()

func close() -> void:
	_active = false
	_canvas.visible = false
	_sync_all_ledgers()

func is_active() -> bool:
	return _active

func loadout_for_player(player_index: int) -> Dictionary:
	var slot := clampi(player_index, 1, 2) - 1
	var unlocked := _unlocked_for(player_index)
	return BattleLoadoutCatalog.sanitize(_loadouts[slot], unlocked)

func set_loadout_for_test(player_index: int, loadout: Dictionary) -> void:
	var slot := clampi(player_index, 1, 2) - 1
	_loadouts[slot] = BattleLoadoutCatalog.sanitize(loadout, _unlocked_for(player_index))
	_persist_player(player_index)
	_refresh()

func selected_field_for_player(player_index: int) -> StringName:
	return BattleLoadoutCatalog.FIELD_ORDER[_field_indices[clampi(player_index, 1, 2) - 1]]

func _unhandled_input(event: InputEvent) -> void:
	if not _active or event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_W: _cycle_field(1, -1)
		KEY_S: _cycle_field(1, 1)
		KEY_A: _cycle_value(1, -1)
		KEY_D: _cycle_value(1, 1)
		KEY_UP: _cycle_field(2, -1)
		KEY_DOWN: _cycle_field(2, 1)
		KEY_LEFT: _cycle_value(2, -1)
		KEY_RIGHT: _cycle_value(2, 1)
		KEY_1: _reset_player(1)
		KEY_2: _reset_player(2)
		KEY_ENTER, KEY_KP_ENTER:
			_sync_all_ledgers()
			start_requested.emit()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _cycle_field(player_index: int, direction: int) -> void:
	var slot := player_index - 1
	_field_indices[slot] = wrapi(_field_indices[slot] + direction, 0, BattleLoadoutCatalog.FIELD_ORDER.size())
	_refresh_player(player_index)

func _cycle_value(player_index: int, direction: int) -> void:
	var slot := player_index - 1
	var field_id := BattleLoadoutCatalog.FIELD_ORDER[_field_indices[slot]]
	var unlocked := _unlocked_for(player_index)
	var options := BattleLoadoutCatalog.options_for(field_id, _loadouts[slot], unlocked)
	if options.is_empty():
		return
	var current := BattleLoadoutCatalog.value_for_field(field_id, _loadouts[slot])
	var index := options.find(current)
	if index < 0:
		index = 0
	var next_id := options[wrapi(index + direction, 0, options.size())]
	_loadouts[slot] = BattleLoadoutCatalog.set_field(_loadouts[slot], field_id, next_id, unlocked)
	_persist_player(player_index)
	_refresh_player(player_index)

func _reset_player(player_index: int) -> void:
	_loadouts[player_index - 1] = BattleLoadoutCatalog.default_loadout(player_index)
	_field_indices[player_index - 1] = 0
	_persist_player(player_index)
	_refresh_player(player_index)

func _persist_player(player_index: int) -> void:
	var slot := player_index - 1
	var profile_id := "p%d" % player_index
	var unlocked := _unlocked_for(player_index)
	_loadouts[slot] = _battle_ledger.set_loadout(player_index, _loadouts[slot], unlocked)
	var variant_id := StringName(_loadouts[slot].get("variant_id", &""))
	master_training_runtime.ledger.set_selected_variant(profile_id, variant_id)
	var cosmetic_loadout := {}
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		cosmetic_loadout[String(socket_id)] = String(_loadouts[slot].get(String(socket_id), &"none"))
	_cosmetic_ledger.set_loadout(profile_id, cosmetic_loadout)
	_battle_ledger.save_to_disk()
	master_training_runtime.ledger.save_to_disk()
	_cosmetic_ledger.save_to_disk()

func _sync_all_ledgers() -> void:
	_persist_player(1)
	_persist_player(2)

func _unlocked_for(player_index: int) -> Array:
	return master_training_runtime.ledger.unlocked_variants("p%d" % player_index)

func _unlocked_by_profile() -> Dictionary:
	return {
		"p1": master_training_runtime.ledger.unlocked_variants("p1"),
		"p2": master_training_runtime.ledger.unlocked_variants("p2")
	}

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 210
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.012, 0.018, 0.032, 0.985)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_background)
	var header := ColorRect.new()
	header.offset_right = 1280.0
	header.offset_bottom = 86.0
	header.color = Color(0.035, 0.065, 0.105, 0.98)
	_background.add_child(header)
	_title = Label.new()
	_title.offset_left = 20.0
	_title.offset_top = 12.0
	_title.offset_right = 1260.0
	_title.offset_bottom = 72.0
	_title.text = "PREPARAÇÃO COMPLETA • TAIJIFU MASTERS\nMONTE SUA ESTRATÉGIA ANTES DO PRIMEIRO GOLPE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	header.add_child(_title)
	for slot in range(2):
		_build_player_panel(slot + 1, 30.0 + slot * 630.0)
	_footer = Label.new()
	_footer.offset_left = 20.0
	_footer.offset_top = 672.0
	_footer.offset_right = 1260.0
	_footer.offset_bottom = 716.0
	_footer.text = "P1: W/S categoria • A/D opção • 1 restaurar    |    P2: ↑/↓ categoria • ←/→ opção • 2 restaurar    |    ENTER iniciar"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	_background.add_child(_footer)
	_canvas.visible = false

func _build_player_panel(player_index: int, left: float) -> void:
	var panel := PanelContainer.new()
	panel.offset_left = left
	panel.offset_top = 104.0
	panel.offset_right = left + 590.0
	panel.offset_bottom = 660.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.070, 0.96)
	style.border_color = Color(0.28, 0.67, 0.95, 0.9) if player_index == 1 else Color(1.0, 0.42, 0.26, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	_background.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 5)
	margin.add_child(root_column)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.66, 0.87, 1.0) if player_index == 1 else Color(1.0, 0.70, 0.60))
	root_column.add_child(title)
	_player_titles.append(title)
	var role := Label.new()
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 13)
	role.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	root_column.add_child(role)
	_player_roles.append(role)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	root_column.add_child(middle)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(218.0, 218.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	middle.add_child(preview)
	_player_previews.append(preview)
	_preview_atlases.append(AtlasTexture.new())
	var fields := RichTextLabel.new()
	fields.custom_minimum_size = Vector2(320.0, 218.0)
	fields.bbcode_enabled = true
	fields.fit_content = false
	fields.scroll_active = false
	fields.add_theme_font_size_override("normal_font_size", 12)
	fields.add_theme_font_size_override("bold_font_size", 13)
	middle.add_child(fields)
	_player_fields.append(fields)
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.94, 0.82, 0.48))
	root_column.add_child(stats)
	_player_stats.append(stats)
	var summary := Label.new()
	summary.custom_minimum_size = Vector2(0.0, 62.0)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color(0.75, 0.80, 0.89))
	root_column.add_child(summary)
	_player_summaries.append(summary)

func _refresh() -> void:
	_refresh_player(1)
	_refresh_player(2)

func _refresh_player(player_index: int) -> void:
	if _player_titles.size() < player_index:
		return
	var slot := player_index - 1
	var loadout := loadout_for_player(player_index)
	_loadouts[slot] = loadout
	var character_id := StringName(loadout.get("character_id", &"kael"))
	var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
	var build := BuildProfile.prototype_preset(preset_id)
	_player_titles[slot].text = "P%d — %s" % [player_index, build.character_name.to_upper()]
	_player_roles[slot].text = CharacterVisualCatalog.role(character_id).to_upper()
	_player_stats[slot].text = "TAI %d   JI %d   FU %d   •   VIDA %d   POSTURA %d" % [
		roundi(build.tai_index()), roundi(build.ji_index()), roundi(build.fu_index()),
		roundi(build.max_health()), roundi(build.max_posture())
	]
	_player_summaries[slot].text = "%s\n%s / %s • %s" % [
		build.tactical_summary,
		WeaponKitCatalog.label_for(StringName(loadout.get("primary_weapon_id", &"unarmed"))),
		WeaponKitCatalog.label_for(StringName(loadout.get("secondary_weapon_id", &"unarmed"))),
		MasterTrainingCatalog.variant_summary(StringName(loadout.get("variant_id", &"")))
	]
	_update_preview(slot, character_id)
	_update_fields(slot, player_index)

func _update_preview(slot: int, character_id: StringName) -> void:
	var path := CharacterVisualCatalog.sheet_path(character_id)
	if path == "" or not ResourceLoader.exists(path):
		_player_previews[slot].texture = null
		return
	var texture := load(path) as Texture2D
	if not is_instance_valid(texture):
		_player_previews[slot].texture = null
		return
	var atlas := _preview_atlases[slot]
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, CharacterVisualCatalog.FRAME_SIZE)
	_player_previews[slot].texture = atlas

func _update_fields(slot: int, player_index: int) -> void:
	var lines: Array[String] = []
	var loadout := _loadouts[slot]
	var color := "#86d7ff" if player_index == 1 else "#ff9a78"
	for index in range(BattleLoadoutCatalog.FIELD_ORDER.size()):
		var field_id := BattleLoadoutCatalog.FIELD_ORDER[index]
		var value_id := BattleLoadoutCatalog.value_for_field(field_id, loadout)
		var label := BattleLoadoutCatalog.field_label(field_id)
		var value := BattleLoadoutCatalog.value_label(field_id, value_id)
		if index == _field_indices[slot]:
			lines.append("[color=%s][b]▶ %s: ◀ %s ▶[/b][/color]" % [color, label, value])
		else:
			lines.append("  [b]%s:[/b] %s" % [label, value])
	_player_fields[slot].text = "\n".join(lines)

func _exit_tree() -> void:
	_sync_all_ledgers()
