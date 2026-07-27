class_name GroupStageRuntime
extends Node

const GUEST_PRESETS: Array[StringName] = [
	&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger",
	&"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"
]

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var preset_runtime: LoadoutPresetRuntime = get_node("../LoadoutPresetRuntime")
@onready var profile_runtime: PlayerProfileRuntime = get_node("../PlayerProfileRuntime")
@onready var tournament_runtime: TournamentRuntime = get_node("../TournamentRuntime")

var ledger := GroupStageLedger.new()
var _sources: Array[Dictionary] = []
var _slot_sources: Array[int] = []
var _selected_slot := 0
var _active_panel := false
var _feedback := "F11 abre • 8 competidores • Enter inicia"
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	ledger.load_from_disk()
	_resize_slots()
	_build_interface()
	_refresh_sources()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"group_stage_toggle"):
		if _active_panel:
			close()
		elif preparation_runtime.is_active():
			open()
	if not _active_panel:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"group_stage_up"):
		_selected_slot = wrapi(_selected_slot - 1, 0, _slot_sources.size())
		_refresh()
	elif Input.is_action_just_pressed(&"group_stage_down"):
		_selected_slot = wrapi(_selected_slot + 1, 0, _slot_sources.size())
		_refresh()
	if Input.is_action_just_pressed(&"group_stage_prev_source"):
		_cycle_source(-1)
	elif Input.is_action_just_pressed(&"group_stage_next_source"):
		_cycle_source(1)
	if Input.is_action_just_pressed(&"group_stage_shuffle"):
		shuffle_slots()
	if Input.is_action_just_pressed(&"group_stage_start"):
		_start_group_stage()
	if Input.is_action_just_pressed(&"group_stage_reset"):
		reset_group_stage()

func open() -> void:
	_active_panel = true
	_canvas.visible = true
	_refresh_sources()
	_refresh()

func close() -> void:
	_active_panel = false
	_canvas.visible = false

func is_group_stage_active() -> bool:
	return ledger.is_active()

func is_group_stage_finished() -> bool:
	return ledger.is_finished()

func current_pair() -> Array[Dictionary]:
	return ledger.current_pair()

