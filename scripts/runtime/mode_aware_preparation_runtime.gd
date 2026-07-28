extends Node

signal preparation_context_changed(mode_id: String, options: Dictionary)
signal champion_difficulty_changed(difficulty_id: String)
signal training_focus_changed(focus_id: String)

const CHAMPION_DIFFICULTIES := {
	"initiate": {"label":"INICIADO","unit_scale":0.85,"champion_scale":0.80,"pickup_interval":7.0},
	"master": {"label":"MESTRE","unit_scale":1.0,"champion_scale":1.0,"pickup_interval":9.0},
	"legend": {"label":"LENDA","unit_scale":1.20,"champion_scale":1.30,"pickup_interval":12.0}
}

const TRAINING_FOCUS := {
	"free": "TREINO LIVRE",
	"tai": "DOMÍNIO TAI",
	"ji": "CONTROLE JI",
	"fu": "PRECISÃO FU",
	"ghost": "CORRIDA CONTRA FANTASMA"
}

const MODE_RULES := {
	"competitive_duel": ["Sem tropas ou pickups", "Builds fixas durante o round", "Vitória definida por técnica e adaptação"],
	"arena_loot": ["Tropas e Champion Dragon ativos", "Pickups, raridades e sinergias", "Sem inventário persistente entre rounds"],
	"roguelite_series": ["Melhor de 3 ou 5", "Inventário e build evoluem entre rounds", "Derrota pode remover parte do loot"],
	"training": ["Sem interferências da arena", "Fantasmas, maestria e certificações", "Resultado não afeta série competitiva"],
	"champion_challenge": ["Tropas neutras e campeão", "Recursos limitados", "Dificuldade altera pressão e recompensas"]
}

var _champion_difficulty := "master"
var _training_focus := "free"
var _layer: CanvasLayer
var _panel: PanelContainer
var _rules_label: Label
var _options_box: HBoxContainer
var _status_label: Label
var _mode_id := "arena_loot"
var _scan_timer := 0.0
var _preparation: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var menu := get_node_or_null("/root/MainMenuRuntime")
	if menu != null and menu.has_signal("preparation_requested"):
		menu.preparation_requested.connect(_on_preparation_requested)
	var modes := get_node_or_null("/root/GameModeRuntime")
	if modes != null and modes.has_signal("mode_changed"):
		modes.mode_changed.connect(_on_mode_changed)
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.2
	_resolve_preparation()
	if _preparation == null:
		_hide_context()
		return
	if bool(_preparation.call("is_active")):
		_ensure_context()
		_refresh_status()
	else:
		_hide_context()

func _resolve_preparation() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_preparation = null
		return
	_preparation = scene.get_node_or_null("BattlePreparationRuntime")

func _on_preparation_requested(mode_id: String, _options: Dictionary) -> void:
	_mode_id = mode_id
	_apply_mode_options()
	preparation_context_changed.emit(_mode_id, context_snapshot())

func _on_mode_changed(mode_id: String, _config: Dictionary) -> void:
	_mode_id = mode_id
	_apply_mode_options()

func _ensure_context() -> void:
	if is_instance_valid(_layer):
		_layer.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.name = "ModeAwarePreparation"
	_layer.layer = 212
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(300, 88)
	_panel.size = Vector2(680, 108)
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	_panel.add_child(root)
	_rules_label = Label.new()
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_rules_label)
	_options_box = HBoxContainer.new()
	_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_box.add_theme_constant_override("separation", 8)
	root.add_child(_options_box)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_status_label)
	_rebuild_context()

func _hide_context() -> void:
	if is_instance_valid(_layer):
		_layer.visible = false

