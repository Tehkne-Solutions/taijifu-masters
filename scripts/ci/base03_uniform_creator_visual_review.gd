extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const SET_LIAN := &"uniform_01_lian_martial"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const OUTPUT := "res://artifacts/c67_2/C67_2_UNIFORM_CREATOR_CONTROL.review-1280x720.png"

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
		_fail("C67_2_VISUAL=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(8):
		await process_frame

	creator.set_display_name("LIAN • TRAJE MARCIAL")
	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(SET_LIAN))
	if not failures.is_empty():
		_fail("C67_2_VISUAL=BLOCKED selection:%s" % ",".join(failures))
		return
	for _frame in range(6):
		await process_frame

	var uniform_option := creator.uniform_set_option()
	var hair_option := creator.hair_style_option()
	if uniform_option == null or hair_option == null:
		_fail("C67_2_VISUAL=BLOCKED controls")
		return
	if uniform_option.name != "UniformSetOption" or hair_option.name != "HairStyleOption":
		_fail("C67_2_VISUAL=BLOCKED control_identity")
		return
	var uniform_rect := Rect2(uniform_option.position, uniform_option.size)
	var hair_rect := Rect2(hair_option.position, hair_option.size)
	if uniform_rect.intersects(hair_rect):
		_fail("C67_2_VISUAL=BLOCKED control_overlap")
		return
	if uniform_option.size.x <= 0.0 or uniform_option.size.y <= 0.0 or hair_option.size.x <= 0.0 or hair_option.size.y <= 0.0:
		_fail("C67_2_VISUAL=BLOCKED control_size")
		return
	if uniform_rect.position.x < 0.0 or uniform_rect.end.x > 1280.0 or hair_rect.position.x < 0.0 or hair_rect.end.x > 1280.0:
		_fail("C67_2_VISUAL=BLOCKED control_bounds")
		return

	# C67.2 owns the presence and non-overlap contract, not immutable coordinates.
	# Later BASE packs may reflow the top control band as long as Hair + Uniform
	# remain present, readable and non-overlapping.
	var armor_option := creator.get_node_or_null("ArmorSetOption") as OptionButton
	if armor_option != null:
		var armor_rect := Rect2(armor_option.position, armor_option.size)
		if armor_rect.intersects(uniform_rect) or armor_rect.intersects(hair_rect):
			_fail("C67_2_VISUAL=BLOCKED expansion_overlap")
			return

	var assembler := creator.current_assembler()
	if assembler == null or creator.current_uniform_set_id() != SET_LIAN or creator.current_hair_style_id() != HAIR_TOPKNOT:
		_fail("C67_2_VISUAL=BLOCKED preview_state")
		return
	for slot_name in ["torso_outer", "arms", "waist", "legs", "feet"]:
		if assembler.get_node_or_null("Module_%s" % slot_name) == null:
			_fail("C67_2_VISUAL=BLOCKED preview_uniform:%s" % slot_name)
			return
	if assembler.get_node_or_null("Module_hair_back") == null or assembler.get_node_or_null("Module_hair_front") == null:
		_fail("C67_2_VISUAL=BLOCKED preview_hair")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C67_2_VISUAL=BLOCKED capture")
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C67_2_VISUAL=BLOCKED save")
		return

	print("C67_2_VISUAL_REVIEW=PASS set=uniform_01_lian_martial hair=hair_01_lian_topknot")
	print("C67_2_VISUAL_LAYOUT=PASS uniform_control=true hair_control=true overlap=false expansion_aware=true")
	print("C67_2_VISUAL_PREVIEW=PASS uniform_modules=5 hair_nodes=2")
	print("C67_2_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	creator.queue_free()
	await process_frame
	quit(0)

# Tehkné Solutions
