class_name VsAnalysisRuntime
extends Node

signal analysis_finished

const DISPLAY_SECONDS := 2.85

var _canvas: CanvasLayer
var _background: ColorRect
var _title: Label
var _left: RichTextLabel
var _right: RichTextLabel
var _footer: Label
var _active := false
var _token := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()

func play(player_one_loadout: Dictionary, player_two_loadout: Dictionary, config: Dictionary) -> void:
	_token += 1
	var token := _token
	_active = true
	_canvas.visible = true
	var report := build_report(player_one_loadout, player_two_loadout, config)
	_title.text = "%s\n%s" % [String(report.get("headline", "ANÁLISE VS")), CompetitiveMatchCatalog.config_summary(config)]
	_left.text = String(report.get("p1_text", ""))
	_right.text = String(report.get("p2_text", ""))
	_footer.text = "%s\nA análise indica tendências, não determina o vencedor." % CompetitiveMatchCatalog.arena_summary(config)
	await get_tree().create_timer(DISPLAY_SECONDS, true, false, true).timeout
	if token != _token:
		return
	_active = false
	_canvas.visible = false
	analysis_finished.emit()

func is_active() -> bool:
	return _active

func skip_for_test() -> void:
	if not _active:
		return
	_token += 1
	_active = false
	_canvas.visible = false
	analysis_finished.emit()

func build_report(player_one_loadout: Dictionary, player_two_loadout: Dictionary, config: Dictionary) -> Dictionary:
	var p1 := _resolved_build(player_one_loadout)
	var p2 := _resolved_build(player_two_loadout)
	var p1_analysis := _analyze_side(p1, p2, player_one_loadout, player_two_loadout, config)
	var p2_analysis := _analyze_side(p2, p1, player_two_loadout, player_one_loadout, config)
	return {
		"headline": "%s  VS  %s" % [p1.character_name.to_upper(), p2.character_name.to_upper()],
		"p1_text": _format_side("P1", p1, player_one_loadout, p1_analysis, Color(0.56, 0.84, 1.0)),
		"p2_text": _format_side("P2", p2, player_two_loadout, p2_analysis, Color(1.0, 0.62, 0.48)),
		"p1_strengths": p1_analysis["strengths"], "p1_risks": p1_analysis["risks"],
		"p2_strengths": p2_analysis["strengths"], "p2_risks": p2_analysis["risks"]
	}

func _resolved_build(loadout: Dictionary) -> BuildProfile:
	var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
	var build := BuildProfile.prototype_preset(preset_id)
	build.element_id = StringName(loadout.get("element_id", build.element_id))
	build.weapon_id = StringName(loadout.get("primary_weapon_id", build.weapon_id))
	build.secondary_weapon_id = StringName(loadout.get("secondary_weapon_id", build.secondary_weapon_id))
	return build

func _analyze_side(build: BuildProfile, opponent: BuildProfile, loadout: Dictionary, opponent_loadout: Dictionary, config: Dictionary) -> Dictionary:
	var strengths: Array[String] = []
	var risks: Array[String] = []
	var tai_delta := build.tai_index() - opponent.tai_index()
	var ji_delta := build.ji_index() - opponent.ji_index()
	var fu_delta := build.fu_index() - opponent.fu_index()
	if tai_delta >= 7.0: strengths.append("Mobilidade e iniciativa Tai superiores")
	elif tai_delta <= -7.0: risks.append("Pode perder espaço e altura nas rotas Tai")
	if ji_delta >= 7.0: strengths.append("Maior estabilidade para contato, agarrão e postura")
	elif ji_delta <= -7.0: risks.append("Pressão Ji adversária ameaça postura e desarmamento")
	if fu_delta >= 7.0: strengths.append("Melhor leitura para transições, aparos e adaptação")
	elif fu_delta <= -7.0: risks.append("Menor margem para responder a mudanças de condição")
	var route_bias := CompetitiveMatchCatalog.route_bias(config)
	var route_index := _index_for_route(build, route_bias)
	var opponent_route_index := _index_for_route(opponent, route_bias)
	if route_index >= opponent_route_index + 5.0: strengths.append("A arena favorece seu caminho %s" % String(route_bias).to_upper())
	elif route_index + 5.0 <= opponent_route_index: risks.append("A arena favorece o caminho %s do adversário" % String(route_bias).to_upper())
	var weapon_id := StringName(loadout.get("primary_weapon_id", build.weapon_id))
	var opponent_weapon_id := StringName(opponent_loadout.get("primary_weapon_id", opponent.weapon_id))
	var weapon_range := _weapon_range(weapon_id)
	var opponent_range := _weapon_range(opponent_weapon_id)
	if weapon_range > opponent_range: strengths.append("Maior alcance inicial com %s" % WeaponKitCatalog.label_for(weapon_id))
	elif weapon_range < opponent_range: risks.append("Precisa atravessar o alcance de %s" % WeaponKitCatalog.label_for(opponent_weapon_id))
	var element_id := StringName(loadout.get("element_id", build.element_id))
	var opponent_element := StringName(opponent_loadout.get("element_id", opponent.element_id))
	_append_element_context(element_id, opponent_element, strengths, risks)
	if StringName(loadout.get("variant_id", &"")) != &"": strengths.append("Leva uma variação técnica treinada")
	if strengths.is_empty(): strengths.append("Build equilibrada, sem dependência de uma única rota")
	if risks.is_empty(): risks.append("Risco principal depende da execução e leitura do adversário")
	return {"strengths": strengths.slice(0, 4), "risks": risks.slice(0, 4)}

