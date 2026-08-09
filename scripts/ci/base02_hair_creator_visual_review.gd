extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const STYLE := &"hair_01_lian_topknot"
const OUTPUT := "res://artifacts/c66_2/C66_2_HAIR_CREATOR_CONTROL.review-1280x720.png"

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	FirstPlayableSession.reset()
	quit(2)

func _run() -> void:
	FirstPlayableSession.reset()
	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C66_2_VISUAL=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(8):
		await process_frame

	creator.set_display_name("MESTRE TAIJIFU")
	creator.set_preset_id("mestre_taijifu")
	var failures := creator.set_hair_style(STYLE)
	if not failures.is_empty():
		_fail("C66_2_VISUAL=BLOCKED hair:%s" % ",".join(failures))
		return
	for _frame in range(8):
		await process_frame

	var option := creator.hair_style_option()
	if option == null or not option.visible or option.item_count != 2:
		_fail("C66_2_VISUAL=BLOCKED option")
		return
	if creator.current_hair_style_id() != STYLE:
		_fail("C66_2_VISUAL=BLOCKED style")
		return
	var assembler := creator.current_assembler()
	var back := assembler.get_node_or_null("Module_hair_back") as Sprite2D
	var front := assembler.get_node_or_null("Module_hair_front") as Sprite2D
	if back == null or front == null:
		_fail("C66_2_VISUAL=BLOCKED preview_hair")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C66_2_VISUAL=BLOCKED capture")
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C66_2_VISUAL=BLOCKED save")
		return

	print("C66_2_VISUAL_REVIEW=PASS style=hair_01_lian_topknot")
	print("C66_2_VISUAL_CONTROL=PASS node=HairStyleOption location=creator_header")
	print("C66_2_VISUAL_PREVIEW=PASS hair_back=true hair_front=true")
	print("C66_2_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	creator.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

# Tehkné Solutions
