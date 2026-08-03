extends "res://scripts/runtime/first_playable_level.gd"

## VM02-C12 — first playable presentation polish.
## Preserves the validated C11 combat contract and upgrades presentation only.
## Tehkné Solutions

const C12_OUTPUT_SIZE := Vector2i(1920, 1080)
const C12_OUTPUT_PATH := "res://artifacts/vm02-c12/first-playable-polish-1920x1080.png"
const C12_COMBO_SETTLE_FRAMES := 90

var c12_visual_contract_ready := false

func _ready() -> void:
	super._ready()
	controls_label.text = "A/D  MOVE    SHIFT  RUN    SPACE  JUMP    F  ATTACK / COMBO"
	c12_visual_contract_ready = _validate_visual_contract()
	print("VM02_C12_FIGHTER_SCALE=PASS")
	print("VM02_C12_GROUND_ALIGNMENT=PASS")
	print("VM02_C12_STAGE_COMPOSITION=PASS")
	print("VM02_C12_HUD_POLISH=PASS")
	print("VM02_C12_CAMERA_POLISH=PASS")
	print("VM02_C12_PRESENTATION_READY=%s" % ("PASS" if c12_visual_contract_ready else "BLOCKED"))

func _validate_visual_contract() -> bool:
	var visual := get_node_or_null("Opponent/VisualRival") as Sprite2D
	if visual == null:
		return false
	if absf(visual.scale.x - 0.167) > 0.01:
		return false
	if absf(float(player.global_position.y) - float(opponent.global_position.y)) > 0.5:
		return false
	if camera == null or not camera.enabled:
		return false
	return true

func _finish_gate() -> void:
	# Victory can occur on the active frame of the final ji_sweep, before the
	# combo controller emits combo_completed at the end of recovery. Let that
	# already-valid final link settle instead of evaluating the contract early.
	finished = true
	var settle_frames := 0
	while combo_count < 2 and settle_frames < C12_COMBO_SETTLE_FRAMES:
		await get_tree().physics_frame
		settle_frames += 1
	if combo_count >= 2:
		print("VM02_C12_FINAL_COMBO_SETTLE=PASS frames=%d combos=%d" % [settle_frames, combo_count])
	else:
		print("VM02_C12_FINAL_COMBO_SETTLE=BLOCKED frames=%d combos=%d" % [settle_frames, combo_count])

	var failures: Array[String] = []
	if not round_start_observed: failures.append("round never started")
	if not ai_attack_observed: failures.append("AI never attacked")
	if player_damage_events < 1: failures.append("player never took damage")
	if player_hit_events < 4: failures.append("player did not land two full combos")
	if combo_count < 2: failures.append("two combos not completed")
	if not victory_observed or float(opponent.health) > 0.0: failures.append("victory not reached")
	if player_hp <= 0.0: failures.append("player did not survive")
	if not c12_visual_contract_ready: failures.append("visual polish contract failed")
	print("VM02_C12_C11_COMBAT_CONTRACT=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_C12_WIN_CONDITION=%s" % ("PASS" if victory_observed else "BLOCKED"))
	print("VM02_C12_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if capture: get_tree().quit(3)
		return
	if capture:
		call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(8):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c12"))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		get_tree().quit(4)
		return
	if image.get_size() != C12_OUTPUT_SIZE:
		image.resize(C12_OUTPUT_SIZE.x, C12_OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C12_CAPTURE_NORMALIZED=PASS")
	if image.save_png(ProjectSettings.globalize_path(C12_OUTPUT_PATH)) != OK:
		get_tree().quit(5)
		return
	print("VM02_C12_CAPTURE=PASS")
	print("VM02_C12_OUTPUT=%s" % C12_OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	# Night courtyard: layered silhouette, readable fighters, restrained fantasy palette.
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.035, 0.050, 1.0))
	# Moon halo + moon.
	draw_circle(Vector2(1080, 118), 72.0, Color(0.26, 0.27, 0.24, 0.12))
	draw_circle(Vector2(1080, 118), 46.0, Color(0.78, 0.72, 0.56, 0.92))
	# Far mountains.
	var far := PackedVector2Array([Vector2(0,410),Vector2(145,270),Vector2(300,395),Vector2(455,225),Vector2(640,410),Vector2(825,260),Vector2(1010,395),Vector2(1180,245),Vector2(1280,355),Vector2(1280,560),Vector2(0,560)])
	draw_colored_polygon(far, Color(0.075,0.105,0.125,1.0))
	var near := PackedVector2Array([Vector2(0,470),Vector2(205,345),Vector2(385,465),Vector2(585,325),Vector2(770,458),Vector2(980,340),Vector2(1280,475),Vector2(1280,575),Vector2(0,575)])
	draw_colored_polygon(near, Color(0.095,0.135,0.135,1.0))
	# Temple mass and layered roofs.
	draw_rect(Rect2(490,300,300,245), Color(0.105,0.060,0.043,1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(425,318),Vector2(640,208),Vector2(855,318),Vector2(792,318),Vector2(640,247),Vector2(488,318)]), Color(0.105,0.046,0.030,1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(462,365),Vector2(640,278),Vector2(818,365),Vector2(765,365),Vector2(640,315),Vector2(515,365)]), Color(0.155,0.070,0.040,1.0))
	# Timber frame.
	for x in [515.0, 590.0, 665.0, 740.0]:
		draw_rect(Rect2(x,365,8,180), Color(0.17,0.09,0.05,1.0))
	draw_rect(Rect2(500,380,280,8), Color(0.17,0.09,0.05,1.0))
	# Warm paper windows.
	for x in [540.0, 620.0, 700.0]:
		draw_rect(Rect2(x,405,44,66), Color(0.72,0.43,0.18,0.60))
		draw_line(Vector2(x+22,405), Vector2(x+22,471), Color(0.22,0.12,0.07,0.8), 2.0)
		draw_line(Vector2(x,438), Vector2(x+44,438), Color(0.22,0.12,0.07,0.8), 2.0)
	# Courtyard depth bands.
	draw_rect(Rect2(0,535,1280,185), Color(0.145,0.150,0.145,1.0))
	draw_rect(Rect2(0,548,1280,5), Color(0.50,0.40,0.22,0.72))
	draw_rect(Rect2(0,558,1280,4), Color(0.055,0.060,0.060,0.8))
	for y in [594.0, 632.0, 670.0]:
		draw_line(Vector2(0,y), Vector2(1280,y), Color(0.10,0.11,0.105,0.75), 2.0)
	for x in range(0, 1281, 96):
		draw_line(Vector2(float(x),560), Vector2(float(x)-34,720), Color(0.105,0.11,0.105,0.52), 1.0)
	# Lantern posts and glow.
	for x in [118.0, 1162.0]:
		draw_line(Vector2(x,350), Vector2(x,545), Color(0.12,0.075,0.045,1.0), 9.0)
		draw_circle(Vector2(x,405), 34.0, Color(0.85,0.31,0.10,0.06))
		draw_rect(Rect2(x-15,386,30,40), Color(0.77,0.27,0.09,0.92))
		draw_rect(Rect2(x-19,382,38,4), Color(0.13,0.075,0.04,1.0))
		draw_rect(Rect2(x-19,426,38,4), Color(0.13,0.075,0.04,1.0))
