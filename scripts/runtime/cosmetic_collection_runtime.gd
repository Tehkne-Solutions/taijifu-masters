extends Node

signal collection_opened
signal collection_closed
signal equipment_changed(slot_id: String, item_id: String)
signal equipment_rejected(slot_id: String, item_id: String, reason: String)

const SAVE_PATH := "user://taijifu-cosmetic-loadout.json"
const SLOT_ITEMS := {
	"banner": ["", "tai_banner", "ji_banner", "fu_banner"],
	"aura": ["", "training_aura"],
	"frame": ["", "master_frame"]
}
const ITEM_LABELS := {
	"": "NENHUM",
	"tai_banner": "ESTANDARTE TAI",
	"ji_banner": "ESTANDARTE JI",
	"fu_banner": "ESTANDARTE FU",
	"training_aura": "AURA DO DISCÍPULO",
	"master_frame": "MOLDURA DOS MESTRES"
}

var _equipped := {"banner":"", "aura":"", "frame":""}
var _layer: CanvasLayer
var _content: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_validate_equipment()
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_signal("shop_purchase_completed"):
		profile.shop_purchase_completed.connect(_on_purchase_completed)

func open_collection() -> void:
	close_collection()
	_layer = CanvasLayer.new()
	_layer.layer = 490
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.024, 0.038, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 70)
	panel.size = Vector2(860, 580)
	shade.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	panel.add_child(_content)
	_rebuild()
	collection_opened.emit()

func close_collection() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	collection_closed.emit()

func equip(slot_id: String, item_id: String) -> bool:
	if not SLOT_ITEMS.has(slot_id):
		equipment_rejected.emit(slot_id, item_id, "invalid_slot")
		return false
	if item_id not in Array(SLOT_ITEMS[slot_id]):
		equipment_rejected.emit(slot_id, item_id, "invalid_item_for_slot")
		return false
	if item_id != "" and not _owns(item_id):
		equipment_rejected.emit(slot_id, item_id, "not_owned")
		return false
	_equipped[slot_id] = item_id
	_save()
	equipment_changed.emit(slot_id, item_id)
	_rebuild()
	return true

func equipped_item(slot_id: String) -> String:
	return String(_equipped.get(slot_id, ""))

func equipped_snapshot() -> Dictionary:
	return _equipped.duplicate(true)

func available_items(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	if not SLOT_ITEMS.has(slot_id):
		return result
	for item_id in Array(SLOT_ITEMS[slot_id]):
		if String(item_id) == "" or _owns(String(item_id)):
			result.append(String(item_id))
	return result

func _owns(item_id: String) -> bool:
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	return profile != null and profile.has_method("owns_item") and bool(profile.owns_item(item_id))

func _validate_equipment() -> void:
	var changed := false
	for slot_id in SLOT_ITEMS:
		var item_id := String(_equipped.get(slot_id, ""))
		if item_id != "" and (item_id not in Array(SLOT_ITEMS[slot_id]) or not _owns(item_id)):
			_equipped[slot_id] = ""
			changed = true
	if changed:
		_save()

func _on_purchase_completed(item_id: String, _remaining_tokens: int) -> void:
	for slot_id in SLOT_ITEMS:
		if item_id in Array(SLOT_ITEMS[slot_id]) and equipped_item(slot_id) == "":
			equip(slot_id, item_id)
			return
	_rebuild()

func _rebuild() -> void:
	if not is_instance_valid(_content):
		return
	for child in _content.get_children():
		child.queue_free()
	_content.add_child(_label("COLEÇÃO E PERSONALIZAÇÃO", 30))
	_content.add_child(_label("Equipe um item por categoria. Apenas itens adquiridos aparecem.", 16))
	for slot_id in ["banner", "aura", "frame"]:
		_content.add_child(_slot_section(slot_id))
	var close := Button.new()
	close.text = "FECHAR"
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.pressed.connect(close_collection)
	_content.add_child(close)

func _slot_section(slot_id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label(slot_id.to_upper(), 21))
	var options := available_items(slot_id)
	for item_id in options:
		var row := HBoxContainer.new()
		var selected := equipped_item(slot_id) == item_id
		row.add_child(_label("%s%s" % [ITEM_LABELS.get(item_id, item_id.to_upper()), "  •  EQUIPADO" if selected else ""], 16))
		var button := Button.new()
		button.text = "EQUIPADO" if selected else "EQUIPAR"
		button.disabled = selected
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		var target_slot := slot_id
		var target_item := item_id
		button.pressed.connect(func(): equip(target_slot, target_item))
		row.add_child(button)
		box.add_child(row)
	return box

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	return label

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for slot_id in SLOT_ITEMS:
			_equipped[slot_id] = String(parsed.get(slot_id, ""))

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_equipped, "\t"))
