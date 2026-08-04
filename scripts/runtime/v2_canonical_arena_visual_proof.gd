extends Node

const FIRST_PLAYABLE := preload("res://scenes/vertical_slice/first_playable.tscn")
const OUTPUT := "res://artifacts/vm02-c35/mountain-dojo-night-runtime-1920x1080.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var playable := FIRST_PLAYABLE.instantiate()
	add_child(playable)

	for _i in range(24):
		await get_tree().process_frame

	var environment := playable.get_node_or_null("EnvironmentArt")
	if environment == null:
		push_error("missing EnvironmentArt")
		get_tree().quit(2)
		return

	var signature: Dictionary = environment.presentation_signature()
	var canonical_active := bool(signature.get("canonical_arena", false))
	var canonical_id := str(signature.get("canonical_arena_id", ""))
	var parallax_ready := playable.has_node("CanonicalArenaParallax")
	var procedural_retired := not playable.has_node("ArenaParallaxFar") and not playable.has_node("ArenaFinalLayer")

	print("VM02_C35_CANONICAL_ARENA_ACTIVE=" + ("PASS" if canonical_active else "BLOCKED"))
	print("VM02_C35_CANONICAL_ARENA_ID=" + canonical_id)
	print("VM02_C35_PARALLAX_NODE=" + ("PASS" if parallax_ready else "BLOCKED"))
	print("VM02_C35_PROCEDURAL_RETIRED=" + ("PASS" if procedural_retired else "BLOCKED"))

	if not canonical_active or canonical_id != "mountain_dojo_night" or not parallax_ready or not procedural_retired:
		push_error("canonical arena visual runtime contract failed")
		get_tree().quit(3)
		return

	var output_dir := OUTPUT.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("viewport capture unavailable")
		get_tree().quit(4)
		return

	if image.get_width() != 1920 or image.get_height() != 1080:
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)

	var save_error := image.save_png(OUTPUT)
	if save_error != OK:
		push_error("capture save failed: %s" % save_error)
		get_tree().quit(5)
		return

	print("VM02_C35_CAPTURE_NORMALIZED=PASS")
	print("VM02_C35_CAPTURE=PASS")
	print("VM02_C35_OUTPUT=" + OUTPUT)
	print("VM02_C35_RUNTIME=PASS")
	get_tree().quit(0)

# Tehkné Solutions
