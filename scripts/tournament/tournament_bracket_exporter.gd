class_name TournamentBracketExporter
extends RefCounted

const EXPORT_DIR := "user://exports"
const SIGNATURE := "TAIJIFU_TOURNAMENT_BRACKET"

static func export_snapshot(snapshot: Dictionary) -> Dictionary:
	var participants: Array = snapshot.get("participants", [])
	if participants.is_empty():
		return {"ok": false, "error": "Chaveamento sem participantes"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var base_name := "taijifu-bracket-%d-%s" % [int(snapshot.get("bracket_size", participants.size())), stamp]
	var json_path := "%s/%s.json" % [EXPORT_DIR, base_name]
	var svg_path := "%s/%s.svg" % [EXPORT_DIR, base_name]
	var png_path := "%s/%s.png" % [EXPORT_DIR, base_name]
	var payload := {
		"signature": SIGNATURE,
		"version": 2,
		"exported_unix": int(Time.get_unix_time_from_system()),
		"bracket": snapshot.duplicate(true)
	}
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		return {"ok": false, "error": "Não foi possível criar o JSON"}
	json_file.store_string(JSON.stringify(payload, "\t"))
	var svg := build_svg(snapshot)
	var svg_file := FileAccess.open(svg_path, FileAccess.WRITE)
	if svg_file == null:
		return {"ok": false, "error": "Não foi possível criar o SVG"}
	svg_file.store_string(svg)
	var image := Image.new()
	var svg_error := image.load_svg_from_buffer(svg.to_utf8_buffer(), 1.0)
	if svg_error != OK:
		return {"ok": false, "error": "SVG criado, mas não foi possível renderizar o PNG", "svg_path": svg_path, "json_path": json_path}
	var png_error := image.save_png(png_path)
	if png_error != OK:
		return {"ok": false, "error": "SVG criado, mas não foi possível salvar o PNG", "svg_path": svg_path, "json_path": json_path}
	return {
		"ok": true,
		"json_path": json_path,
		"svg_path": svg_path,
		"png_path": png_path,
		"json_absolute": ProjectSettings.globalize_path(json_path),
		"svg_absolute": ProjectSettings.globalize_path(svg_path),
		"png_absolute": ProjectSettings.globalize_path(png_path),
		"png_width": image.get_width(),
		"png_height": image.get_height()
	}

static func build_svg(snapshot: Dictionary) -> String:
	var size := int(snapshot.get("bracket_size", 4))
	var rounds: Array = snapshot.get("rounds", [])
	var width := 1500 if size == 8 else 1120
	var height := 900 if size == 8 else 620
	var column_count := 3 if size == 8 else 2
	var column_width := float(width - 120) / float(column_count)
	var parts: Array[String] = []
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [width, height, width, height])
	parts.append("<rect width=\"100%%\" height=\"100%%\" fill=\"#070b14\"/>")
	parts.append("<text x=\"%d\" y=\"48\" text-anchor=\"middle\" fill=\"#f4d477\" font-family=\"sans-serif\" font-size=\"28\" font-weight=\"700\">TAIJIFU MASTERS • TORNEIO DE %d</text>" % [width / 2, size])
	parts.append("<text x=\"%d\" y=\"76\" text-anchor=\"middle\" fill=\"#8ecff0\" font-family=\"sans-serif\" font-size=\"14\">Tehkné Solutions</text>" % [width / 2])
	for round_index in range(column_count):
		var title := _round_title(size, round_index)
		var x := 60.0 + round_index * column_width
		parts.append("<text x=\"%.1f\" y=\"116\" fill=\"#f4d477\" font-family=\"sans-serif\" font-size=\"18\" font-weight=\"700\">%s</text>" % [x, _escape(title)])
		if round_index >= rounds.size() or not (rounds[round_index] is Array):
			continue
		var matches: Array = rounds[round_index]
		var vertical_space := float(height - 180) / float(maxi(1, matches.size()))
		for match_index in range(matches.size()):
			if not (matches[match_index] is Dictionary):
				continue
			var match_data: Dictionary = matches[match_index]
			var y := 140.0 + match_index * vertical_space + vertical_space * 0.5
			parts.append_array(_match_svg(match_data, x, y, column_width - 70.0))
	var champion_source: Variant = snapshot.get("champion", {})
	if champion_source is Dictionary and not (champion_source as Dictionary).is_empty():
		var champion: Dictionary = champion_source
		parts.append("<rect x=\"%d\" y=\"%d\" width=\"420\" height=\"58\" rx=\"12\" fill=\"#2d2410\" stroke=\"#ffd36b\" stroke-width=\"2\"/>" % [width / 2 - 210, height - 82])
		parts.append("<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" fill=\"#ffd36b\" font-family=\"sans-serif\" font-size=\"21\" font-weight=\"700\">CAMPEÃO • #%d %s</text>" % [width / 2, height - 45, int(champion.get("seed", 0)), _escape(String(champion.get("name", "CAMPEÃO")))])
	parts.append("</svg>")
	return "\n".join(parts)

static func _match_svg(match_data: Dictionary, x: float, y: float, width: float) -> Array[String]:
	var result: Array[String] = []
	var p1 := _participant_label(match_data.get("p1", {}))
	var p2 := _participant_label(match_data.get("p2", {}))
	var winner := _participant_label(match_data.get("winner", {}))
	result.append("<rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"70\" rx=\"10\" fill=\"#111a2a\" stroke=\"#36506f\" stroke-width=\"1.5\"/>" % [x, y - 35.0, width])
	result.append("<text x=\"%.1f\" y=\"%.1f\" fill=\"#d7deeb\" font-family=\"sans-serif\" font-size=\"14\">%s</text>" % [x + 14.0, y - 9.0, _escape(p1)])
	result.append("<text x=\"%.1f\" y=\"%.1f\" fill=\"#d7deeb\" font-family=\"sans-serif\" font-size=\"14\">%s</text>" % [x + 14.0, y + 18.0, _escape(p2)])
	if winner != "A DEFINIR":
		result.append("<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"end\" fill=\"#70e0a0\" font-family=\"sans-serif\" font-size=\"12\">VENCEDOR • %s</text>" % [x + width - 12.0, y + 3.0, _escape(winner)])
	return result

static func _participant_label(source: Variant) -> String:
	if not (source is Dictionary) or (source as Dictionary).is_empty():
		return "A DEFINIR"
	var participant: Dictionary = source
	var seed := int(participant.get("seed", 0))
	return "#%d %s" % [seed, String(participant.get("name", "A DEFINIR"))] if seed > 0 else String(participant.get("name", "A DEFINIR"))

static func _round_title(size: int, round_index: int) -> String:
	if size == 8:
		return ["QUARTAS DE FINAL", "SEMIFINAIS", "FINAL"][clampi(round_index, 0, 2)]
	return ["SEMIFINAIS", "FINAL"][clampi(round_index, 0, 1)]

static func _escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
