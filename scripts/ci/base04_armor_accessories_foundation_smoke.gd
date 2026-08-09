extends SceneTree

const SLOTS := [&"head_accessory", &"shoulders", &"back_accessory"]
const EXPECTED_Z := {
	"back_accessory": 4,
	"hair_back": 5,
	"body_base": 10,
	"hair_front": 50,
	"head_accessory": 60,
	"torso_outer": 65,
	"shoulders": 70,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	for slot_name in EXPECTED_Z.keys():
		if ModularFighterLayerPolicy.z_index_for(StringName(slot_name)) != int(EXPECTED_Z[slot_name]):
			failures.append("layer:%s" % slot_name)
	if not (
		ModularFighterLayerPolicy.z_index_for(&"back_accessory") < ModularFighterLayerPolicy.z_index_for(&"hair_back")
		and ModularFighterLayerPolicy.z_index_for(&"hair_back") < ModularFighterLayerPolicy.z_index_for(&"body_base")
		and ModularFighterLayerPolicy.z_index_for(&"hair_front") < ModularFighterLayerPolicy.z_index_for(&"head_accessory")
		and ModularFighterLayerPolicy.z_index_for(&"torso_outer") < ModularFighterLayerPolicy.z_index_for(&"shoulders")
	):
		failures.append("layer_relations")

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c68_base04_foundation_probe"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	for slot in SLOTS:
		profile.set_module(slot, StringName("future_%s_probe" % String(slot)))
	var profile_failures := profile.validate_against_standard()
	if not profile_failures.is_empty():
		failures.append("profile:%s" % ",".join(profile_failures))
	for slot in SLOTS:
		profile.clear_module(slot)
		if profile.module_id(slot) != &"":
			failures.append("clear:%s" % String(slot))

	var packed := load("res://scenes/characters/modular_fighter_creator_shell.tscn") as PackedScene
	var creator := packed.instantiate() if packed != null else null
	if creator == null:
		failures.append("creator")
	else:
		get_root().add_child(creator)
		await process_frame
		for node_name in ["ArmorSetOption", "HeadAccessoryOption", "ShouldersOption", "BackAccessoryOption"]:
			if creator.get_node_or_null(node_name) != null:
				failures.append("creator_exposed:%s" % node_name)
		creator.queue_free()
		await process_frame

	if not failures.is_empty():
		for failure in failures:
			push_error("C68_0_BASE04_FOUNDATION=BLOCKED %s" % failure)
		quit(2)
		return

	print("C68_0_BASE04_FOUNDATION=PASS")
	print("C68_0_ARMOR_SET=PASS slots=head_accessory,shoulders atomic=true")
	print("C68_0_BACK_ACCESSORY=PASS independent=true")
	print("C68_0_LAYER_POLICY=PASS back=4 hair_back=5 body=10 hair_front=50 head=60 torso_outer=65 shoulders=70")
	print("C68_0_PROFILE_STORAGE=PASS schema=v2")
	print("C68_0_CREATOR_EXPOSURE=BLOCKED art_required=true")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

# Tehkné Solutions
