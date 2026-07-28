extends Node

const HERO_TEXTURES := {
	1: "res://assets/packs/pack_07_heroes_masters/runtime/hd/TM_HERO_WARDEN_NE_BASE_001.png",
	2: "res://assets/packs/pack_07_heroes_masters/runtime/hd/TM_HERO_REAVER_NW_BASE_001.png"
}
const IMPACT_TEXTURE := "res://assets/packs/pack_09_combat_vfx_skills/runtime/hd/TM_VFX_IMPACT_CRITICAL_003.png"
const HEAL_TEXTURE := "res://assets/packs/pack_09_combat_vfx_skills/runtime/hd/TM_VFX_STATE_HEAL_002.png"

const COLOR_PANEL := Color(0.105, 0.078, 0.052, 0.94)
const COLOR_PANEL_INNER := Color(0.16, 0.115, 0.072, 0.96)
const COLOR_BRONZE := Color(0.66, 0.47, 0.24, 1.0)
const COLOR_PARCHMENT := Color(0.91, 0.84, 0.68, 1.0)
const COLOR_HEALTH := Color(0.56, 0.12, 0.10, 1.0)
const COLOR_POSTURE := Color(0.78, 0.52, 0.16, 1.0)
const COLOR_STAMINA := Color(0.24, 0.48, 0.26, 1.0)
const COLOR_TRACK := Color(0.055, 0.043, 0.032, 0.96)

var _fighters: Dictionary = {}
var _last_health: Dictionary = {}
var _last_posture: Dictionary = {}
var _scan_timer := 0.0
var _hud_layer: CanvasLayer
var _hud_root: Control
var _bars: Dictionary = {}
var _duel_label: Label

func _ready() -> void:
	_create_hud()
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.35
		_discover_fighters()
	_update_bound_fighters()

func _discover_fighters() -> void:
	var found: Array[Node] = []
	_collect_fighters(get_tree().root, found)
	for node in found:
		var fighter := node as FighterController
		var player_index := int(fighter.player_index)
		if player_index < 1 or player_index > 2:
			continue
		if _fighters.get(player_index) != fighter:
			_bind_fighter(player_index, fighter)

func _collect_fighters(node: Node, found: Array[Node]) -> void:
	if node is FighterController:
		found.append(node)
	for child in node.get_children():
		_collect_fighters(child, found)

func _bind_fighter(player_index: int, fighter: FighterController) -> void:
	_fighters[player_index] = fighter
	_last_health[player_index] = float(fighter.health)
	_last_posture[player_index] = float(fighter.posture)
	_apply_character_visual(player_index, fighter)
	_update_duel_title()

func _apply_character_visual(player_index: int, fighter: FighterController) -> void:
	var old_visual := fighter.get_node_or_null("Pack99CharacterVisual")
	if old_visual != null:
		old_visual.queue_free()
	var sprite := Sprite2D.new()
	sprite.name = "Pack99CharacterVisual"
	sprite.position = Vector2(0.0, -82.0)
	sprite.scale = Vector2(0.34, 0.34)
	sprite.z_index = 20
	var path := String(HERO_TEXTURES.get(player_index, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		sprite.texture = load(path)
		sprite.modulate = Color.WHITE
	else:
		sprite.texture = _fallback_character_texture(player_index)
	fighter.add_child(sprite)

func _fallback_character_texture(player_index: int) -> Texture2D:
	var image := Image.create(192, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := Color(0.24, 0.42, 0.58, 0.94) if player_index == 1 else Color(0.55, 0.22, 0.13, 0.94)
	for y in range(36, 230):
		for x in range(34, 158):
			var center := Vector2(96, 132)
			var radius := Vector2(58, 102)
			var p := Vector2(x, y)
			var normalized := Vector2((p.x - center.x) / radius.x, (p.y - center.y) / radius.y)
			if normalized.length_squared() <= 1.0:
				image.set_pixel(x, y, color)
	for y in range(18, 84):
		for x in range(62, 130):
			if Vector2(x - 96, y - 51).length() <= 33.0:
				image.set_pixel(x, y, color.lightened(0.12))
	return ImageTexture.create_from_image(image)

func _update_bound_fighters() -> void:
	for player_index in [1, 2]:
		var fighter: FighterController = _fighters.get(player_index)
		if not is_instance_valid(fighter):
			_fighters.erase(player_index)
			continue
		var health := float(fighter.health)
		var posture := float(fighter.posture)
		var previous_health := float(_last_health.get(player_index, health))
		var previous_posture := float(_last_posture.get(player_index, posture))
		if health < previous_health - 0.1:
			_spawn_vfx(fighter.global_position + Vector2(0, -70), IMPACT_TEXTURE, Color(1.0, 0.42, 0.24, 0.9))
		elif health > previous_health + 0.1:
			_spawn_vfx(fighter.global_position + Vector2(0, -70), HEAL_TEXTURE, Color(0.35, 1.0, 0.55, 0.9))
		if posture < previous_posture - 12.0:
			_spawn_vfx(fighter.global_position + Vector2(0, -35), IMPACT_TEXTURE, Color(1.0, 0.82, 0.28, 0.75))
		_last_health[player_index] = health
		_last_posture[player_index] = posture
		_update_hud_for(player_index, fighter)

func _spawn_vfx(world_position: Vector2, texture_path: String, fallback_color: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.global_position = world_position
	sprite.z_index = 80
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(0.42, 0.42)
	else:
		sprite.texture = _fallback_vfx_texture(fallback_color)
	get_tree().current_scene.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 1.45, 0.22)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(sprite.queue_free)

func _fallback_vfx_texture(color: Color) -> Texture2D:
	var image := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(80, 80)
	for y in range(160):
		for x in range(160):
			var distance := Vector2(x, y).distance_to(center)
			if distance < 66.0:
				var alpha := clampf(1.0 - distance / 66.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * color.a))
	return ImageTexture.create_from_image(image)

func _create_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 40
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)

	_duel_label = Label.new()
	_duel_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_duel_label.position = Vector2(-115, 18)
	_duel_label.size = Vector2(230, 34)
	_duel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_duel_label.text = "DUELO DOS MESTRES"
	_duel_label.add_theme_font_size_override("font_size", 15)
	_duel_label.add_theme_color_override("font_color", COLOR_PARCHMENT)
	_duel_label.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL_INNER, 2, 8))
	_hud_root.add_child(_duel_label)

	_create_player_hud(1, true)
	_create_player_hud(2, false)

