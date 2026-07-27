class_name TournamentRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var preset_runtime: LoadoutPresetRuntime = get_node("../LoadoutPresetRuntime")

var ledger := TournamentLedger.new()
var _sources: Array[Dictionary] = []
var _slot_sources: Array[int] = [0, 1, 2, 3]
var _selected_slot := 0
var _active_panel := false
var _feedback := "F10 abre • setas configuram • ENTER inicia • DEL reinicia"
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _bracket: RichTextLabel
var _details: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	ledger.load_from_disk()
	_build_interface()
	_refresh_sources()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"tournament_toggle"):
		_toggle_panel()
	if not _active_panel:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"tournament_up"):
		_selected_slot = wrapi(_selected_slot - 1, 0, 4)
		_refresh()
	elif Input.is_action_just_pressed(&"tournament_down"):
		_selected_slot = wrapi(_selected_slot + 1, 0, 4)
		_refresh()
	if Input.is_action_just_pressed(&"tournament_prev"):
		_cycle_source(-1)
	elif Input.is_action_just_pressed(&"tournament_next"):
		_cycle_source(1)
	if Input.is_action_just_pressed(&"tournament_start"):
		_start_tournament()
	if Input.is_action_just_pressed(&"tournament_reset"):
		reset_tournament()

func open() -> void:
	if not preparation_runtime.is_active():
		_feedback = "O TORNEIO SÓ PODE SER CONFIGURADO NA PREPARAÇÃO"
		return
	_active_panel = true
	_canvas.visible = true
	_refresh_sources()
	_refresh()

func close() -> void:
	_active_panel = false
	_canvas.visible = false

func is_tournament_active() -> bool:
	return bool(ledger.data.get("active", false))

func is_tournament_finished() -> bool:
	return bool(ledger.data.get("finished", false))

func current_pair() -> Array[Dictionary]:
	return ledger.current_pair()

func champion_name() -> String:
	return String(ledger.champion().get("name", ""))

func prepare_current_match() -> bool:
	var pair := ledger.current_pair()
	if pair.size() != 2:
		return false
	var p1: Dictionary = pair[0]
	var p2: Dictionary = pair[1]
	preparation_runtime.set_loadout_for_test(1, p1.get("loadout", {}) as Dictionary)
	preparation_runtime.set_loadout_for_test(2, p2.get("loadout", {}) as Dictionary)
	preparation_runtime.set_ready_for_test(1, false)
	preparation_runtime.set_ready_for_test(2, false)
	_feedback = "%s • %s VS %s" % [ledger.stage_label(), String(p1.get("name", "P1")), String(p2.get("name", "P2"))]
	_refresh()
	return true

func record_series_winner(winner_index: int) -> Dictionary:
	var result := ledger.record_winner(winner_index)
	if not bool(result.get("ok", false)):
		return result
	var winner: Dictionary = result.get("winner", {})
	if bool(result.get("finished", false)):
		_feedback = "CAMPEÃO: %s" % String(winner.get("name", "CAMPEÃO"))
	else:
		_feedback = "%s AVANÇA • PRÓXIMO: %s" % [String(winner.get("name", "VENCEDOR")), ledger.stage_label()]
	_refresh()
	return result

func reset_tournament() -> void:
	ledger.reset()
	_slot_sources = [0, 1, 2, 3]
	_selected_slot = 0
	_feedback = "TORNEIO REINICIADO"
	_refresh_sources()
	_refresh()

func set_participants_for_test(participants: Array[Dictionary]) -> bool:
	return ledger.set_participants(participants)

func start_for_test() -> bool:
	return ledger.start()

func record_winner_for_test(winner_index: int) -> Dictionary:
	return ledger.record_winner(winner_index)

func bracket_snapshot() -> Dictionary:
	return ledger.data.duplicate(true)

func _toggle_panel() -> void:
	if _active_panel:
		close()
	else:
		open()

func _cycle_source(direction: int) -> void:
	if _sources.is_empty():
		return
	_slot_sources[_selected_slot] = wrapi(_slot_sources[_selected_slot] + direction, 0, _sources.size())
	_feedback = "COMPETIDOR %d ATUALIZADO" % (_selected_slot + 1)
	_refresh()

func _start_tournament() -> void:
	_refresh_sources()
	if _sources.is_empty():
		_feedback = "NENHUMA FONTE DE LOADOUT DISPONÍVEL"
		_refresh()
		return
	var participants: Array[Dictionary] = []
	for slot in range(4):
		var source_index := clampi(_slot_sources[slot], 0, _sources.size() - 1)
		var source: Dictionary = _sources[source_index]
		var participant := source.duplicate(true)
		participant["participant_id"] = "slot_%d_%s" % [slot + 1, String(source.get("participant_id", source_index))]
		participants.append(participant)
	if not ledger.set_participants(participants) or not ledger.start():
		_feedback = "NÃO FOI POSSÍVEL INICIAR O TORNEIO"
		_refresh()
		return
	prepare_current_match()
	close()

