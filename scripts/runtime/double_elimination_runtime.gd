class_name DoubleEliminationRuntime
extends Node

const GUEST_PRESETS: Array[StringName] = [
	&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger",
	&"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"
]

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var preset_runtime: LoadoutPresetRuntime = get_node("../LoadoutPresetRuntime")
@onready var profile_runtime: PlayerProfileRuntime = get_node("../PlayerProfileRuntime")
@onready var tournament_runtime: TournamentRuntime = get_node("../TournamentRuntime")
@onready var group_stage_runtime: GroupStageRuntime = get_node("../GroupStageRuntime")

var ledger := DoubleEliminationLedger.new()
var _sources: Array[Dictionary] = []
var _slot_sources: Array[int] = []
var _selected_slot := 0
var _active_panel := false
var _feedback := "F12 abre • T alterna 4/8 • Enter inicia"
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	ledger.load_from_disk()
	_resize_slots(ledger.current_bracket_size())
	_build_interface()
	_refresh_sources()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"double_elimination_toggle"):
		if _active_panel:
			close()
		elif preparation_runtime.is_active():
			open()
	if not _active_panel:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"double_elimination_format"):
		_toggle_format()
	if Input.is_action_just_pressed(&"double_elimination_up"):
		_selected_slot = wrapi(_selected_slot - 1, 0, _slot_sources.size())
		_refresh()
	elif Input.is_action_just_pressed(&"double_elimination_down"):
		_selected_slot = wrapi(_selected_slot + 1, 0, _slot_sources.size())
		_refresh()
	if Input.is_action_just_pressed(&"double_elimination_prev"):
		_cycle_source(-1)
	elif Input.is_action_just_pressed(&"double_elimination_next"):
		_cycle_source(1)
	if Input.is_action_just_pressed(&"double_elimination_shuffle"):
		shuffle_slots()
	if Input.is_action_just_pressed(&"double_elimination_start"):
		_start_double_elimination()
	if Input.is_action_just_pressed(&"double_elimination_reset"):
		reset_double_elimination()

func open() -> void:
	_active_panel = true
	_canvas.visible = true
	_resize_slots(ledger.current_bracket_size())
	_refresh_sources()
	_refresh()

func close() -> void:
	_active_panel = false
	_canvas.visible = false

func is_double_elimination_active() -> bool:
	return ledger.is_active()

func is_double_elimination_finished() -> bool:
	return ledger.is_finished()

func current_pair() -> Array[Dictionary]:
	return ledger.current_pair()

func current_profile_context(player_index: int) -> Dictionary:
	var pair := ledger.current_pair()
	if pair.size() != 2:
		return {}
	var participant: Dictionary = pair[clampi(player_index, 1, 2) - 1]
	return {
		"profile_id": String(participant.get("profile_id", "double_%s" % String(participant.get("participant_id", player_index)))),
		"profile_name": String(participant.get("profile_name", participant.get("name", "COMPETIDOR")))
	}

func competition_context() -> Dictionary:
	var match_data := ledger.current_match()
	return {
		"competition_mode": "double_elimination",
		"competition_stage": String(match_data.get("stage_label", ledger.stage_label())),
		"competition_match_id": String(match_data.get("match_id", "")),
		"competition_bracket": String(match_data.get("bracket", ""))
	}

func prepare_current_match() -> bool:
	var pair := ledger.current_pair()
	if pair.size() != 2:
		return false
	var p1_loadout: Variant = pair[0].get("loadout", {})
	var p2_loadout: Variant = pair[1].get("loadout", {})
	if not (p1_loadout is Dictionary) or not (p2_loadout is Dictionary):
		return false
	preparation_runtime.set_loadout_for_test(1, p1_loadout as Dictionary)
	preparation_runtime.set_loadout_for_test(2, p2_loadout as Dictionary)
	preparation_runtime.set_ready_for_test(1, false)
	preparation_runtime.set_ready_for_test(2, false)
	_feedback = "%s • %s VS %s" % [ledger.stage_label(), String(pair[0].get("name", "P1")), String(pair[1].get("name", "P2"))]
	_refresh()
	return true

