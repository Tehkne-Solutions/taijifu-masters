class_name TournamentRuntime
extends Node

const GUEST_PRESETS: Array[StringName] = [
	&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger",
	&"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"
]

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var preset_runtime: LoadoutPresetRuntime = get_node("../LoadoutPresetRuntime")

var ledger := TournamentLedger.new()
var _sources: Array[Dictionary] = []
var _slot_sources: Array[int] = []
var _selected_slot := 0
var _active_panel := false
var _feedback := "F10 abre • T alterna 4/8 • ENTER inicia"
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _bracket: RichTextLabel
var _details: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	ledger.load_from_disk()
	_resize_slots(ledger.current_bracket_size())
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
	if Input.is_action_just_pressed(&"tournament_format"):
		_toggle_format()
	if Input.is_action_just_pressed(&"tournament_up"):
		_selected_slot = wrapi(_selected_slot - 1, 0, _slot_sources.size())
		_refresh()
	elif Input.is_action_just_pressed(&"tournament_down"):
		_selected_slot = wrapi(_selected_slot + 1, 0, _slot_sources.size())
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
	_resize_slots(ledger.current_bracket_size())
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

func bracket_size() -> int:
	return ledger.current_bracket_size()

func prepare_current_match() -> bool:
	var pair := ledger.current_pair()
	if pair.size() != 2:
		return false
	var p1: Dictionary = pair[0]
	var p2: Dictionary = pair[1]
	var p1_loadout: Variant = p1.get("loadout", {})
	var p2_loadout: Variant = p2.get("loadout", {})
	if not (p1_loadout is Dictionary) or not (p2_loadout is Dictionary):
		return false
	preparation_runtime.set_loadout_for_test(1, p1_loadout as Dictionary)
	preparation_runtime.set_loadout_for_test(2, p2_loadout as Dictionary)
	preparation_runtime.set_ready_for_test(1, false)
	preparation_runtime.set_ready_for_test(2, false)
	_feedback = "%s • %s VS %s" % [ledger.stage_label(), String(p1.get("name", "P1")), String(p2.get("name", "P2"))]
	_refresh()
	return true

func record_series_winner(winner_index: int) -> Dictionary:
	var result := ledger.record_winner(winner_index)
	if not bool(result.get("ok", false)):
		return result
	var winner_source: Variant = result.get("winner", {})
	var winner: Dictionary = winner_source as Dictionary if winner_source is Dictionary else {}
	if bool(result.get("finished", false)):
		_feedback = "CAMPEÃO: %s" % String(winner.get("name", "CAMPEÃO"))
	else:
		_feedback = "%s AVANÇA • PRÓXIMO: %s" % [String(winner.get("name", "VENCEDOR")), ledger.stage_label()]
	_refresh()
	return result

func reset_tournament() -> void:
	var size := ledger.current_bracket_size()
	ledger.reset(size)
	_resize_slots(size)
	_selected_slot = 0
	_feedback = "TORNEIO REINICIADO • %d COMPETIDORES" % size
	_refresh_sources()
	_refresh()

func set_format_for_test(size: int) -> int:
	var clean := ledger.set_bracket_size(size)
	_resize_slots(clean)
	return clean

func set_participants_for_test(participants: Array[Dictionary]) -> bool:
	return ledger.set_participants(participants)

func start_for_test() -> bool:
	return ledger.start()

func record_winner_for_test(winner_index: int) -> Dictionary:
	return ledger.record_winner(winner_index)

func bracket_snapshot() -> Dictionary:
	return ledger.bracket_snapshot()

func _toggle_panel() -> void:
	if _active_panel:
		close()
	else:
		open()

func _toggle_format() -> void:
	if is_tournament_active():
		_feedback = "FORMATO BLOQUEADO DURANTE O TORNEIO"
		_refresh()
		return
	var next_size := 8 if ledger.current_bracket_size() == 4 else 4
	ledger.set_bracket_size(next_size)
	_resize_slots(next_size)
	_selected_slot = 0
	_refresh_sources()
	_feedback = "FORMATO ALTERADO PARA %d COMPETIDORES" % next_size
	_refresh()

func _resize_slots(size: int) -> void:
	var old := _slot_sources.duplicate()
	_slot_sources.clear()
	for index in range(size):
		_slot_sources.append(int(old[index]) if index < old.size() else index)
	_selected_slot = clampi(_selected_slot, 0, maxi(0, size - 1))

func _cycle_source(direction: int) -> void:
	if _sources.is_empty() or _slot_sources.is_empty():
		return
	_slot_sources[_selected_slot] = wrapi(_slot_sources[_selected_slot] + direction, 0, _sources.size())
	_feedback = "SEED %d ATUALIZADO" % (_selected_slot + 1)
	_refresh()

