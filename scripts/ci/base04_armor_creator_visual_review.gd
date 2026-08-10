extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const UNIFORM_LIAN := &"uniform_01_lian_martial"
const ARMOR_GUARD := &"armor_01_taijifu_guard"
const OUTPUT := "res://artifacts/c68_2/C68_2_ARMOR_CREATOR_CONTROL.review-1280x720.png"

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
		_fail("C68_2_VISUAL=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(10): await process_frame

	var back_creator := ModularFighterArmorRuntime.back_accessory_creator_exposure_enabled()
	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(UNIFORM_LIAN))
	if back_creator:
		failures.append_array(creator.set_back_accessory(&"back_none"))
	failures.append_array(creator.set_armor_set(ARMOR_GUARD))
	if not failures.is_empty():
		_fail("C68_2_VISUAL=BLOCKED composition:%s" % ",".join(failures))
		return
	for _frame in range(8): await process_frame

	var armor_option := creator.armor_set_option()
	var uniform_option := creator.uniform_set_option()
	var hair_option := creator.hair_style_option()
	var back_option := creator.back_accessory_option() if back_creator else null
	if armor_option == null or uniform_option == null or hair_option == null or (back_creator and back_option == null):
		_fail("C68_2_VISUAL=BLOCKED controls")
		return
	for forbidden_name in ["HeadAccessoryOption", "ShouldersOption", "WeaponBackOption", "WeaponMainOption", "WeaponOffhandOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("C68_2_VISUAL=BLOCKED raw_control:%s" % forbidden_name)
			return

	var controls: Array[Control] = [armor_option, uniform_option, hair_option]
	if back_option != null:
		controls.append(back_option)
	var rects: Array[Rect2] = []
	for control in controls:
		var rect := Rect2(control.position, control.size)
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1280.0 or rect.end.y > 720.0:
			_fail("C68_2_VISUAL=BLOCKED control_bounds:%s" % control.name)
			return
		rects.append(rect)
	for left in range(rects.size()):
		for right in range(left + 1, rects.size()):
			if rects[left].intersects(rects[right]):
				_fail("C68_2_VISUAL=BLOCKED actual_control_overlap")
				return
	if bool(creator.reviewed_layout_signature().get("controls_overlap", true)):
		_fail("C68_2_VISUAL=BLOCKED layout_signature_overlap")
		return

	var preview := creator.current_assembler()
	var head := preview.get_node_or_null("Module_head_accessory") as Sprite2D
	var shoulders := preview.get_node_or_null("Module_shoulders") as Sprite2D
	if head == null or shoulders == null or head.z_index != 60 or shoulders.z_index != 70:
		_fail("C68_2_VISUAL=BLOCKED armor_preview")
		return
	if preview.get_node_or_null("Module_back_accessory") != null:
		_fail("C68_2_VISUAL=BLOCKED isolated_back_preview")
		return
	if preview.get_node_or_null("Module_hair_front") == null or preview.get_node_or_null("Module_torso_outer") == null:
		_fail("C68_2_VISUAL=BLOCKED cross_pack_preview")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C68_2_VISUAL=BLOCKED capture")
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C68_2_VISUAL=BLOCKED save")
		return

	print("C68_2_CREATOR_VISUAL=PASS armor=armor_01_taijifu_guard hair=hair_01_lian_topknot uniform=uniform_01_lian_martial")
	print("C68_2_CREATOR_LAYOUT=PASS armor_atomic=true raw_armor_controls=false back_control=%s overlap=false expansion_aware=true" % str(back_creator).to_lower())
	print("C68_2_CREATOR_PREVIEW=PASS head_z=60 shoulders_z=70 back=back_none")
	print("C68_2_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	creator.queue_free()
	await process_frame
	quit(0)

# Tehkné Solutions
