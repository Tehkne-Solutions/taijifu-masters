extends Node

signal mode_changed(mode_id: String, config: Dictionary)

const DEFAULT_MODE := "arena_loot"
const MODES := {
	"competitive_duel": {
		"label": "DUELO COMPETITIVO",
		"description": "Combate técnico puro, sem tropas, pickups ou progressão entre rounds.",
		"units": false, "pickups": false, "synergies": false, "series_loot": false, "series": false, "training": false, "champion": false
	},
	"arena_loot": {
		"label": "ARENA COM LOOT",
		"description": "Duelo com tropas, campeão, itens procedurais, raridades e sinergias.",
		"units": true, "pickups": true, "synergies": true, "series_loot": false, "series": false, "training": false, "champion": true
	},
	"roguelite_series": {
		"label": "SÉRIE ROGUELITE",
		"description": "Melhor de três ou cinco com inventário, perdas, proteção e builds evolutivas.",
		"units": true, "pickups": true, "synergies": true, "series_loot": true, "series": true, "training": false, "champion": true
	},
	"training": {
		"label": "TREINO TAI · JI · FU",
		"description": "Ambiente controlado para gravação, fantasmas, técnicas e certificações.",
		"units": false, "pickups": false, "synergies": false, "series_loot": false, "series": false, "training": true, "champion": false
	},
	"champion_challenge": {
		"label": "DESAFIO DO CAMPEÃO",
		"description": "Enfrente tropas neutras e o Champion Dragon com recursos limitados.",
		"units": true, "pickups": true, "synergies": false, "series_loot": false, "series": false, "training": false, "champion": true
	}
}

const RUNTIME_MAP := {
	"units": "/root/Pack08ArenaUnitRuntime",
	"pickups": "/root/ProceduralArenaPickupRuntime",
	"synergies": "/root/PickupSynergyRuntime",
	"series_loot": "/root/SeriesLootProgressionRuntime",
	"series": "/root/CompleteSeriesModeRuntime"
}

var current_mode := DEFAULT_MODE
var _selector_layer: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("apply_mode", DEFAULT_MODE)

func apply_mode(mode_id: String) -> bool:
	if not MODES.has(mode_id):
		return false
	current_mode = mode_id
	var config: Dictionary = MODES[mode_id]
	for feature in RUNTIME_MAP:
		_set_runtime_enabled(String(RUNTIME_MAP[feature]), bool(config.get(feature, false)))
	_configure_training(bool(config.get("training", false)))
	_configure_champion(bool(config.get("champion", false)))
	if mode_id != "roguelite_series":
		var series := get_node_or_null("/root/CompleteSeriesModeRuntime")
		if series != null and series.has_method("start_series"):
			series._close_panel()
			get_tree().paused = false
	mode_changed.emit(mode_id, mode_snapshot())
	return true

func _set_runtime_enabled(path: String, enabled: bool) -> void:
	var runtime := get_node_or_null(path)
	if runtime == null:
		return
	runtime.set_process(enabled)
	runtime.set_physics_process(enabled)
	runtime.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _configure_training(enabled: bool) -> void:
	for path in ["/root/TaijifuGamepadTraining", "/root/TaijifuControllerMastery", "/root/TaijifuInputGhostMastery", "/root/TaijifuGhostRace"]:
		var runtime := get_node_or_null(path)
		if runtime != null:
			runtime.set_process(enabled)

func _configure_champion(enabled: bool) -> void:
	var units := get_node_or_null("/root/Pack08ArenaUnitRuntime")
	if units != null:
		units.set_meta("champion_enabled", enabled)

func open_mode_selector() -> void:
	close_mode_selector()
	_selector_layer = CanvasLayer.new()
	_selector_layer.name = "GameModeSelector"
	_selector_layer.layer = 300
	_selector_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_selector_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 55)
	panel.size = Vector2(780, 610)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_selector_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ESCOLHA O MODO DE JOGO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for mode_id in MODES:
		var selected := String(mode_id)
		var config: Dictionary = MODES[mode_id]
		var button := Button.new()
		button.text = "%s\n%s" % [String(config["label"]), String(config["description"])]
		button.custom_minimum_size = Vector2(720, 86)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.pressed.connect(func():
			apply_mode(selected)
			close_mode_selector()
		)
		box.add_child(button)
	var close := Button.new()
	close.text = "FECHAR"
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.pressed.connect(close_mode_selector)
	box.add_child(close)

func close_mode_selector() -> void:
	if is_instance_valid(_selector_layer):
		_selector_layer.queue_free()
	_selector_layer = null

func mode_snapshot() -> Dictionary:
	var result: Dictionary = Dictionary(MODES[current_mode]).duplicate(true)
	result["id"] = current_mode
	return result

func available_modes() -> Array[String]:
	var result: Array[String] = []
	for mode_id in MODES.keys():
		result.append(String(mode_id))
	return result

func is_feature_enabled(feature: String) -> bool:
	return bool(MODES[current_mode].get(feature, false))