func current_profile_context(player_index: int) -> Dictionary:
	var pair := ledger.current_pair()
	if pair.size() != 2:
		return {}
	var participant: Dictionary = pair[clampi(player_index, 1, 2) - 1]
	var source_id := String(participant.get("source", participant.get("participant_id", player_index)))
	for source in _sources:
		if String(source.get("participant_id", "")) == source_id:
			return {
				"profile_id": String(source.get("profile_id", "group_%s" % source_id)),
				"profile_name": String(source.get("profile_name", participant.get("name", "COMPETIDOR")))
			}
	return {
		"profile_id": "group_%s" % String(participant.get("participant_id", player_index)),
		"profile_name": String(participant.get("name", "COMPETIDOR"))
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
	if bool(result.get("finished", false)):
		var knockout_started := _start_knockout_from_qualifiers()
		result["knockout_started"] = knockout_started
		_feedback = "GRUPOS CONCLUÍDOS • SEMIFINAIS PREPARADAS" if knockout_started else "GRUPOS CONCLUÍDOS"
	else:
		var winner_source: Variant = result.get("winner", {})
		var winner: Dictionary = winner_source as Dictionary if winner_source is Dictionary else {}
		_feedback = "%s VENCE • PRÓXIMO: %s" % [String(winner.get("name", "VENCEDOR")), ledger.stage_label()]
	_refresh()
	return result

func reset_group_stage() -> void:
	ledger.reset()
	_resize_slots()
	_selected_slot = 0
	_feedback = "FASE DE GRUPOS REINICIADA"
	_refresh_sources()
	_refresh()

func set_participants_for_test(participants: Array[Dictionary]) -> bool:
	return ledger.set_participants(participants)

func start_for_test() -> bool:
	return ledger.start()

func record_result_for_test(winner_index: int, score_p1: int, score_p2: int) -> Dictionary:
	return ledger.record_result(winner_index, score_p1, score_p2)

func standings_for_test(group_id: String) -> Array[Dictionary]:
	return ledger.standings(group_id)

func qualifiers_for_test() -> Array[Dictionary]:
	return ledger.qualifiers()

func shuffle_for_test(seed_value: int) -> Array[int]:
	shuffle_slots(seed_value)
	return _slot_sources.duplicate()

func shuffle_slots(seed_value: int = 0) -> void:
	if ledger.is_active():
		_feedback = "SORTEIO BLOQUEADO DURANTE A FASE DE GRUPOS"
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
	_feedback = "SORTEIO DOS GRUPOS CONCLUÍDO"
	_refresh()

func _start_group_stage() -> void:
	if ledger.is_active():
		_feedback = "FASE DE GRUPOS JÁ ESTÁ EM ANDAMENTO"
		_refresh()
		return
	_refresh_sources()
	if not ledger.set_participants(_participants_from_slots()) or not ledger.start():
		_feedback = "NÃO FOI POSSÍVEL INICIAR A FASE DE GRUPOS"
		_refresh()
		return
	prepare_current_match()
	close()

func _start_knockout_from_qualifiers() -> bool:
	var participants := ledger.semifinal_participants()
	if participants.size() != 4:
		return false
	tournament_runtime.ledger.reset(4)
	if not tournament_runtime.ledger.set_participants(participants):
		return false
	if not tournament_runtime.ledger.start():
		return false
	return tournament_runtime.prepare_current_match()

func _resize_slots() -> void:
	var old := _slot_sources.duplicate()
	_slot_sources.clear()
	for index in range(GroupStageLedger.PARTICIPANT_COUNT):
		_slot_sources.append(int(old[index]) if index < old.size() else index)
	_selected_slot = clampi(_selected_slot, 0, GroupStageLedger.PARTICIPANT_COUNT - 1)

func _cycle_source(direction: int) -> void:
	if _sources.is_empty():
		return
	_slot_sources[_selected_slot] = wrapi(_slot_sources[_selected_slot] + direction, 0, _sources.size())
	_feedback = "SEED %d ATUALIZADA" % (_selected_slot + 1)
	_refresh()

func _participants_from_slots() -> Array[Dictionary]:
	var participants: Array[Dictionary] = []
	for slot in range(_slot_sources.size()):
		var source_index := clampi(_slot_sources[slot], 0, _sources.size() - 1)
		var participant := _sources[source_index].duplicate(true)
		participant["participant_id"] = "group_seed_%d_%s" % [slot + 1, String(participant.get("participant_id", source_index))]
		participant["seed"] = slot + 1
		participants.append(participant)
	return participants

func _refresh_sources() -> void:
	_sources.clear()
	_sources.append(_source_from_loadout(preparation_runtime.loadout_for_player(1), "current_p1", profile_runtime.profile_context_for_player(1)))
	_sources.append(_source_from_loadout(preparation_runtime.loadout_for_player(2), "current_p2", profile_runtime.profile_context_for_player(2)))
	for player_index in [1, 2]:
		var context := profile_runtime.profile_context_for_player(player_index)
		for preset in preset_runtime.presets_for_player(player_index):
			var loadout_source: Variant = preset.get("loadout", {})
			if loadout_source is Dictionary:
				_sources.append(_source_from_loadout(loadout_source as Dictionary, String(preset.get("preset_id", "preset_%d" % _sources.size())), context))
	while _sources.size() < GroupStageLedger.PARTICIPANT_COUNT:
		var guest_number := _sources.size() + 1
		var preset_id: StringName = GUEST_PRESETS[_sources.size() % GUEST_PRESETS.size()]
		_sources.append(_source_from_loadout(
			BattleLoadoutCatalog.loadout_from_preset(preset_id),
			"group_guest_%d" % guest_number,
			{"profile_id": "group_guest_%d" % guest_number, "profile_name": "CONVIDADO %d" % guest_number}
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
	_title.text = "TAIJIFU MASTERS • FASE DE GRUPOS"
	_report.text = _standings_report() if ledger.is_active() or ledger.is_finished() else _setup_report()
	_footer.text = "F11 fecha • Page Up/Down seed • Home/End fonte • Ctrl+S sorteia • Enter inicia • Delete reinicia\n%s • Tehkné Solutions" % _feedback

func _setup_report() -> String:
	var lines: Array[String] = ["[center][color=#f4d477][font_size=20][b]DISTRIBUIÇÃO DOS OITO COMPETIDORES[/b][/font_size][/color][/center]\n"]
	for slot in range(_slot_sources.size()):
		var source_index := clampi(_slot_sources[slot], 0, maxi(0, _sources.size() - 1))
		var source: Dictionary = _sources[source_index] if not _sources.is_empty() else {}
		var group_id := "A" if slot + 1 in GroupStageLedger.GROUP_SEEDS["A"] else "B"
		var cursor := "[color=#ffd36b]▶[/color]" if slot == _selected_slot else " "
		lines.append("%s SEED %d • GRUPO %s • [b]%s[/b] • %s • %s" % [cursor, slot + 1, group_id, String(source.get("name", "COMPETIDOR")), String(source.get("character_name", "")), String(source.get("build_name", ""))])
	return "\n".join(lines)

func _standings_report() -> String:
	var lines: Array[String] = ["[center][color=#f4d477][font_size=22][b]%s[/b][/font_size][/color][/center]\n" % ledger.stage_label()]
	for group_id in ["A", "B"]:
		lines.append("[color=#8ecff0][font_size=18][b]GRUPO %s[/b][/font_size][/color]" % group_id)
		lines.append("[table=8][cell][b]#[/b][/cell][cell][b]COMPETIDOR[/b][/cell][cell][b]PTS[/b][/cell][cell][b]J[/b][/cell][cell][b]V[/b][/cell][cell][b]D[/b][/cell][cell][b]R+/R−[/b][/cell][cell][b]SALDO[/b][/cell]")
		for entry in ledger.standings(group_id):
			lines.append("[cell]%d[/cell][cell]%s[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d/%d[/cell][cell]%+d[/cell]" % [int(entry.get("position", 0)), String(entry.get("name", "COMPETIDOR")).to_upper(), int(entry.get("points", 0)), int(entry.get("played", 0)), int(entry.get("wins", 0)), int(entry.get("losses", 0)), int(entry.get("rounds_for", 0)), int(entry.get("rounds_against", 0)), int(entry.get("round_diff", 0))])
		lines.append("[/table]\n")
	if ledger.is_finished():
		var labels: Array[String] = []
		for qualifier in ledger.qualifiers():
			labels.append("%s: %s" % [String(qualifier.get("qualification", "")), String(qualifier.get("name", ""))])
		lines.append("[center][color=#70e0a0][b]CLASSIFICADOS • %s[/b][/color][/center]" % " • ".join(labels))
	return "\n".join(lines)

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 240
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 60.0
	_panel.offset_top = 28.0
	_panel.offset_right = 1220.0
	_panel.offset_bottom = 700.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.009, 0.016, 0.028, 0.994)
	style.border_color = Color(0.32, 0.82, 0.94, 0.94)
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
	_title.add_theme_color_override("font_color", Color(0.58, 0.90, 1.0))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1090.0, 550.0)
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
	_add_key_action(&"group_stage_toggle", KEY_F11)
	_add_key_action(&"group_stage_up", KEY_PAGEUP)
	_add_key_action(&"group_stage_down", KEY_PAGEDOWN)
	_add_key_action(&"group_stage_prev_source", KEY_HOME)
	_add_key_action(&"group_stage_next_source", KEY_END)
	_add_key_action(&"group_stage_shuffle", KEY_S, true)
	_add_key_action(&"group_stage_start", KEY_ENTER)
	_add_key_action(&"group_stage_reset", KEY_DELETE)

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