func _rebuild_context() -> void:
	if not is_instance_valid(_rules_label):
		return
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	var label := _mode_id.to_upper()
	if mode_runtime != null and mode_runtime.MODES.has(_mode_id):
		label = String(mode_runtime.MODES[_mode_id].get("label", label))
	var rules: Array = MODE_RULES.get(_mode_id, [])
	_rules_label.text = "%s  •  %s" % [label, "  |  ".join(rules)]
	for child in _options_box.get_children():
		child.queue_free()
	if _mode_id == "champion_challenge":
		for difficulty_id in CHAMPION_DIFFICULTIES:
			var selected := String(difficulty_id)
			var button := Button.new()
			button.text = String(CHAMPION_DIFFICULTIES[difficulty_id]["label"])
			button.disabled = selected == _champion_difficulty
			button.process_mode = Node.PROCESS_MODE_ALWAYS
			button.pressed.connect(func(): set_champion_difficulty(selected))
			_options_box.add_child(button)
	elif _mode_id == "training":
		for focus_id in TRAINING_FOCUS:
			var selected := String(focus_id)
			var button := Button.new()
			button.text = String(TRAINING_FOCUS[focus_id])
			button.disabled = selected == _training_focus
			button.process_mode = Node.PROCESS_MODE_ALWAYS
			button.pressed.connect(func(): set_training_focus(selected))
			_options_box.add_child(button)
	elif _mode_id == "roguelite_series":
		var series := get_node_or_null("/root/CompleteSeriesModeRuntime")
		var best_of := 3 if series == null else int(series.best_of)
		_options_box.add_child(_small_label("FORMATO: MELHOR DE %d  •  INVENTÁRIO MÁXIMO: 5  •  1 ITEM PROTEGIDO" % best_of))
	elif _mode_id == "competitive_duel":
		_options_box.add_child(_small_label("REGRAS PURAS  •  SEM INTERFERÊNCIAS  •  LOADOUT BLOQUEADO APÓS CONFIRMAÇÃO"))
	else:
		_options_box.add_child(_small_label("ARENA DINÂMICA  •  LOOT TEMPORÁRIO  •  SINERGIAS ATIVAS"))
	_apply_mode_options()

func _refresh_status() -> void:
	if not is_instance_valid(_status_label) or _preparation == null:
		return
	var p1 := bool(_preparation.call("is_player_ready", 1))
	var p2 := bool(_preparation.call("is_player_ready", 2))
	var p1_label := "PRONTO" if p1 else "CONFIGURANDO"
	var p2_label := "PRONTO" if p2 else "CONFIGURANDO"
	_status_label.text = "P1: %s   •   P2: %s   •   %s" % [p1_label, p2_label, "INICIANDO BATALHA" if p1 and p2 else "AGUARDANDO AS DUAS CONFIRMAÇÕES"]

func set_champion_difficulty(difficulty_id: String) -> bool:
	if not CHAMPION_DIFFICULTIES.has(difficulty_id):
		return false
	_champion_difficulty = difficulty_id
	_apply_mode_options()
	_rebuild_context()
	champion_difficulty_changed.emit(difficulty_id)
	return true

func set_training_focus(focus_id: String) -> bool:
	if not TRAINING_FOCUS.has(focus_id):
		return false
	_training_focus = focus_id
	_apply_mode_options()
	_rebuild_context()
	training_focus_changed.emit(focus_id)
	return true

func _apply_mode_options() -> void:
	var units := get_node_or_null("/root/Pack08ArenaUnitRuntime")
	if units != null:
		var difficulty: Dictionary = CHAMPION_DIFFICULTIES[_champion_difficulty]
		units.set_meta("difficulty_id", _champion_difficulty)
		units.set_meta("unit_scale", difficulty["unit_scale"])
		units.set_meta("champion_scale", difficulty["champion_scale"])
	var pickups := get_node_or_null("/root/ProceduralArenaPickupRuntime")
	if pickups != null:
		pickups.set_meta("mode_pickup_interval", CHAMPION_DIFFICULTIES[_champion_difficulty]["pickup_interval"])
	var training := get_node_or_null("/root/TaijifuGamepadTraining")
	if training != null:
		training.set_meta("training_focus", _training_focus)

func context_snapshot() -> Dictionary:
	return {
		"mode_id": _mode_id,
		"rules": Array(MODE_RULES.get(_mode_id, [])).duplicate(),
		"champion_difficulty": _champion_difficulty,
		"champion_config": Dictionary(CHAMPION_DIFFICULTIES[_champion_difficulty]).duplicate(true),
		"training_focus": _training_focus
	}

func selected_champion_difficulty() -> String:
	return _champion_difficulty

func selected_training_focus() -> String:
	return _training_focus

func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	return label