func _refresh_sources() -> void:
	_sources.clear()
	_sources.append(_source_from_loadout("P1 ATUAL", preparation_runtime.loadout_for_player(1), "current_p1"))
	_sources.append(_source_from_loadout("P2 ATUAL", preparation_runtime.loadout_for_player(2), "current_p2"))
	for player_index in [1, 2]:
		for preset in preset_runtime.presets_for_player(player_index):
			var loadout_source: Variant = preset.get("loadout", {})
			if not (loadout_source is Dictionary):
				continue
			_sources.append(_source_from_loadout(
				String(preset.get("name", "PRESET P%d" % player_index)),
				loadout_source as Dictionary,
				String(preset.get("preset_id", "preset_%d" % _sources.size()))
			))
	while _sources.size() < 4:
		var fallback_id := [&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger"][_sources.size() % 4]
		var fallback := BattleLoadoutCatalog.default_loadout(1)
		fallback["preset_id"] = fallback_id
		_sources.append(_source_from_loadout("CONVIDADO %d" % (_sources.size() + 1), fallback, "guest_%d" % _sources.size()))
	for slot in range(4):
		_slot_sources[slot] = clampi(_slot_sources[slot], 0, _sources.size() - 1)

func _source_from_loadout(name: String, loadout: Dictionary, source_id: String) -> Dictionary:
	var clean := BattleLoadoutCatalog.sanitize(loadout)
	var build := BuildProfile.prototype_preset(StringName(clean.get("preset_id", &"adaptive_staff")))
	return {
		"participant_id": source_id,
		"name": name.left(36),
		"character_name": build.character_name,
		"build_name": build.display_name,
		"loadout": clean,
		"source": source_id
	}

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 238
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 170.0
	_panel.offset_top = 64.0
	_panel.offset_right = 1110.0
	_panel.offset_bottom = 656.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.020, 0.036, 0.988)
	style.border_color = Color(0.94, 0.64, 0.24, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 25)
	_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.42))
	column.add_child(_title)
	_bracket = RichTextLabel.new()
	_bracket.custom_minimum_size = Vector2(900.0, 420.0)
	_bracket.bbcode_enabled = true
	_bracket.fit_content = false
	_bracket.scroll_active = false
	_bracket.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_bracket)
	_details = Label.new()
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 13)
	_details.add_theme_color_override("font_color", Color(0.76, 0.84, 0.94))
	column.add_child(_details)
	_canvas.visible = false

func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	_title.text = "TORNEIO LOCAL • %s" % ledger.stage_label()
	var lines: Array[String] = []
	if bool(ledger.data.get("active", false)) or bool(ledger.data.get("finished", false)):
		var participants: Array = ledger.data.get("participants", [])
		var winners: Array = ledger.data.get("semifinal_winners", [])
		lines.append("[center][b]SEMIFINAL A[/b]  %s  VS  %s[/center]" % [_name_at(participants, 0), _name_at(participants, 1)])
		lines.append("[center][b]SEMIFINAL B[/b]  %s  VS  %s[/center]" % [_name_at(participants, 2), _name_at(participants, 3)])
		lines.append("\n[center][b]FINAL[/b]  %s  VS  %s[/center]" % [_name_at(winners, 0), _name_at(winners, 1)])
		var champion := champion_name()
		if champion != "":
			lines.append("\n[center][color=#ffd36b][font_size=24][b]CAMPEÃO: %s[/b][/font_size][/color][/center]" % champion)
	else:
		for slot in range(4):
			var source_index := clampi(_slot_sources[slot], 0, maxi(0, _sources.size() - 1))
			var source: Dictionary = _sources[source_index] if not _sources.is_empty() else {}
			var prefix := "▶" if slot == _selected_slot else " "
			lines.append("[color=%s]%s COMPETIDOR %d  •  [b]%s[/b]  •  %s  •  %s[/color]" % [
				"#ffd36b" if slot == _selected_slot else "#d7deeb",
				prefix, slot + 1, String(source.get("name", "VAZIO")),
				String(source.get("character_name", "")), String(source.get("build_name", ""))
			])
	_bracket.text = "\n\n".join(lines)
	_details.text = "F10 fecha • ↑/↓ competidor • ←/→ fonte • ENTER inicia • DEL reinicia\n%s" % _feedback

func _name_at(source: Array, index: int) -> String:
	if index < 0 or index >= source.size() or not (source[index] is Dictionary):
		return "A DEFINIR"
	return String((source[index] as Dictionary).get("name", "A DEFINIR"))

func _register_inputs() -> void:
	_add_key_action(&"tournament_toggle", KEY_F10)
	_add_key_action(&"tournament_up", KEY_PAGEUP)
	_add_key_action(&"tournament_down", KEY_PAGEDOWN)
	_add_key_action(&"tournament_prev", KEY_HOME)
	_add_key_action(&"tournament_next", KEY_END)
	_add_key_action(&"tournament_start", KEY_ENTER)
	_add_key_action(&"tournament_reset", KEY_DELETE)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
