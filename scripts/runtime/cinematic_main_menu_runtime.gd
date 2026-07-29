extends Node

signal presentation_applied
signal profile_summary_refreshed(summary: Dictionary)

const MODE_GLYPHS := {
	"ARENA": "⚔",
	"DUELO": "◆",
	"TREINO": "◈",
	"CAMPEÃO": "♜",
	"SÉRIE": "✦",
	"ROGUELITE": "✦"
}
const CRESTS := [
	{"id":"tai", "label":"TAI", "subtitle":"CORPO", "color":Color("4d8fb8")},
	{"id":"ji", "label":"JI", "subtitle":"FLUXO", "color":Color("bd7445")},
	{"id":"fu", "label":"FU", "subtitle":"TÉCNICA", "color":Color("8467b8")}
]

var _decorated_layer_id := 0
var _summary_label: Label
var _scan_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var menu := get_node_or_null("/root/MainMenuRuntime")
	if menu != null and menu.has_signal("menu_opened"):
		menu.menu_opened.connect(func(): call_deferred("_decorate_menu"))
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.5
	if not is_instance_valid(_summary_label):
		_decorate_menu()
	else:
		_refresh_summary()

func _decorate_menu() -> void:
	var layer := _find_menu_layer()
	if layer == null:
		return
	if _decorated_layer_id == layer.get_instance_id():
		return
	_decorated_layer_id = layer.get_instance_id()
	_add_arena_backdrop(layer)
	_add_crest_row(layer)
	_add_profile_summary(layer)
	_decorate_mode_cards(layer)
	presentation_applied.emit()

func _find_menu_layer() -> CanvasLayer:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == "TaijifuMainMenu":
			return child
	return null

func _add_arena_backdrop(layer: CanvasLayer) -> void:
	var backdrop := Control.new()
	backdrop.name = "CinematicArenaBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)
	layer.move_child(backdrop, 0)
	var sky := ColorRect.new()
	sky.color = Color(0.025, 0.028, 0.034, 1.0)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(sky)
	for i in range(7):
		var pillar := Polygon2D.new()
		var x := 90.0 + float(i) * 185.0
		pillar.polygon = PackedVector2Array([Vector2(x-34,720),Vector2(x-24,190),Vector2(x+24,190),Vector2(x+34,720)])
		pillar.color = Color(0.10,0.095,0.085,0.55)
		backdrop.add_child(pillar)
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2(0,720),Vector2(1280,720),Vector2(1030,465),Vector2(250,465)])
	floor.color = Color(0.12,0.085,0.055,0.62)
	backdrop.add_child(floor)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(410,720),Vector2(870,720),Vector2(760,475),Vector2(520,475)])
	glow.color = Color(0.62,0.40,0.16,0.12)
	backdrop.add_child(glow)

func _add_crest_row(layer: CanvasLayer) -> void:
	var row := HBoxContainer.new()
	row.name = "TaiJiFuCrests"
	row.position = Vector2(450, 10)
	row.size = Vector2(390, 52)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(row)
	for data in CRESTS:
		var crest := PanelContainer.new()
		crest.custom_minimum_size = Vector2(116,46)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crest.add_theme_stylebox_override("panel", _crest_style(data.color))
		var label := Label.new()
		label.text = "%s  •  %s" % [data.label, data.subtitle]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("f0dfbd"))
		crest.add_child(label)
		row.add_child(crest)

func _add_profile_summary(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.name = "CinematicProfileSummary"
	panel.position = Vector2(42, 668)
	panel.size = Vector2(1196, 38)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _summary_style())
	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color("e8d6b4"))
	panel.add_child(_summary_label)
	layer.add_child(panel)
	_refresh_summary()

func _refresh_summary() -> void:
	if not is_instance_valid(_summary_label):
		return
	var summary := {"level":1,"xp":0,"tokens":0,"banner":"NENHUM","aura":"NENHUMA","frame":"NENHUMA"}
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_method("profile_snapshot"):
		var snapshot: Dictionary = profile.profile_snapshot()
		summary.level = int(snapshot.get("level", snapshot.get("training_level", 1)))
		summary.xp = int(snapshot.get("total_xp", snapshot.get("xp", 0)))
		summary.tokens = int(snapshot.get("training_tokens", snapshot.get("tokens", 0)))
	var collection := get_node_or_null("/root/CosmeticCollectionRuntime")
	if collection != null and collection.has_method("equipped_snapshot"):
		var equipped: Dictionary = collection.equipped_snapshot()
		summary.banner = _short_item(String(equipped.get("banner", "")))
		summary.aura = _short_item(String(equipped.get("aura", "")))
		summary.frame = _short_item(String(equipped.get("frame", "")))
	_summary_label.text = "NÍVEL %d   •   XP %d   •   FICHAS %d   •   ESTANDARTE %s   •   AURA %s   •   MOLDURA %s" % [summary.level, summary.xp, summary.tokens, summary.banner, summary.aura, summary.frame]
	profile_summary_refreshed.emit(summary)

func _decorate_mode_cards(layer: CanvasLayer) -> void:
	for button in _find_buttons(layer):
		var text := button.text.to_upper()
		if "ENTRAR NA PREPARAÇÃO" in text or "PERFIL" in text or "LOJA" in text or "COLEÇÃO" in text:
			continue
		for key in MODE_GLYPHS:
			if key in text and not text.begins_with(MODE_GLYPHS[key]):
				button.text = "%s  %s" % [MODE_GLYPHS[key], button.text]
				button.tooltip_text = "Prova de mestre: %s" % key.capitalize()
				break

func _find_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			result.append(child)
		result.append_array(_find_buttons(child))
	return result

func _short_item(item_id: String) -> String:
	if item_id == "": return "NENHUM"
	return item_id.replace("_banner", "").replace("training_", "").replace("master_", "").replace("_", " ").to_upper()

func _crest_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r*0.35,color.g*0.35,color.b*0.35,0.94)
	style.border_color = color.lightened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0,0,0,0.6)
	style.shadow_size = 5
	return style

func _summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.04,0.025,0.96)
	style.border_color = Color(0.72,0.53,0.27,0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func presentation_snapshot() -> Dictionary:
	return {"crests":3,"arena_backdrop":true,"profile_summary":true,"mode_glyphs":MODE_GLYPHS.size()}