func _start_tournament() -> void:
	_refresh_sources()
	var size := ledger.current_bracket_size()
	if _sources.is_empty() or _slot_sources.size() != size:
		_feedback = "FONTES INSUFICIENTES PARA O CHAVEAMENTO"
		_refresh()
		return
	var participants: Array[Dictionary] = []
	for slot in range(size):
		var source_index := clampi(_slot_sources[slot], 0, _sources.size() - 1)
		var source: Dictionary = _sources[source_index]
		var participant := source.duplicate(true)
		participant["participant_id"] = "seed_%d_%s" % [slot + 1, String(source.get("participant_id", source_index))]
		participant["seed"] = slot + 1
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
	var required := ledger.current_bracket_size()
	while _sources.size() < required:
		var guest_index := _sources.size() % GUEST_PRESETS.size()
		var fallback_id: StringName = GUEST_PRESETS[guest_index]
		var fallback := BattleLoadoutCatalog.loadout_from_preset(fallback_id)
		_sources.append(_source_from_loadout("CONVIDADO %d" % (_sources.size() + 1), fallback, "guest_%d" % _sources.size()))
	for slot in range(_slot_sources.size()):
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
	_panel.offset_left = 115.0
	_panel.offset_top = 38.0
	_panel.offset_right = 1165.0
	_panel.offset_bottom = 686.0
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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.42))
	column.add_child(_title)
	_bracket = RichTextLabel.new()
	_bracket.custom_minimum_size = Vector2(980.0, 500.0)
	_bracket.bbcode_enabled = true
	_bracket.fit_content = false
	_bracket.scroll_active = true
	_bracket.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_bracket)
	_details = Label.new()
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 12)
	_details.add_theme_color_override("font_color", Color(0.76, 0.84, 0.94))
	column.add_child(_details)
	_canvas.visible = false

func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	_title.text = "TORNEIO LOCAL • %d COMPETIDORES • %s" % [ledger.current_bracket_size(), ledger.stage_label()]
	var lines: Array[String] = []
	if is_tournament_active() or is_tournament_finished():
		lines = _active_bracket_lines()
	else:
		for slot in range(_slot_sources.size()):
			var source_index := clampi(_slot_sources[slot], 0, maxi(0, _sources.size() - 1))
			var source: Dictionary = _sources[source_index] if not _sources.is_empty() else {}
			var prefix := "▶" if slot == _selected_slot else " "
			lines.append("[color=%s]%s SEED %d  •  [b]%s[/b]  •  %s  •  %s[/color]" % [
				"#ffd36b" if slot == _selected_slot else "#d7deeb",
				prefix, slot + 1, String(source.get("name", "VAZIO")),
				String(source.get("character_name", "")), String(source.get("build_name", ""))
			])
	_bracket.text = "\n".join(lines)
	_details.text = "F10 fecha • T alterna 4/8 • Page Up/Down seed • Home/End fonte • ENTER inicia • DEL reinicia\n%s" % _feedback

func _active_bracket_lines() -> Array[String]:
	var lines: Array[String] = []
	var rounds: Array = ledger.data.get("rounds", [])
	for round_index in range(rounds.size()):
		if not (rounds[round_index] is Array):
			continue
		var round_matches: Array = rounds[round_index]
		lines.append("[color=#f4d477][b]%s[/b][/color]" % _round_title(round_index, rounds.size()))
		for match_index in range(round_matches.size()):
			if not (round_matches[match_index] is Dictionary):
				continue
			var match_data: Dictionary = round_matches[match_index]
			var p1 := _participant_name(match_data.get("p1", {}))
			var p2 := _participant_name(match_data.get("p2", {}))
			var winner := _participant_name(match_data.get("winner", {}))
			var marker := "▶" if round_index == int(ledger.data.get("round_index", 0)) and match_index == int(ledger.data.get("match_index", 0)) and is_tournament_active() else " "
			var suffix := " • vencedor %s" % winner if winner != "A DEFINIR" else ""
			lines.append("%s %d. %s  VS  %s%s" % [marker, match_index + 1, p1, p2, suffix])
		lines.append("")
	var champion := champion_name()
	if champion != "":
		lines.append("[center][color=#ffd36b][font_size=24][b]CAMPEÃO: %s[/b][/font_size][/color][/center]" % champion)
	return lines

func _round_title(round_index: int, round_count: int) -> String:
	if round_count >= 3:
		return ["QUARTAS DE FINAL", "SEMIFINAIS", "FINAL"][clampi(round_index, 0, 2)]
	return ["SEMIFINAIS", "FINAL"][clampi(round_index, 0, 1)]

func _participant_name(source: Variant) -> String:
	if not (source is Dictionary) or (source as Dictionary).is_empty():
		return "A DEFINIR"
	var participant: Dictionary = source
	var seed := int(participant.get("seed", 0))
	var seed_label := "#%d " % seed if seed > 0 else ""
	return "%s%s" % [seed_label, String(participant.get("name", "A DEFINIR"))]

func _register_inputs() -> void:
	_add_key_action(&"tournament_toggle", KEY_F10)
	_add_key_action(&"tournament_format", KEY_T)
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
