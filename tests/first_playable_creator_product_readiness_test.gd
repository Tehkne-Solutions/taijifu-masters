extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const HANDOFF_CONTRACT := "res://assets/modular_fighters/base_01/production/BASE01_CREATOR_BATTLE_HANDOFF.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CREATOR_SCENE):
		_fail("P0_CREATOR_READINESS=BLOCKED creator_scene_missing")
		return
	if not FileAccess.file_exists(HANDOFF_CONTRACT):
		_fail("P0_CREATOR_READINESS=BLOCKED handoff_contract_missing")
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate()
	if creator == null:
		_fail("P0_CREATOR_READINESS=BLOCKED creator_instantiate")
		return
	root.add_child(creator)
	for _frame in range(5):
		await process_frame

	if not creator.has_method("creator_product_readiness_signature"):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED readiness_signature_missing")
		return
	var readiness = creator.call("creator_product_readiness_signature")
	if not (readiness is Dictionary):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED readiness_signature_invalid")
		return
	var signature := readiness as Dictionary
	for key in ["identity_options", "hair_options", "uniform_options", "armor_options", "back_accessory_options", "weapon_options"]:
		if int(signature.get(key, 0)) <= 0:
			creator.queue_free()
			_fail("P0_CREATOR_READINESS=BLOCKED no_production_options:%s" % key)
			return
	if not bool(signature.get("options_are_production_backed", false)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED production_backing_not_asserted")
		return
	if bool(signature.get("authored_motion_final", true)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED transform_motion_falsely_final")
		return
	if String(signature.get("motion_quality", "")) != "placeholder_transform_runtime":
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED motion_debt_not_explicit")
		return
	if not bool(signature.get("pack04_required_for_final_motion", false)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED pack04_not_required")
		return
	if String(signature.get("battle_visual_activation", "")) != "on_complete_assembly":
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED battle_activation_policy")
		return

	var readiness_label := creator.get_node_or_null("ProductReadiness") as Label
	if readiness_label == null or not readiness_label.text.contains("MOVIMENTO MODULAR: PROVISÓRIO"):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED user_visible_motion_status_missing")
		return

	var file := FileAccess.open(HANDOFF_CONTRACT, FileAccess.READ)
	if file == null:
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED handoff_contract_open")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED handoff_contract_parse")
		return
	var contract := parsed as Dictionary
	if String(contract.get("schema", "")) != "tehkne/taijifu-base01-creator-battle-handoff/v2":
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED handoff_schema")
		return
	var battle = contract.get("battle_contract", {})
	if not (battle is Dictionary):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED battle_contract_invalid")
		return
	var battle_contract := battle as Dictionary
	if bool(battle_contract.get("prebattle_visual_activation", true)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED prebattle_must_fail_closed")
		return
	if not bool(battle_contract.get("battle_visual_activation_on_complete_assembly", false)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED battle_success_activation_missing")
		return
	if not bool(battle_contract.get("fallback_allowed_only_on_assembly_failure", false)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED fallback_policy")
		return
	var release = contract.get("release_policy", {})
	if not (release is Dictionary) or bool((release as Dictionary).get("product_ready", true)):
		creator.queue_free()
		_fail("P0_CREATOR_READINESS=BLOCKED product_falsely_ready")
		return

	print("P0_CREATOR_PRODUCTION_OPTIONS=PASS identity=%d hair=%d uniform=%d armor=%d back=%d weapon=%d" % [
		int(signature["identity_options"]),
		int(signature["hair_options"]),
		int(signature["uniform_options"]),
		int(signature["armor_options"]),
		int(signature["back_accessory_options"]),
		int(signature["weapon_options"]),
	])
	print("P0_CREATOR_HANDOFF_TRUTH=PASS prebattle=false battle_on_complete_assembly=true")
	print("P0_CREATOR_MOTION_DEBT=PASS quality=placeholder_transform_runtime pack04_required=true")
	print("P0_CREATOR_READINESS=PASS")
	print("SIGNATURE=Tehkné Solutions")
	creator.queue_free()
	await process_frame
	quit(0)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	quit(2)

# Tehkné Solutions
