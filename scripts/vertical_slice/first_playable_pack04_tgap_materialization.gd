class_name FirstPlayablePack04TgapMaterialization
extends RefCounted

## Read-only materialization probe for PACK 04.
## TGAP remains the only owner of install/staging/promotion/catalog/rollback.
## This class validates product-specific completeness after TGAP promotion.
## The canonical checksum authority is the assets release `checksums.sha256`.
## Tehkné Solutions

const CONTRACT_ID := "first_playable_pack04_tgap_materialization_v1"
const DOMAIN_PACK_ID := "PACK_04_COMBAT_REACTIONS_AND_MOTION"
const TGAP_PACK_ID := "pack_04_combat_reactions_and_motion"
const EXPECTED_VERSION := "1.0.0"
const EXPECTED_RELEASE_TAG := "assets-pack-04-v1.0.0"
const EXPECTED_ASSET_COUNT := 34
const EXPECTED_TOTAL_FILE_COUNT := 38
const EXPECTED_CHECKSUM_ENTRY_COUNT := 37

const MANIFEST_PATH := "manifest.json"
const RUNTIME_MAP_PATH := "runtime-map.json"
const APPROVAL_PATH := "approval.json"
const CHECKSUMS_PATH := "checksums.sha256"

const MANIFEST_SCHEMA := "tehkne/taijifu-pack04-materialization/v1"
const RUNTIME_MAP_SCHEMA := "tehkne/taijifu-pack04-runtime-map/v1"
const APPROVAL_SCHEMA := "tehkne/taijifu-pack04-approval/v1"

const REQUIRED_FIGHTERS := ["lian_wu", "training_rival"]
const REQUIRED_STATES := ["block_recoil", "parry", "posture_break", "knockback", "neutral_recovery"]
const CONTRACT_FILES := [MANIFEST_PATH, CHECKSUMS_PATH, RUNTIME_MAP_PATH, APPROVAL_PATH]
const CHECKSUMMED_SUPPORT_FILES := [MANIFEST_PATH, RUNTIME_MAP_PATH, APPROVAL_PATH]

var _cached_loader_id := 0
var _cached_generation := -999999
var _cached_result: Dictionary = {}

func status(loader: Node = null, force: bool = false) -> Dictionary:
	var active_loader := loader if is_instance_valid(loader) else _production_loader()
	if not is_instance_valid(active_loader):
		return _blocked(["tgap_loader_missing"], -1)
	if not active_loader.has_method("generation") or not active_loader.has_method("get_pack") or not active_loader.has_method("resolve"):
		return _blocked(["tgap_loader_contract_invalid"], -1)
	var generation := int(active_loader.call("generation"))
	var loader_id := active_loader.get_instance_id()
	if not force and loader_id == _cached_loader_id and generation == _cached_generation and not _cached_result.is_empty():
		return _cached_result.duplicate(true)
	var result := _probe(active_loader, generation)
	_cached_loader_id = loader_id
	_cached_generation = generation
	_cached_result = result.duplicate(true)
	return result

func invalidate_cache() -> void:
	_cached_loader_id = 0
	_cached_generation = -999999
	_cached_result = {}

