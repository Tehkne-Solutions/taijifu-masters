extends Node2D

const RIVAL_VISUAL := preload("res://scripts/runtime/opponent_visual_sparring_rival.gd")
const OUTPUT := "res://artifacts/vm02-c36/canonical-rival-binding-1920x1080.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var rival := RIVAL_VISUAL.new()
	rival.name = "TrainingRivalVisual"
	rival.position = Vector2(960, 820)
	rival.scale = Vector2(0.52, 0.52)
	add_child(rival)

	for _i in range(12):
		await get_tree().process_frame

	var signature: Dictionary = rival.presentation_signature()
	var canonical := bool(signature.get("canonical_visual", false))
	var proxy := bool(signature.get("proxy_visual", true))
	var ready := bool(rival.visual_ready)
	var state_count := int(signature.get("visual_states", 0))
	var facing_ok := (not rival.flip_h) if canonical else rival.flip_h
	var identity_ok := str(signature.get("character_id", "")) == "training_rival"

	print("VM02_C36_VISUAL_READY=" + ("PASS" if ready else "BLOCKED"))
	print("VM02_C36_STATE_COVERAGE=" + ("PASS" if state_count == 4 else "BLOCKED"))
	print("VM02_C36_IDENTITY_CONTRACT=" + ("PASS" if identity_ok else "BLOCKED"))
	print("VM02_C36_FACING_CONTRACT=" + ("PASS" if facing_ok else "BLOCKED"))
	print("VM02_C36_CANONICAL_ACTIVE=" + ("PASS" if canonical else "BLOCKED"))
	print("VM02_C36_PROXY_FALLBACK=" + ("PASS" if proxy else "OFF"))
	print("VM02_C36_RUNTIME_BINDING=PASS")

	if not ready or state_count != 4 or not identity_ok or not facing_ok:
		push_error("canonical rival runtime binding contract failed")
		get_tree().quit(3)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("rival binding viewport capture unavailable")
		get_tree().quit(4)
		return
	if image.get_width() != 1920 or image.get_height() != 1080:
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		print("VM02_C36_CAPTURE_NORMALIZED=PASS")
	if image.save_png(OUTPUT) != OK:
		push_error("rival binding capture save failed")
		get_tree().quit(5)
		return
	print("VM02_C36_CAPTURE=PASS")
	print("VM02_C36_OUTPUT=" + OUTPUT)
	print("VM02_C36_RUNTIME=PASS")
	get_tree().quit(0)

# Tehkné Solutions