func record_series_result(winner_index: int, score_p1: int, score_p2: int) -> Dictionary:
	var result := ledger.record_result(winner_index, score_p1, score_p2)
	if not bool(result.get("ok", false)):
		return result
	var winner_source: Variant = result.get("winner", {})
	var loser_source: Variant = result.get("loser", {})
	var winner: Dictionary = winner_source as Dictionary if winner_source is Dictionary else {}
	var loser: Dictionary = loser_source as Dictionary if loser_source is Dictionary else {}
	if bool(result.get("finished", false)):
		_feedback = "CAMPEÃO DA DUPLA ELIMINAÇÃO: %s" % String(winner.get("name", "CAMPEÃO"))
	elif bool(result.get("reset_required", false)):
		_feedback = "%s FORÇA O RESET DA GRANDE FINAL" % String(winner.get("name", "VENCEDOR"))
	elif bool(result.get("eliminated", false)):
		_feedback = "%s ELIMINADO • PRÓXIMO: %s" % [String(loser.get("name", "COMPETIDOR")), ledger.stage_label()]
	else:
		_feedback = "%s AVANÇA • %s CAI PARA A CHAVE INFERIOR" % [String(winner.get("name", "VENCEDOR")), String(loser.get("name", "COMPETIDOR"))]
	_refresh()
	return result

func champion_name() -> String:
	return String(ledger.champion().get("name", ""))

func reset_double_elimination() -> void:
	var size := ledger.current_bracket_size()
	ledger.reset(size)
	_resize_slots(size)
	_selected_slot = 0
	_feedback = "DUPLA ELIMINAÇÃO REINICIADA • %d COMPETIDORES" % size
	_refresh_sources()
	_refresh()

func start_with_participants(participants: Array[Dictionary]) -> bool:
	if participants.size() not in DoubleEliminationLedger.VALID_SIZES:
		return false
	ledger.reset(participants.size())
	if not ledger.set_participants(participants):
		return false
	if not ledger.start():
		return false
	_resize_slots(participants.size())
	_feedback = "DUPLA ELIMINAÇÃO INICIADA • %d COMPETIDORES" % participants.size()
	return prepare_current_match()

func set_format_for_test(size: int) -> int:
	var clean := ledger.set_bracket_size(size)
	_resize_slots(clean)
	return clean

func set_participants_for_test(participants: Array[Dictionary]) -> bool:
	return ledger.set_participants(participants)

func start_for_test() -> bool:
	return ledger.start()

func record_result_for_test(winner_index: int, score_p1: int, score_p2: int) -> Dictionary:
	return ledger.record_result(winner_index, score_p1, score_p2)

func shuffle_for_test(seed_value: int) -> Array[int]:
	shuffle_slots(seed_value)
	return _slot_sources.duplicate()

func bracket_snapshot() -> Dictionary:
	return ledger.bracket_snapshot()

