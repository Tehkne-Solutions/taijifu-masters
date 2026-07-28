extends Node

signal profile_opened
signal profile_closed
signal shop_purchase_completed(item_id: String, remaining_tokens: int)
signal shop_purchase_failed(item_id: String, reason: String)

const SAVE_PATH := "user://taijifu-player-profile.json"
const SHOP_ITEMS := {
	"tai_banner": {"label":"ESTANDARTE TAI","cost":3,"type":"cosmetic"},
	"ji_banner": {"label":"ESTANDARTE JI","cost":3,"type":"cosmetic"},
	"fu_banner": {"label":"ESTANDARTE FU","cost":3,"type":"cosmetic"},
	"training_aura": {"label":"AURA DO DISCÍPULO","cost":5,"type":"cosmetic"},
	"master_frame": {"label":"MOLDURA DOS MESTRES","cost":8,"type":"profile"},
	"extra_preset": {"label":"ESPAÇO EXTRA DE PRESET","cost":6,"type":"utility"}
}

var _data := {"version":1,"owned_items":[],"purchase_history":[],"battle_stats":{"matches":0,"wins":0,"losses":0,"training_sessions":0}}
var _layer: CanvasLayer
var _content: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()

func open_profile() -> void:
	close_profile()
	_layer = CanvasLayer.new()
	_layer.layer = 480
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.018,0.024,0.038,0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(150,35)
	scroll.size = Vector2(980,650)
	shade.add_child(scroll)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(940,0)
	_content.add_theme_constant_override("separation",10)
	scroll.add_child(_content)
	_rebuild()
	profile_opened.emit()

func close_profile() -> void:
	if is_instance_valid(_layer): _layer.queue_free()
	_layer = null
	profile_closed.emit()

func _rebuild() -> void:
	if not is_instance_valid(_content): return
	for child in _content.get_children(): child.queue_free()
	_content.add_child(_label("PERFIL DE PROGRESSÃO",30))
	var snapshot := profile_snapshot()
	_content.add_child(_label("NÍVEL %d  •  %d XP  •  %d FICHAS DE TREINO" % [snapshot.level,snapshot.total_xp,snapshot.training_tokens],18))
	_content.add_child(_label("MEDALHAS: %s" % _joined(snapshot.medals),15))
	_content.add_child(_label("CERTIFICAÇÕES: %s" % _joined(snapshot.certifications),15))
	_content.add_child(_label("VARIANTES: %s" % _joined(snapshot.variants),15))
	var stats: Dictionary = snapshot.battle_stats
	_content.add_child(_label("BATALHAS %d  •  VITÓRIAS %d  •  DERROTAS %d  •  TREINOS %d" % [stats.matches,stats.wins,stats.losses,stats.training_sessions],15))
	_content.add_child(_label("LOJA DE TREINO",24))
	for item_id in SHOP_ITEMS:
		var spec: Dictionary = SHOP_ITEMS[item_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var owned := item_id in Array(_data.owned_items)
		row.add_child(_label("%s  •  %d FICHAS%s" % [spec.label,spec.cost,"  •  ADQUIRIDO" if owned else ""],16))
		var button := Button.new()
		button.text = "ADQUIRIDO" if owned else "COMPRAR"
		button.disabled = owned
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		var selected := String(item_id)
		button.pressed.connect(func(): purchase(selected))
		row.add_child(button)
		_content.add_child(row)
	var close := Button.new()
	close.text = "FECHAR"
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.pressed.connect(close_profile)
	_content.add_child(close)

func purchase(item_id: String) -> bool:
	if not SHOP_ITEMS.has(item_id):
		shop_purchase_failed.emit(item_id,"invalid_item")
		return false
	if item_id in Array(_data.owned_items):
		shop_purchase_failed.emit(item_id,"already_owned")
		return false
	var progression := get_node_or_null("/root/TrainingProgressionRuntime")
	if progression == null:
		shop_purchase_failed.emit(item_id,"progression_unavailable")
		return false
	var pdata: Dictionary = progression.get("_data")
	var cost := int(SHOP_ITEMS[item_id].cost)
	var tokens := int(pdata.get("training_tokens",0))
	if tokens < cost:
		shop_purchase_failed.emit(item_id,"insufficient_tokens")
		return false
	pdata["training_tokens"] = tokens - cost
	progression.set("_data",pdata)
	if progression.has_method("_save_to_disk"): progression.call("_save_to_disk")
	var owned: Array = _data.owned_items
	owned.append(item_id)
	_data.owned_items = owned
	var history: Array = _data.purchase_history
	history.append({"item_id":item_id,"cost":cost,"timestamp":int(Time.get_unix_time_from_system())})
	while history.size() > 50: history.pop_front()
	_data.purchase_history = history
	_save()
	shop_purchase_completed.emit(item_id,tokens-cost)
	_rebuild()
	return true

func record_battle_result(won: bool) -> void:
	var stats: Dictionary = _data.battle_stats
	stats.matches = int(stats.matches)+1
	if won: stats.wins = int(stats.wins)+1
	else: stats.losses = int(stats.losses)+1
	_data.battle_stats = stats
	_save()

func record_training_session() -> void:
	var stats: Dictionary = _data.battle_stats
	stats.training_sessions = int(stats.training_sessions)+1
	_data.battle_stats = stats
	_save()

func profile_snapshot() -> Dictionary:
	var progression := get_node_or_null("/root/TrainingProgressionRuntime")
	var ps := progression.progression_snapshot() if progression != null else {"level":1,"total_xp":0,"training_tokens":0,"medals":[],"certifications":[]}
	var variants: Array = []
	var scene := get_tree().current_scene
	var master := scene.get_node_or_null("MasterTrainingRuntime") if scene != null else null
	if master != null:
		var ledger = master.get("ledger")
		if ledger != null:
			for profile_id in ["p1","p2"]:
				for variant_id in ledger.unlocked_variants(profile_id):
					if variant_id not in variants: variants.append(variant_id)
	return {"level":int(ps.get("level",1)),"total_xp":int(ps.get("total_xp",0)),"training_tokens":int(ps.get("training_tokens",0)),"medals":Array(ps.get("medals",[])),"certifications":Array(ps.get("certifications",[])),"variants":variants,"owned_items":Array(_data.owned_items).duplicate(),"battle_stats":Dictionary(_data.battle_stats).duplicate(true),"purchase_history":Array(_data.purchase_history).duplicate(true)}

func owns_item(item_id: String) -> bool:
	return item_id in Array(_data.owned_items)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	return label

func _joined(values: Array) -> String:
	return "NENHUMA" if values.is_empty() else " • ".join(values).to_upper()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary: _data.merge(parsed,true)

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(_data,"\t"))