func _create_player_hud(player_index: int, align_left: bool) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT if align_left else Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(18, 18) if align_left else Vector2(-356, 18)
	panel.size = Vector2(338, 118)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 2, 10))
	_hud_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	var crest := Label.new()
	crest.text = "I" if player_index == 1 else "II"
	crest.custom_minimum_size = Vector2(32, 26)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 14)
	crest.add_theme_color_override("font_color", COLOR_PARCHMENT)
	crest.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL_INNER, 1, 5))
	title_row.add_child(crest)

	var title := Label.new()
	title.name = "Title"
	title.text = "MESTRE %d" % player_index
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COLOR_PARCHMENT)
	title_row.add_child(title)

	var health := _create_bar(18, COLOR_HEALTH)
	box.add_child(health)
	var posture := _create_bar(12, COLOR_POSTURE)
	box.add_child(posture)
	var stamina := _create_bar(10, COLOR_STAMINA)
	box.add_child(stamina)

	var detail := Label.new()
	detail.name = "Detail"
	detail.text = "ELEMENTO • ARMA • TÉCNICA"
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color(0.76, 0.69, 0.56, 1.0))
	box.add_child(detail)

	_bars[player_index] = {
		"title": title,
		"health": health,
		"posture": posture,
		"stamina": stamina,
		"detail": detail
	}

func _create_bar(height: int, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, height)
	bar.add_theme_stylebox_override("background", _bar_style(COLOR_TRACK, height))
	bar.add_theme_stylebox_override("fill", _bar_style(fill_color, height))
	return bar

func _panel_style(color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLOR_BRONZE
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	style.shadow_size = 5
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(maxi(2, radius / 3))
	return style

func _update_duel_title() -> void:
	if not is_instance_valid(_duel_label):
		return
	if _fighters.has(1) and _fighters.has(2):
		_duel_label.text = "DUELO EM ANDAMENTO"
	else:
		_duel_label.text = "DUELO DOS MESTRES"

func _update_hud_for(player_index: int, fighter: FighterController) -> void:
	var refs: Dictionary = _bars.get(player_index, {})
	if refs.is_empty():
		return
	(refs["health"] as ProgressBar).value = clampf(float(fighter.health), 0.0, 100.0)
	(refs["posture"] as ProgressBar).value = clampf(float(fighter.posture), 0.0, 100.0)
	(refs["stamina"] as ProgressBar).value = clampf(float(fighter.stamina), 0.0, 100.0)
	(refs["title"] as Label).text = String(fighter.build.character_name).to_upper()
	(refs["detail"] as Label).text = "%s • %s • %s" % [
		String(fighter.build.element_id).to_upper(),
		fighter.current_weapon_label(),
		fighter.current_technique_label()
	]
