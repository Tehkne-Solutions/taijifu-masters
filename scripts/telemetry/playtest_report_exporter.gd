class_name PlaytestReportExporter
extends RefCounted

const DEFAULT_FILE_NAME := "taijifu-playtest-report.json"

static func sanitize_file_name(raw_file_name: String) -> String:
	var candidate := raw_file_name.strip_edges().get_file()
	var sanitized := ""
	for character in candidate:
		var code := character.unicode_at(0)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or character in ["-", "_", "."]
		)
		sanitized += character if allowed else "_"
	if sanitized == "" or sanitized == "." or sanitized == "..":
		sanitized = DEFAULT_FILE_NAME
	if not sanitized.to_lower().ends_with(".json"):
		sanitized += ".json"
	return sanitized

static func build_web_download_script(report_json: String, raw_file_name: String) -> String:
	var encoded := Marshalls.utf8_to_base64(report_json)
	var file_name := sanitize_file_name(raw_file_name)
	return """(function () {
	const binary = atob('%s');
	const bytes = new Uint8Array(binary.length);
	for (let index = 0; index < binary.length; index += 1) {
		bytes[index] = binary.charCodeAt(index);
	}
	const blob = new Blob([bytes], { type: 'application/json;charset=utf-8' });
	const url = URL.createObjectURL(blob);
	const link = document.createElement('a');
	link.href = url;
	link.download = '%s';
	link.rel = 'noopener';
	document.body.appendChild(link);
	link.click();
	link.remove();
	setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
	return true;
})();""" % [encoded, file_name]

static func export_report(
	report_json: String,
	raw_file_name: String,
	source_path: String = ""
) -> Dictionary:
	if report_json.strip_edges() == "":
		return {"ok": false, "mode": "none", "message": "Relatório vazio."}
	var file_name := sanitize_file_name(raw_file_name)
	if OS.has_feature("web"):
		var result := JavaScriptBridge.eval(
			build_web_download_script(report_json, file_name),
			true
		)
		return {
			"ok": result != null and bool(result),
			"mode": "browser_download",
			"file_name": file_name
		}
	if source_path != "" and FileAccess.file_exists(source_path):
		var absolute_path := ProjectSettings.globalize_path(source_path)
		OS.shell_show_in_file_manager(absolute_path, true)
		return {
			"ok": true,
			"mode": "native_reveal",
			"file_name": file_name,
			"path": source_path
		}
	return {
		"ok": false,
		"mode": "native_missing",
		"file_name": file_name,
		"message": "Arquivo local não encontrado."
	}

static func contract_signature() -> Dictionary:
	return {
		"web_blob_download": true,
		"web_payload_encoding": "base64",
		"native_file_reveal": true,
		"automatic_upload": false,
		"file_extension": ".json"
	}
