class_name LoadoutShareCodeRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var competitive_runtime: CompetitiveMatchRuntime = get_node("../CompetitiveMatchRuntime")
@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

var _player_index := 1
var _feedback := "CTRL+SHIFT+C copia • CTRL+SHIFT+V importa • K alterna jogador"
var _canvas: CanvasLayer
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_status()

func _process(_delta: float) -> void:
	_canvas.visible = preparation_runtime.is_active()
	if not preparation_runtime.is_active():
		return
	if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_C) and not Input.is_action_pressed(&"share_code_copy_lock"):
			_copy_current()
			Input.action_press(&"share_code_copy_lock")
		elif not Input.is_key_pressed(KEY_C):
			Input.action_release(&"share_code_copy_lock")
		if Input.is_key_pressed(KEY_V) and not Input.is_action_pressed(&"share_code_paste_lock"):
			_import_clipboard()
			Input.action_press(&"share_code_paste_lock")
		elif not Input.is_key_pressed(KEY_V):
			Input.action_release(&"share_code_paste_lock")
	else:
		Input.action_release(&"share_code_copy_lock")
		Input.action_release(&"share_code_paste_lock")
	if Input.is_key_pressed(KEY_K) and not Input.is_action_pressed(&"share_code_player_lock"):
		_player_index = 2 if _player_index == 1 else 1
		_feedback = "CÓDIGO COMPACTO DIRECIONADO AO P%d" % _player_index
		Input.action_press(&"share_code_player_lock")
	elif not Input.is_key_pressed(KEY_K):
		Input.action_release(&"share_code_player_lock")
	_refresh()

func code_for_player(player_index: int) -> String:
	var index := clampi(player_index, 1, 2)
	var loadout := preparation_runtime.loadout_for_player(index)
	var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
	return LoadoutShareCode.encode_preset({
		"name": "%s • %s" % [build.character_name.to_upper(), build.display_name.to_upper()],
		"loadout": loadout,
		"match_config": competitive_runtime.current_config()
	})

func apply_code_for_test(player_index: int, code: String) -> bool:
	var result := LoadoutShareCode.decode_code(code, _unlocked_for(player_index))
	if not bool(result.get("ok", false)):
		return false
	var preset: Dictionary = result.get("preset", {})
	var loadout_source: Variant = preset.get("loadout", {})
	var config_source: Variant = preset.get("match_config", {})
	if not (loadout_source is Dictionary):
		return false
	preparation_runtime.set_loadout_for_test(player_index, loadout_source as Dictionary)
	if config_source is Dictionary:
		competitive_runtime.set_config_for_test(config_source as Dictionary)
	return true

func _copy_current() -> void:
	var code := code_for_player(_player_index)
	if code == "":
		_feedback = "FALHA AO GERAR CÓDIGO"
		return
	DisplayServer.clipboard_set(code)
	_feedback = "CÓDIGO DO P%d COPIADO • %d CARACTERES" % [_player_index, code.length()]

func _import_clipboard() -> void:
	var code := DisplayServer.clipboard_get().strip_edges()
	var result := LoadoutShareCode.decode_code(code, _unlocked_for(_player_index))
	if not bool(result.get("ok", false)):
		_feedback = "FALHA: %s" % String(result.get("error", "CÓDIGO INVÁLIDO"))
		return
	if apply_code_for_test(_player_index, code):
		_feedback = "CÓDIGO APLICADO AO P%d" % _player_index
	else:
		_feedback = "CÓDIGO NÃO PÔDE SER APLICADO"

func _unlocked_for(player_index: int) -> Array:
	return master_training_runtime.ledger.unlocked_variants("p%d" % clampi(player_index, 1, 2))

func _build_status() -> void:
	for action_id in [&"share_code_copy_lock", &"share_code_paste_lock", &"share_code_player_lock"]:
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id)
	_canvas = CanvasLayer.new()
	_canvas.layer = 232
	add_child(_canvas)
	_label = Label.new()
	_label.offset_left = 330.0
	_label.offset_top = 646.0
	_label.offset_right = 950.0
	_label.offset_bottom = 706.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.64, 0.92, 0.86))
	_canvas.add_child(_label)
	_refresh()

func _refresh() -> void:
	if is_instance_valid(_label):
		_label.text = "CÓDIGO COMPACTO • P%d\n%s" % [_player_index, _feedback]