func _probe(loader: Node, generation: int) -> Dictionary:
	if generation < 1:
		return _blocked(["tgap_catalog_unavailable"], generation)
	var pack_variant: Variant = loader.call("get_pack", TGAP_PACK_ID)
	if not (pack_variant is Dictionary):
		return _blocked(["tgap_pack_missing"], generation)
	var pack := pack_variant as Dictionary
	if pack.is_empty():
		return _blocked(["tgap_pack_missing"], generation)
	if String(pack.get("version", "")) != EXPECTED_VERSION:
		return _blocked(["tgap_pack_version_mismatch"], generation, pack)
	if int(pack.get("file_count", -1)) < EXPECTED_TOTAL_FILE_COUNT:
		return _blocked(["tgap_pack_file_count_incomplete"], generation, pack)

	var contract_paths := {}
	for relative_path in CONTRACT_FILES:
		var resolved := String(loader.call("resolve", TGAP_PACK_ID, relative_path, EXPECTED_VERSION))
		if resolved.is_empty():
			return _blocked(["contract_file_missing:%s" % relative_path], generation, pack)
		contract_paths[relative_path] = resolved

	var manifest_result := _read_json(String(contract_paths[MANIFEST_PATH]), MANIFEST_SCHEMA, "manifest")
	if not bool(manifest_result.get("ok", false)):
		return _blocked([String(manifest_result.get("blocker", "manifest_invalid"))], generation, pack)
	var manifest := manifest_result.get("data", {}) as Dictionary
	if not _identity_matches(manifest):
		return _blocked(["manifest_identity_mismatch"], generation, pack)
	var assets_variant: Variant = manifest.get("assets", [])
	if not (assets_variant is Array):
		return _blocked(["manifest_assets_invalid"], generation, pack)
	var assets := assets_variant as Array
	if assets.size() != EXPECTED_ASSET_COUNT or int(manifest.get("asset_count", 0)) != EXPECTED_ASSET_COUNT:
		return _blocked(["manifest_asset_count:%d_of_%d" % [assets.size(), EXPECTED_ASSET_COUNT]], generation, pack)

	var checksums_result := _read_sha256sum(String(contract_paths[CHECKSUMS_PATH]))
	if not bool(checksums_result.get("ok", false)):
		return _blocked([String(checksums_result.get("blocker", "checksums_invalid"))], generation, pack)
	var checksum_files := checksums_result.get("files", {}) as Dictionary
	if checksum_files.size() < EXPECTED_CHECKSUM_ENTRY_COUNT:
		return _blocked(["checksums_entry_count:%d_lt_%d" % [checksum_files.size(), EXPECTED_CHECKSUM_ENTRY_COUNT]], generation, pack)
	for support_path in CHECKSUMMED_SUPPORT_FILES:
		if not checksum_files.has(support_path):
			return _blocked(["checksum_support_missing:%s" % support_path], generation, pack)
		var support_actual := FileAccess.get_sha256(String(contract_paths[support_path])).to_lower()
		if support_actual != String(checksum_files[support_path]).to_lower():
			return _blocked(["checksum_support_mismatch:%s" % support_path], generation, pack)

	var inventory := {}
	var coverage := {}
	for fighter in REQUIRED_FIGHTERS:
		coverage[fighter] = {}
		for state in REQUIRED_STATES:
			coverage[fighter][state] = 0
	for asset_variant in assets:
		if not (asset_variant is Dictionary):
			return _blocked(["manifest_asset_entry_invalid"], generation, pack)
		var asset := asset_variant as Dictionary
		var relative_path := String(asset.get("path", ""))
		var fighter := String(asset.get("fighter", ""))
		var state := String(asset.get("state", ""))
		var expected_sha := String(asset.get("sha256", "")).to_lower()
		if not _safe_png_path(relative_path):
			return _blocked(["asset_path_invalid:%s" % relative_path], generation, pack)
		if inventory.has(relative_path):
			return _blocked(["asset_path_duplicate:%s" % relative_path], generation, pack)
		if not REQUIRED_FIGHTERS.has(fighter):
			return _blocked(["asset_fighter_invalid:%s" % fighter], generation, pack)
		if not REQUIRED_STATES.has(state):
			return _blocked(["asset_state_invalid:%s" % state], generation, pack)
		if not _valid_sha256(expected_sha):
			return _blocked(["asset_sha_invalid:%s" % relative_path], generation, pack)
		if String(checksum_files.get(relative_path, "")).to_lower() != expected_sha:
			return _blocked(["checksum_manifest_mismatch:%s" % relative_path], generation, pack)
		var resolved_asset := String(loader.call("resolve", TGAP_PACK_ID, relative_path, EXPECTED_VERSION))
		if resolved_asset.is_empty():
			return _blocked(["asset_missing:%s" % relative_path], generation, pack)
		var actual_sha := FileAccess.get_sha256(resolved_asset).to_lower()
		if actual_sha != expected_sha:
			return _blocked(["asset_checksum_mismatch:%s" % relative_path], generation, pack)
		var image := Image.load_from_file(resolved_asset)
		if image == null or image.is_empty():
			return _blocked(["asset_png_invalid:%s" % relative_path], generation, pack)
		inventory[relative_path] = {"fighter": fighter, "state": state, "sha256": expected_sha}
		coverage[fighter][state] = int(coverage[fighter][state]) + 1
	for fighter in REQUIRED_FIGHTERS:
		for state in REQUIRED_STATES:
			if int(coverage[fighter][state]) <= 0:
				return _blocked(["state_coverage_missing:%s:%s" % [fighter, state]], generation, pack)

	var runtime_map_result := _read_json(String(contract_paths[RUNTIME_MAP_PATH]), RUNTIME_MAP_SCHEMA, "runtime_map")
	if not bool(runtime_map_result.get("ok", false)):
		return _blocked([String(runtime_map_result.get("blocker", "runtime_map_invalid"))], generation, pack)
	var runtime_map := runtime_map_result.get("data", {}) as Dictionary
	if not _identity_matches(runtime_map):
		return _blocked(["runtime_map_identity_mismatch"], generation, pack)
	var mappings_variant: Variant = runtime_map.get("mappings", {})
	if not (mappings_variant is Dictionary):
		return _blocked(["runtime_map_mappings_invalid"], generation, pack)
	var mappings := mappings_variant as Dictionary
	for fighter in REQUIRED_FIGHTERS:
		var fighter_map_variant: Variant = mappings.get(fighter, {})
		if not (fighter_map_variant is Dictionary):
			return _blocked(["runtime_map_fighter_missing:%s" % fighter], generation, pack)
		var fighter_map := fighter_map_variant as Dictionary
		for state in REQUIRED_STATES:
			var paths_variant: Variant = fighter_map.get(state, [])
			if not (paths_variant is Array) or (paths_variant as Array).is_empty():
				return _blocked(["runtime_map_state_missing:%s:%s" % [fighter, state]], generation, pack)
			for mapped_path_variant in paths_variant as Array:
				var mapped_path := String(mapped_path_variant)
				if not inventory.has(mapped_path):
					return _blocked(["runtime_map_asset_unknown:%s" % mapped_path], generation, pack)
				var entry := inventory[mapped_path] as Dictionary
				if String(entry.get("fighter", "")) != fighter or String(entry.get("state", "")) != state:
					return _blocked(["runtime_map_asset_mismatch:%s" % mapped_path], generation, pack)

	var approval_result := _read_json(String(contract_paths[APPROVAL_PATH]), APPROVAL_SCHEMA, "approval")
	if not bool(approval_result.get("ok", false)):
		return _blocked([String(approval_result.get("blocker", "approval_invalid"))], generation, pack)
	var approval := approval_result.get("data", {}) as Dictionary
	if not _identity_matches(approval):
		return _blocked(["approval_identity_mismatch"], generation, pack)
	if not bool(approval.get("approved", false)) or String(approval.get("human_review", "")) != "PASS":
		return _blocked(["human_review_not_approved"], generation, pack)
	if String(approval.get("reviewer", "")).strip_edges().is_empty():
		return _blocked(["human_reviewer_missing"], generation, pack)
	var evidence_variant: Variant = approval.get("evidence", [])
	if not (evidence_variant is Array) or (evidence_variant as Array).is_empty():
		return _blocked(["human_review_evidence_missing"], generation, pack)
	for legacy_field in ["status", "human_visual_review", "identity_continuity", "weapon_continuity"]:
		if String(approval.get(legacy_field, "")) != "pass":
			return _blocked(["approval_legacy_field:%s" % legacy_field], generation, pack)
	if String(approval.get("signature", "")) != "Tehkné Solutions":
		return _blocked(["approval_signature_invalid"], generation, pack)

	return {
		"contract": CONTRACT_ID,
		"available": true,
		"materialized": true,
		"runtime_active": false,
		"status": "materialized_pending_runtime_activation",
		"blockers": [],
		"pack_id": DOMAIN_PACK_ID,
		"tgap_pack_id": TGAP_PACK_ID,
		"version": EXPECTED_VERSION,
		"release_tag": EXPECTED_RELEASE_TAG,
		"generation": generation,
		"asset_count": assets.size(),
		"expected_asset_count": EXPECTED_ASSET_COUNT,
		"checksum_authority": CHECKSUMS_PATH,
		"coverage": coverage,
		"human_review": "PASS",
		"signature": "Tehkné Solutions",
	}

