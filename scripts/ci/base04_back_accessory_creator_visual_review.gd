extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const UNIFORM_LIAN := &"uniform_01_lian_martial"
const ARMOR_GUARD := &"armor_01_taijifu_guard"
const BACK_GUARDIAN := &"back_01_guardian_panel"
const WEAPON_BACK := &"sheath_lian_wu_blue"
const OUTPUT := "res://artifacts/c68_5/C68_5_BACK_ACCESSORY_CREATOR_CONTROL.review-1280x720.png"

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	quit(2)

func _run() -> void:
	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C68_5_VISUAL=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(10):
		await process_frame

	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(UNIFORM_LIAN))
	failures.append_array(creator.set_armor_set(ARMOR_GUARD))
	var profile := creator.current_profile()
	profile.set_module(&"weapon_back", WEAPON_BACK)
	failures.append_array(ModularFighterEquipmentRuntime.assemble_profile(profile, creator.current_assembler()))
	failures.append_array(creator.set_back_accessory(BACK_GUARDIAN))
	if not failures.is_empty():
		_fail("C68_5_VISUAL=BLOCKED composition:%s" % ",".join(failures))
		return
	for _frame in range(8):
		await process_frame

	var armor_option := creator.armor_set_option()
	var back_option := creator.back_accessory_option()
	var uniform_option := creator.uniform_set_option()
	var hair_option := creator.hair_style_option()
	if armor_option == null or back_option == null or uniform_option == null or hair_option == null:
		_fail("C68_5_VISUAL=BLOCKED controls")
		return
	for forbidden_name in ["HeadAccessoryOption", "ShouldersOption", "WeaponBackOption", "WeaponMainOption", "WeaponOffhandOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("C68_5_VISUAL=BLOCKED forbidden_control:%s" % forbidden_name)
			return

	var controls := [armor_option, back_option, uniform_option, hair_option]
	var rects: Array[Rect2] = []
	for control in controls:
		var rect := Rect2(control.position, control.size)
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1280.0 or rect.end.y > 720.0:
			_fail("C68_5_VISUAL=BLOCKED control_bounds:%s" % control.name)
			return
		rects.append(rect)
	for left in range(rects.size()):
		for right in range(left + 1, rects.size()):
			if rects[left].intersects(rects[right]):
				_fail("C68_5_VISUAL=BLOCKED control_overlap:%d:%d" % [left, right])
				return
	var layout := creator.reviewed_layout_signature()
	if bool(layout.get("controls_overlap", true)):
		_fail("C68_5_VISUAL=BLOCKED layout_signature_overlap")
		return

	var preview := creator.current_assembler()
	var weapon := preview.get_node_or_null("Module_weapon_back") as Sprite2D
	var back := preview.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := preview.get_node_or_null("Module_hair_back") as Sprite2D
	var head := preview.get_node_or_null("Module_head_accessory") as Sprite2D
	var shoulders := preview.get_node_or_null("Module_shoulders") as Sprite2D
	if weapon == null or weapon.z_index != 3 or back == null or back.z_index != 4 or hair_back == null or hair_back.z_index != 5:
		_fail("C68_5_VISUAL=BLOCKED z_chain")
		return
	if head == null or head.z_index != 60 or shoulders == null or shoulders.z_index != 70:
		_fail("C68_5_VISUAL=BLOCKED armor_preview")
		return
	if preview.get_node_or_null("Module_hair_front") == null or preview.get_node_or_null("Module_torso_outer") == null:
		_fail("C68_5_VISUAL=BLOCKED cross_pack_preview")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C68_5_VISUAL=BLOCKED capture")
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C68_5_VISUAL=BLOCKED save")
		return

	print("C68_5_CREATOR_VISUAL=PASS back=back_01_guardian_panel weapon_back=sheath_lian_wu_blue armor=armor_01_taijifu_guard hair=hair_01_lian_topknot uniform=uniform_01_lian_martial")
	print("C68_5_CREATOR_LAYOUT=PASS controls=armor_set,back_accessory,uniform_set,hair_style overlap=false weapon_back_control=false")
	print("C68_5_CREATOR_PREVIEW=PASS weapon_back=3 back=4 hair_back=5 head=60 shoulders=70")
	print("C68_5_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	creator.queue_free()
	await process_frame
	quit(0)

# Tehkné Solutions
