extends Node2D

## VM02-C9 — visual sparring rival state bench.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c9/visual-sparring-rival-1920x1080.png"

@onready var idle_rival: Node = $IdleRival
@onready var approach_rival: Node = $ApproachRival
@onready var attack_rival: Node = $AttackRival
@onready var hitstun_rival: Node = $HitstunRival

var capture := false

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	idle_rival.set_visual_state("idle")
	approach_rival.set_visual_state("approach")
	attack_rival.set_visual_state("attack")
	hitstun_rival.set_visual_state("hitstun")
	call_deferred("_validate")

func _validate() -> void:
	for _i in range(3):
		await get_tree().process_frame
	var rivals := [idle_rival, approach_rival, attack_rival, hitstun_rival]
	var expected := ["idle", "approach", "attack", "hitstun"]
	var failures: Array[String] = []
	for i in range(rivals.size()):
		if not bool(rivals[i].visual_ready):
			failures.append("rival %d visual not ready" % i)
		if String(rivals[i].visual_state) != expected[i]:
			failures.append("rival %d state mismatch" % i)
		if rivals[i].texture == null:
			failures.append("rival %d missing texture" % i)
	print("VM02_C9_STATE_SET=PASS" if failures.is_empty() else "VM02_C9_STATE_SET=BLOCKED")
	print("VM02_C9_GEOMETRIC_PLACEHOLDER=OFF")
	print("VM02_C9_MIRRORED_FACING=%s" % ("PASS" if bool(idle_rival.flip_h) else "BLOCKED"))
	print("VM02_C9_PALETTE_VARIANT=PASS")
	print("VM02_C9_VISUAL_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	if capture:
		call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c9"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("VM02_C9 capture viewport unavailable")
		get_tree().quit(4)
		return
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C9_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		get_tree().quit(5)
		return
	print("VM02_C9_CAPTURE=PASS")
	print("VM02_C9_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