func _identity_matches(data: Dictionary) -> bool:
	return (
		String(data.get("pack_id", "")) == DOMAIN_PACK_ID
		and String(data.get("tgap_pack_id", "")) == TGAP_PACK_ID
		and String(data.get("version", "")) == EXPECTED_VERSION
		and String(data.get("release_tag", "")) == EXPECTED_RELEASE_TAG
		and String(data.get("signature", "")) == "Tehkné Solutions"
	)

func _read_json(path: String, expected_schema: String, label: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "blocker": "%s_unreadable" % label}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "blocker": "%s_invalid_json" % label}
	var data := parsed as Dictionary
	if String(data.get("schema", "")) != expected_schema:
		return {"ok": false, "blocker": "%s_schema_mismatch" % label}
	return {"ok": true, "data": data}

func _read_sha256sum(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "blocker": "checksums_unreadable"}
	var entries := {}
	for raw_line in file.get_as_text().split("\n"):
		var line := String(raw_line).strip_edges()
		if line.is_empty():
			continue
		var separator := line.find(" ")
		if separator <= 0:
			return {"ok": false, "blocker": "checksums_format"}
		var digest := line.substr(0, separator).to_lower()
		var relative_path := line.substr(separator).strip_edges().replace("\\", "/")
		if relative_path.begins_with("*"):
			relative_path = relative_path.substr(1)
		if not _valid_sha256(digest) or not _safe_relative_path(relative_path):
			return {"ok": false, "blocker": "checksums_entry_invalid:%s" % relative_path}
		if entries.has(relative_path):
			return {"ok": false, "blocker": "checksums_entry_duplicate:%s" % relative_path}
		entries[relative_path] = digest
	return {"ok": true, "files": entries}