func shuffle_slots(seed_value: int = 0) -> void:
	if ledger.is_active():
		_feedback = "SORTEIO BLOQUEADO DURANTE O TORNEIO"
		_refresh()
		return
	_refresh_sources()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	for index in range(_slot_sources.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := _slot_sources[index]
		_slot_sources[index] = _slot_sources[other]
		_slot_sources[other] = temporary
	_feedback = "SORTEIO DA DUPLA ELIMINAÇÃO CONCLUÍDO"
	_refresh()

func _start_double_elimination() -> void:
	if ledger.is_active():
		_feedback = "DUPLA ELIMINAÇÃO JÁ ESTÁ EM ANDAMENTO"
		_refresh()
		return
	if group_stage_runtime.is_group_stage_active() or tournament_runtime.is_tournament_active():
		_feedback = "CONCLUA OU REINICIE O MODO COMPETITIVO ATIVO"
		_refresh()
		return
	_refresh_sources()
	var participants := _participants_from_slots()
	if not ledger.set_participants(participants) or not ledger.start():
		_feedback = "NÃO FOI POSSÍVEL INICIAR A DUPLA ELIMINAÇÃO"
		_refresh()
		return
	prepare_current_match()
	close()

func _toggle_format() -> void:
	if ledger.is_active():
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

func _participants_from_slots() -> Array[Dictionary]:
	var participants: Array[Dictionary] = []
	for slot in range(_slot_sources.size()):
		var source_index := clampi(_slot_sources[slot], 0, _sources.size() - 1)
		var participant := _sources[source_index].duplicate(true)
		participant["participant_id"] = "double_seed_%d_%s" % [slot + 1, String(participant.get("participant_id", source_index))]
		participant["seed"] = slot + 1
		participants.append(participant)
	return participants

func _refresh_sources() -> void:
	_sources.clear()
	_sources.append(_source_from_loadout(preparation_runtime.loadout_for_player(1), "double_current_p1", profile_runtime.profile_context_for_player(1)))
	_sources.append(_source_from_loadout(preparation_runtime.loadout_for_player(2), "double_current_p2", profile_runtime.profile_context_for_player(2)))
	for player_index in [1, 2]:
		var context := profile_runtime.profile_context_for_player(player_index)
		for preset in preset_runtime.presets_for_player(player_index):
			var loadout_source: Variant = preset.get("loadout", {})
			if loadout_source is Dictionary:
				_sources.append(_source_from_loadout(loadout_source as Dictionary, "double_%s" % String(preset.get("preset_id", _sources.size())), context))
	var required := ledger.current_bracket_size()
	while _sources.size() < required:
		var guest_number := _sources.size() + 1
		var preset_id: StringName = GUEST_PRESETS[_sources.size() % GUEST_PRESETS.size()]
		_sources.append(_source_from_loadout(
			BattleLoadoutCatalog.loadout_from_preset(preset_id),
			"double_guest_%d" % guest_number,
			{"profile_id": "double_guest_%d" % guest_number, "profile_name": "CONVIDADO %d" % guest_number}
		))
	for slot in range(_slot_sources.size()):
		_slot_sources[slot] = clampi(_slot_sources[slot], 0, _sources.size() - 1)

func _source_from_loadout(loadout: Dictionary, source_id: String, profile_context: Dictionary) -> Dictionary:
	var clean := BattleLoadoutCatalog.sanitize(loadout)
	var build := BuildProfile.prototype_preset(StringName(clean.get("preset_id", &"adaptive_staff")))
	var profile_name := String(profile_context.get("profile_name", build.character_name)).left(36)
	return {
		"participant_id": source_id,
		"name": profile_name,
		"profile_id": String(profile_context.get("profile_id", source_id)),
		"profile_name": profile_name,
		"character_name": build.character_name,
		"build_name": build.display_name,
		"loadout": clean,
		"source": source_id
	}

func _refresh() -> void:
	if not is_instance_valid(_report):
		return
	_title.text = "TAIJIFU MASTERS • DUPLA ELIMINAÇÃO • %d COMPETIDORES" % ledger.current_bracket_size()
	_report.text = _bracket_report() if ledger.is_active() or ledger.is_finished() else _setup_report()
	_footer.text = "F12 fecha • T 4/8 • Page Up/Down seed • Home/End fonte • Ctrl+S sorteia • Enter inicia • Delete reinicia\n%s • Tehkné Solutions" % _feedback

func _setup_report() -> String:
	var lines: Array[String] = ["[center][color=#f4d477][font_size=20][b]CONFIGURAÇÃO DA DUPLA ELIMINAÇÃO[/b][/font_size][/color][/center]", "[center]A primeira derrota envia à chave inferior. A segunda elimina.[/center]\n"]
	for slot in range(_slot_sources.size()):
		var source_index := clampi(_slot_sources[slot], 0, maxi(0, _sources.size() - 1))
		var source: Dictionary = _sources[source_index] if not _sources.is_empty() else {}
		var cursor := "[color=#ffd36b]▶[/color]" if slot == _selected_slot else " "
		lines.append("%s SEED %d • [b]%s[/b] • %s • %s" % [cursor, slot + 1, String(source.get("name", "COMPETIDOR")), String(source.get("character_name", "")), String(source.get("build_name", ""))])
	return "\n".join(lines)

func _bracket_report() -> String:
	var lines: Array[String] = ["[center][color=#f4d477][font_size=21][b]%s[/b][/font_size][/color][/center]\n" % ledger.stage_label()]
	for bracket_id in [&"upper", &"lower", &"grand_final", &"reset"]:
		var bracket_matches: Array[Dictionary] = []
		for match_data in ledger.all_matches():
			if StringName(match_data.get("bracket", &"upper")) == bracket_id and bool(match_data.get("enabled", true)):
				bracket_matches.append(match_data)
		if bracket_matches.is_empty():
			continue
		lines.append("[color=%s][font_size=17][b]%s[/b][/font_size][/color]" % [_bracket_color(bracket_id), _bracket_label(bracket_id)])
		for match_data in bracket_matches:
			var current := String(match_data.get("match_id", "")) == String(ledger.data.get("current_match_id", "")) and ledger.is_active()
			var cursor := "[color=#ffd36b]▶[/color]" if current else " "
			var p1 := _participant_label(match_data.get("p1", {}))
			var p2 := _participant_label(match_data.get("p2", {}))
			var winner := _participant_label(match_data.get("winner", {}))
			var suffix := " • [color=#70e0a0]vencedor %s[/color]" % winner if bool(match_data.get("completed", false)) else ""
			lines.append("%s %s • %s VS %s%s" % [cursor, String(match_data.get("stage_label", "CONFRONTO")), p1, p2, suffix])
		lines.append("")
	lines.append("[color=#8ecff0][font_size=17][b]VIDAS COMPETITIVAS[/b][/font_size][/color]")
	for participant_value in ledger.data.get("participants", []):
		if not (participant_value is Dictionary):
			continue
		var participant: Dictionary = participant_value
		var participant_id := String(participant.get("participant_id", ""))
		var losses := ledger.loss_count(participant_id)
		var status := ledger.participant_status(participant_id)
		lines.append("• #%d %s • derrotas %d/2 • %s" % [int(participant.get("seed", 0)), String(participant.get("name", "COMPETIDOR")), losses, _status_label(status)])
	var champion := ledger.champion()
	if not champion.is_empty():
		lines.append("\n[center][color=#ffd36b][font_size=24][b]CAMPEÃO: %s[/b][/font_size][/color][/center]" % String(champion.get("name", "CAMPEÃO")))
	return "\n".join(lines)

func _participant_label(source: Variant) -> String:
	if not (source is Dictionary) or (source as Dictionary).is_empty():
		return "A DEFINIR"
	var participant: Dictionary = source
	return "#%d %s" % [int(participant.get("seed", 0)), String(participant.get("name", "COMPETIDOR"))]

func _bracket_label(bracket_id: StringName) -> String:
	return {&"upper": "CHAVE SUPERIOR", &"lower": "CHAVE INFERIOR", &"grand_final": "GRANDE FINAL", &"reset": "RESET DA FINAL"}.get(bracket_id, String(bracket_id).to_upper())

func _bracket_color(bracket_id: StringName) -> String:
	return {&"upper": "#8ecff0", &"lower": "#ef9b72", &"grand_final": "#f4d477", &"reset": "#c89cff"}.get(bracket_id, "#d7deeb")

func _status_label(status: StringName) -> String:
	return {&"upper": "INVICTO • CHAVE SUPERIOR", &"lower": "UMA VIDA • CHAVE INFERIOR", &"eliminated": "ELIMINADO", &"champion": "CAMPEÃO"}.get(status, String(status).to_upper())

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 241
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 74.0
	_panel.offset_top = 28.0
	_panel.offset_right = 1206.0
	_panel.offset_bottom = 700.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.016, 0.030, 0.992)
	style.border_color = Color(0.78, 0.54, 1.0, 0.94)
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
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1060.0, 540.0)
	_report.bbcode_enabled = true
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_report)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 11)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	column.add_child(_footer)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"double_elimination_toggle", KEY_F12)
	_add_key_action(&"double_elimination_format", KEY_T)
	_add_key_action(&"double_elimination_up", KEY_PAGEUP)
	_add_key_action(&"double_elimination_down", KEY_PAGEDOWN)
	_add_key_action(&"double_elimination_prev", KEY_HOME)
	_add_key_action(&"double_elimination_next", KEY_END)
	_add_key_action(&"double_elimination_shuffle", KEY_S, true)
	_add_key_action(&"double_elimination_start", KEY_ENTER)
	_add_key_action(&"double_elimination_reset", KEY_DELETE)

func _add_key_action(action_id: StringName, keycode: Key, ctrl_pressed: bool = false) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode and existing.ctrl_pressed == ctrl_pressed:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl_pressed
	InputMap.action_add_event(action_id, event)
