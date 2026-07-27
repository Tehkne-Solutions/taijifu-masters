class_name LoadoutShareCode
extends RefCounted

const PREFIX := "TJF1"
const SIGNATURE := "TAIJIFU_LOADOUT_SHARE"
const MAX_CODE_LENGTH := 12000

static func encode_preset(preset: Dictionary) -> String:
	if preset.is_empty():
		return ""
	var payload := {
		"signature": SIGNATURE,
		"version": 1,
		"name": String(preset.get("name", "PRESET")),
		"loadout": preset.get("loadout", {}),
		"match_config": preset.get("match_config", {})
	}
	var raw := JSON.stringify(payload).to_utf8_buffer()
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var encoded := Marshalls.raw_to_base64(compressed)
	encoded = encoded.replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	var checksum := _checksum(raw)
	return "%s.%s.%s.%s" % [PREFIX, _to_base36(raw.size()), encoded, checksum]

static func decode_code(code: String, unlocked_variants: Array = []) -> Dictionary:
	var clean := code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if clean.length() <= 0 or clean.length() > MAX_CODE_LENGTH:
		return {"ok": false, "error": "Código vazio ou excessivamente longo"}
	var parts := clean.split(".")
	if parts.size() != 4 or parts[0] != PREFIX:
		return {"ok": false, "error": "Prefixo ou formato inválido"}
	var original_size := _from_base36(parts[1])
	if original_size <= 0 or original_size > 200000:
		return {"ok": false, "error": "Tamanho declarado inválido"}
	var encoded := parts[2].replace("-", "+").replace("_", "/")
	while encoded.length() % 4 != 0:
		encoded += "="
	var compressed := Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		return {"ok": false, "error": "Conteúdo Base64 inválido"}
	var raw := compressed.decompress(original_size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != original_size:
		return {"ok": false, "error": "Falha ao descompactar o código"}
	if _checksum(raw) != parts[3].to_lower():
		return {"ok": false, "error": "Checksum inválido"}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "JSON interno inválido"}
	var root: Dictionary = parsed
	if String(root.get("signature", "")) != SIGNATURE:
		return {"ok": false, "error": "Assinatura inválida"}
	var loadout_source: Variant = root.get("loadout", {})
	var config_source: Variant = root.get("match_config", {})
	if not (loadout_source is Dictionary):
		return {"ok": false, "error": "Loadout ausente"}
	var clean_loadout := BattleLoadoutCatalog.sanitize(loadout_source as Dictionary, unlocked_variants)
	var clean_config := CompetitiveMatchCatalog.sanitize(config_source as Dictionary if config_source is Dictionary else {})
	return {
		"ok": true,
		"preset": {
			"name": _clean_name(String(root.get("name", "PRESET COMPARTILHADO"))),
			"loadout": clean_loadout,
			"match_config": clean_config
		}
	}

static func validate_round_trip(preset: Dictionary, unlocked_variants: Array = []) -> bool:
	var code := encode_preset(preset)
	if code == "":
		return false
	var decoded := decode_code(code, unlocked_variants)
	return bool(decoded.get("ok", false))

static func _checksum(raw: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	return context.finish().hex_encode().left(8).to_lower()

static func _to_base36(value: int) -> String:
	const DIGITS := "0123456789abcdefghijklmnopqrstuvwxyz"
	var number := maxi(0, value)
	if number == 0:
		return "0"
	var result := ""
	while number > 0:
		result = DIGITS[number % 36] + result
		number /= 36
	return result

static func _from_base36(value: String) -> int:
	const DIGITS := "0123456789abcdefghijklmnopqrstuvwxyz"
	var result := 0
	for character in value.to_lower():
		var digit := DIGITS.find(character)
		if digit < 0:
			return -1
		result = result * 36 + digit
	return result

static func _clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	return (clean if clean != "" else "PRESET COMPARTILHADO").left(48)