func _append_element_context(element_id: StringName, opponent_id: StringName, strengths: Array[String], risks: Array[String]) -> void:
	if element_id == opponent_id:
		strengths.append("Espelho elemental: decisão depende do timing")
		return
	if element_id == &"water" and opponent_id == &"fire": strengths.append("Água pode extinguir queimaduras e gerar vapor")
	elif element_id == &"fire" and opponent_id == &"air": strengths.append("Ar adversário pode ampliar sua combustão")
	elif element_id == &"earth" and opponent_id == &"water": strengths.append("Terra pode transformar água em controle por lama")
	elif element_id == &"air" and opponent_id == &"earth": risks.append("Alvos ancorados resistem parte do deslocamento do ar")
	else: strengths.append("Elemento oferece condições situacionais de controle")

func _index_for_route(build: BuildProfile, route_id: StringName) -> float:
	match route_id:
		&"tai": return build.tai_index()
		&"ji": return build.ji_index()
		_: return build.fu_index()

func _weapon_range(weapon_id: StringName) -> int:
	match weapon_id:
		&"training_staff": return 3
		&"wind_wraps": return 2
		&"seismic_gauntlets", &"breaker_gauntlets": return 1
		_: return 0

func _format_side(prefix: String, build: BuildProfile, loadout: Dictionary, analysis: Dictionary, color: Color) -> String:
	var lines: Array[String] = []
	lines.append("[center][color=#%s][font_size=25][b]%s — %s[/b][/font_size][/color][/center]" % [color.to_html(false), prefix, build.character_name.to_upper()])
	lines.append("[center]%s[/center]" % build.display_name)
	lines.append("[center]TAI %d   JI %d   FU %d[/center]" % [roundi(build.tai_index()), roundi(build.ji_index()), roundi(build.fu_index())])
	lines.append("[center]%s • %s[/center]\n" % [WeaponKitCatalog.label_for(StringName(loadout.get("primary_weapon_id", build.weapon_id))), String(loadout.get("element_id", build.element_id)).to_upper()])
	lines.append("[color=#8ee6ad][b]VANTAGENS PROVÁVEIS[/b][/color]")
	for item in analysis["strengths"]: lines.append("• %s" % String(item))
	lines.append("\n[color=#ff9f86][b]RISCOS E CONTRAPONTOS[/b][/color]")
	for item in analysis["risks"]: lines.append("• %s" % String(item))
	return "\n".join(lines)

func _build_interface() -> void:
	_canvas = CanvasLayer.new(); _canvas.layer = 218; _canvas.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(_canvas)
	_background = ColorRect.new(); _background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _background.color = Color(0.008, 0.012, 0.024, 0.985); _background.mouse_filter = Control.MOUSE_FILTER_STOP; _canvas.add_child(_background)
	_title = Label.new(); _title.offset_left = 100.0; _title.offset_top = 28.0; _title.offset_right = 1180.0; _title.offset_bottom = 105.0; _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _title.add_theme_font_size_override("font_size", 24); _title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38)); _background.add_child(_title)
	_left = _create_report_panel(36.0, 126.0, 616.0, 600.0, Color(0.30, 0.68, 1.0))
	_right = _create_report_panel(664.0, 126.0, 1244.0, 600.0, Color(1.0, 0.40, 0.24))
	_footer = Label.new(); _footer.offset_left = 90.0; _footer.offset_top = 612.0; _footer.offset_right = 1190.0; _footer.offset_bottom = 700.0; _footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _footer.add_theme_font_size_override("font_size", 14); _footer.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92)); _background.add_child(_footer)
	_canvas.visible = false

func _create_report_panel(left: float, top: float, right: float, bottom: float, border_color: Color) -> RichTextLabel:
	var panel := PanelContainer.new(); panel.offset_left = left; panel.offset_top = top; panel.offset_right = right; panel.offset_bottom = bottom
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.025, 0.034, 0.055, 0.98); style.border_color = border_color; style.set_border_width_all(2); style.corner_radius_top_left = 12; style.corner_radius_top_right = 12; style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12; panel.add_theme_stylebox_override("panel", style); _background.add_child(panel)
	var report := RichTextLabel.new(); report.bbcode_enabled = true; report.fit_content = false; report.scroll_active = false; report.add_theme_font_size_override("normal_font_size", 15); report.add_theme_font_size_override("bold_font_size", 16); panel.add_child(report); return report
