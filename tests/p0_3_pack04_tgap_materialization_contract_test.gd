extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/runtime/tgap_asset_loader.gd")
const TEST_ROOT := "user://p0_3_pack04_tgap_materialization_fixture"
const PACK_ROOT := TEST_ROOT + "/tgap-current/packs/pack_04_combat_reactions_and_motion"
const FIGHTERS := ["lian_wu", "training_rival"]
const STATES := ["block_recoil", "parry", "posture_break", "knockback", "neutral_recovery"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var production_probe := FirstPlayablePack04TgapMaterialization.new()
	var production := production_probe.status(null, true)
	if bool(production.get("available", true)):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED production_false_positive")
		return
	print("PACK04_MATERIALIZATION_DEFAULT=PASS available=false blockers=%s" % ",".join(_string_array(production.get("blockers", []))))

	var fixture := _build_fixture()
	if fixture.is_empty():
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED fixture_build")
		return

	var loader: Node = LOADER_SCRIPT.new()
	loader.runtime_root = TEST_ROOT
	loader.allow_fallbacks = false
	loader.hot_reload_enabled = false
	root.add_child(loader)
	await process_frame
	if not bool(loader.call("reload_catalog")):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED fixture_catalog", loader)
		return

	var probe := FirstPlayablePack04TgapMaterialization.new()
	var complete := probe.status(loader, true)
	if not bool(complete.get("available", false)):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED fixture_complete:%s" % ",".join(_string_array(complete.get("blockers", []))), loader)
		return
	if int(complete.get("asset_count", 0)) != 34 or bool(complete.get("runtime_active", true)):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED fixture_completion_contract", loader)
		return
	print("PACK04_MATERIALIZATION_COMPLETE_FIXTURE=PASS assets=34 synthetic=true runtime_active=false")

	var approval := fixture.get("approval", {}) as Dictionary
	approval["approved"] = false
	approval["human_review"] = "PENDING"
	_write_json(PACK_ROOT + "/approval.json", approval)
	var rejected_approval := probe.status(loader, true)
	if bool(rejected_approval.get("available", true)) or not _has_blocker(rejected_approval, "human_review_not_approved"):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED approval_fail_open", loader)
		return
	print("PACK04_MATERIALIZATION_APPROVAL_GATE=PASS rejected=PENDING")

	approval["approved"] = true
	approval["human_review"] = "PASS"
	_write_json(PACK_ROOT + "/approval.json", approval)
	var first_asset := String(fixture.get("first_asset", ""))
	var asset_file := FileAccess.open(PACK_ROOT + "/" + first_asset, FileAccess.READ_WRITE)
	if asset_file == null:
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED checksum_fixture_open", loader)
		return
	asset_file.seek_end()
	asset_file.store_8(0x54)
	asset_file.close()
	var rejected_checksum := probe.status(loader, true)
	if bool(rejected_checksum.get("available", true)) or not _has_blocker_prefix(rejected_checksum, "asset_checksum_mismatch:"):
		_fail("PACK04_MATERIALIZATION_GATE=BLOCKED checksum_fail_open", loader)
		return
	print("PACK04_MATERIALIZATION_CHECKSUM_GATE=PASS tamper=rejected")

	print("PACK04_MATERIALIZATION_TGAP_AUTHORITY=PASS install=false staging=false promotion=false catalog_write=false")
	print("PACK04_TGAP_MATERIALIZATION_CONTRACT=PASS production_art_status=BLOCKED playtest_02=BLOCKED")
	print("SIGNATURE=Tehkné Solutions")
	loader.queue_free()
	await process_frame
	quit(0)

func _build_fixture() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACK_ROOT))
	var assets: Array = []
	var checksum_files := {}
	var mappings := {}
	var first_asset := ""
	var combo_index := 0
	for fighter in FIGHTERS:
		mappings[fighter] = {}
		for state in STATES:
			mappings[fighter][state] = []
			var frame_count := 4 if combo_index < 4 else 3
			combo_index += 1
			for frame_index in range(frame_count):
				var relative_path := "frames/%s/%s/%02d.png" % [fighter, state, frame_index + 1]
				var full_path := PACK_ROOT + "/" + relative_path
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full_path.get_base_dir()))
				var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
				image.fill(Color(0.12 + float(combo_index) * 0.01, 0.24, 0.36, 1.0))
				if image.save_png(full_path) != OK:
					return {}
				var sha := FileAccess.get_sha256(full_path).to_lower()
				assets.append({
					"path": relative_path,
					"fighter": fighter,
					"state": state,
					"sha256": sha,
				})
				checksum_files[relative_path] = sha
				mappings[fighter][state].append(relative_path)
				if first_asset.is_empty():
					first_asset = relative_path
	if assets.size() != 34:
		return {}

	var identity := {
		"pack_id": "PACK_04_COMBAT_REACTIONS_AND_MOTION",
		"tgap_pack_id": "pack_04_combat_reactions_and_motion",
		"version": "1.0.0",
		"release_tag": "assets-pack-04-v1.0.0",
	}
	var manifest := identity.duplicate(true)
	manifest["schema"] = "tehkne/taijifu-pack04-materialization/v1"
	manifest["assets"] = assets
	manifest["asset_count"] = 34
	manifest["signature"] = "Tehkné Solutions"
	_write_json(PACK_ROOT + "/manifest.json", manifest)

	var runtime_map := identity.duplicate(true)
	runtime_map["schema"] = "tehkne/taijifu-pack04-runtime-map/v1"
	runtime_map["mappings"] = mappings
	runtime_map["signature"] = "Tehkné Solutions"
	_write_json(PACK_ROOT + "/runtime-map.json", runtime_map)

	var approval := identity.duplicate(true)
	approval["schema"] = "tehkne/taijifu-pack04-approval/v1"
	approval["approved"] = true
	approval["human_review"] = "PASS"
	approval["reviewer"] = "synthetic-contract-fixture"
	approval["evidence"] = ["synthetic://p0.3/materialization-contract"]
	approval["synthetic_fixture"] = true
	approval["signature"] = "Tehkné Solutions"
	_write_json(PACK_ROOT + "/approval.json", approval)

	var checksums := identity.duplicate(true)
	checksums["schema"] = "tehkne/taijifu-pack04-checksums/v1"
	checksums["files"] = checksum_files
	checksums["signature"] = "Tehkné Solutions"
	_write_json(PACK_ROOT + "/checksums.json", checksums)

	var catalog := {
		"schema": "tgap/install-catalog/v1",
		"project_id": "taijifu-masters",
		"generation": 99004,
		"active_bundle": {
			"version": "fixture-1.0.0",
			"sha256": "0".repeat(64),
			"manifest": "synthetic-fixture",
		},
		"packs": [{
			"pack_id": "pack_04_combat_reactions_and_motion",
			"version": "1.0.0",
			"root": "packs/pack_04_combat_reactions_and_motion",
			"file_count": 38,
			"sha256": "1".repeat(64),
		}],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	_write_json(TEST_ROOT + "/tgap-catalog.json", catalog)
	return {"approval": approval, "first_asset": first_asset}

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

func _has_blocker(result: Dictionary, expected: String) -> bool:
	for blocker in result.get("blockers", []):
		if String(blocker) == expected:
			return true
	return false

func _has_blocker_prefix(result: Dictionary, expected_prefix: String) -> bool:
	for blocker in result.get("blockers", []):
		if String(blocker).begins_with(expected_prefix):
			return true
	return false

func _string_array(values: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if values is Array:
		for value in values as Array:
			result.append(String(value))
	return result

func _fail(marker: String, node: Node = null) -> void:
	push_error(marker)
	print(marker)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	quit(2)

# Tehkné Solutions