func _safe_relative_path(value: String) -> bool:
	if value.is_empty() or value.is_absolute_path():
		return false
	var normalized := value.replace("\\", "/")
	for segment in normalized.split("/"):
		if segment.is_empty() or segment == "..":
			return false
	return true

func _safe_png_path(value: String) -> bool:
	return _safe_relative_path(value) and value.to_lower().ends_with(".png")

func _valid_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not String(character).to_lower() in "0123456789abcdef":
			return false
	return true

func _production_loader() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("TgapAssetLoader")

func _blocked(blockers: Array, generation: int, pack: Dictionary = {}) -> Dictionary:
	return {
		"contract": CONTRACT_ID,
		"available": false,
		"materialized": false,
		"runtime_active": false,
		"status": "blocked",
		"blockers": blockers.duplicate(),
		"pack_id": DOMAIN_PACK_ID,
		"tgap_pack_id": TGAP_PACK_ID,
		"version": String(pack.get("version", "")),
		"expected_version": EXPECTED_VERSION,
		"release_tag": EXPECTED_RELEASE_TAG,
		"generation": generation,
		"asset_count": 0,
		"expected_asset_count": EXPECTED_ASSET_COUNT,
		"checksum_authority": CHECKSUMS_PATH,
		"human_review": "BLOCKED",
		"signature": "Tehkné Solutions",
	}

# Tehkné Solutions
