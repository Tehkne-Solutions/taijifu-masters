extends Node2D

## VM02-B1 integrated locomotion runtime gate for Lian Wu.
## Tehkné Solutions

const LOGICAL_SIZE := Vector2i(1280, 720)
const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-b1/lian-wu-integrated-locomotion-1920x1080.png"
const CANONICAL_SOURCE := "res://assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
const VISUAL_HEIGHT := 150.0
const GROUND_Y := 535.0
const START_X := 145.0
const GRAVITY := 900.0
const JUMP_VELOCITY := -360.0

const STATE_ORDER := ["idle", "walk", "run", "jump_start", "jump_loop", "fall", "land", "idle"]
const FRAME_COUNTS := {
	"idle": 6,
	"walk": 8,
	"run": 8,
	"jump_start": 4,
	"jump_loop": 3,
	"fall": 3,
	"land": 4,
}
const FPS := {
	"idle": 8.0,
	"walk": 10.0,
	"run": 12.0,
	"jump_start": 12.0,
	"jump_loop": 12.0,
	"fall": 12.0,
	"land": 12.0,
}
const LOOPING := {
	"idle": true,
	"walk": true,
	"run": true,
	"jump_start": false,
	"jump_loop": true,
	"fall": true,
	"land": false,
}

var _textures: Dictionary = {}
var _bounds: Dictionary = {}
var _actor: Sprite2D
var _state_label: Label
var _metric_label: Label
var _state := "idle"
var _state_elapsed := 0.0
var _total_elapsed := 0.0
var _actor_pos := Vector2(START_X, GROUND_Y)
var _velocity := Vector2.ZERO
var _visited: Array[String] = []
var _max_air_height := 0.0
var _landed := false
var _finished := false
var _capture_and_quit := false
var _canonical_height := 900.0
var _scale_factor := 1.0

func _ready() -> void:
	_capture_and_quit = OS.get_cmdline_user_args().has("--capture-and-quit")
	_build_background()
	_build_header()
	var failures := _load_all_frames()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		print("VM02_B1_LOCOMOTION_RUNTIME=BLOCKED_ASSET_LOAD")
		if _capture_and_quit: get_tree().quit(2)
		return
	_build_actor()
	_enter_state("idle")
	print("VM02_B1_LOCOMOTION_ASSETS=PASS")
	print("VM02_B1_LOCOMOTION_FRAME_TOTAL=36")

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.065, 0.085, 1.0)
	bg.position = Vector2.ZERO
	bg.size = Vector2(LOGICAL_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)

func _build_header() -> void:
	var title := Label.new()
	title.text = "VM02-B1 — LIAN WU / INTEGRATED LOCOMOTION RUNTIME GATE"
	title.position = Vector2(48, 24)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Tehkné Solutions · Idle → Walk → Run → Jump Start → Jump Loop → Fall → Land → Idle"
	subtitle.position = Vector2(50, 55)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(0.72, 0.76, 0.82, 1.0)
	add_child(subtitle)
	_state_label = Label.new()
	_state_label.position = Vector2(48, 94)
	_state_label.add_theme_font_size_override("font_size", 16)
	add_child(_state_label)
	_metric_label = Label.new()
	_metric_label.position = Vector2(48, 120)
	_metric_label.add_theme_font_size_override("font_size", 12)
	_metric_label.modulate = Color(0.75, 0.82, 0.90, 1.0)
	add_child(_metric_label)

func _frame_dir(state: String) -> String:
	return "res://assets/pack_01_characters/lian_wu/frames/%s" % state

func _frame_path(state: String, frame_number: int) -> String:
	return "%s/char_lian_wu__%s__f%02d.png" % [_frame_dir(state), state, frame_number]

func _load_png_texture(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path): return null
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty(): return null
	return ImageTexture.create_from_image(image)

func _alpha_bounds(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	if image == null or image.is_empty(): return Rect2i()
	var min_x := image.get_width(); var min_y := image.get_height(); var max_x := -1; var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01: continue
			min_x = mini(min_x, x); min_y = mini(min_y, y); max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y: return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _load_all_frames() -> Array[String]:
	var failures: Array[String] = []
	var total := 0
	for state in FRAME_COUNTS.keys():
		var frames: Array[Texture2D] = []
		var state_bounds: Array[Rect2i] = []
		for frame_number in range(1, int(FRAME_COUNTS[state]) + 1):
			var path := _frame_path(state, frame_number)
			var texture := _load_png_texture(path)
			if texture == null:
				failures.append("missing/invalid frame %s" % path)
				continue
			var bounds := _alpha_bounds(texture)
			if bounds.size == Vector2i.ZERO:
				failures.append("empty alpha frame %s" % path)
				continue
			frames.append(texture)
			state_bounds.append(bounds)
			total += 1
		_textures[state] = frames
		_bounds[state] = state_bounds
	if total != 36: failures.append("expected 36 frames, loaded %d" % total)
	var canonical := _load_png_texture(CANONICAL_SOURCE)
	if canonical == null:
		failures.append("canonical Character Lock missing")
	else:
		var cb := _alpha_bounds(canonical)
		_canonical_height = float(cb.size.y)
		_scale_factor = VISUAL_HEIGHT / maxf(1.0, _canonical_height)
	return failures

func _build_actor() -> void:
	_actor = Sprite2D.new()
	_actor.centered = false
	_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actor.scale = Vector2.ONE * _scale_factor
	_actor.z_index = 10
	add_child(_actor)

func _enter_state(next_state: String) -> void:
	_state = next_state
	_state_elapsed = 0.0
	_visited.append(next_state)
	if next_state == "jump_start":
		_velocity.y = JUMP_VELOCITY
	_snapshot_state(next_state)
	print("VM02_B1_STATE_ENTER=%s" % next_state)

func _snapshot_state(state_name: String) -> void:
	if not _textures.has(state_name): return
	var frames: Array = _textures[state_name]
	var state_bounds: Array = _bounds[state_name]
	if frames.is_empty(): return
	var ghost := Sprite2D.new()
	ghost.centered = false
	ghost.texture = frames[0]
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = Vector2.ONE * (_scale_factor * 0.72)
	var b: Rect2i = state_bounds[0]
	var pivot := Vector2(float(b.position.x) + float(b.size.x - 1) * 0.5, float(b.position.y + b.size.y - 1))
	var snap_pos := _actor_pos
	ghost.position = snap_pos - pivot * ghost.scale.x
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.34)
	ghost.z_index = 3
	add_child(ghost)
	var label := Label.new()
	label.text = state_name.replace("_", " ").to_upper()
	label.position = Vector2(snap_pos.x - 55.0, GROUND_Y + 32.0)
	label.size = Vector2(110, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(0.72, 0.78, 0.86, 0.78)
	add_child(label)

func _current_frame_index() -> int:
	var count := int(FRAME_COUNTS[_state])
	var raw := int(floor(_state_elapsed * float(FPS[_state])))
	if bool(LOOPING[_state]): return raw % count
	return mini(raw, count - 1)

func _update_actor_visual() -> void:
	var frames: Array = _textures[_state]
	var state_bounds: Array = _bounds[_state]
	var index := _current_frame_index()
	_actor.texture = frames[index]
	var b: Rect2i = state_bounds[index]
	var pivot := Vector2(float(b.position.x) + float(b.size.x - 1) * 0.5, float(b.position.y + b.size.y - 1))
	_actor.position = _actor_pos - pivot * _scale_factor
	_state_label.text = "STATE: %s  ·  FRAME %02d/%02d" % [_state.to_upper(), index + 1, int(FRAME_COUNTS[_state])]
	_metric_label.text = "x=%.1f  y=%.1f  vy=%.1f  visited=%d/8" % [_actor_pos.x, _actor_pos.y, _velocity.y, _visited.size()]

func _process(delta: float) -> void:
	if _actor == null or _finished: return
	_state_elapsed += delta
	_total_elapsed += delta
	match _state:
		"idle":
			if _visited.size() == 1 and _state_elapsed >= 0.45: _enter_state("walk")
			elif _visited.size() >= 8 and _state_elapsed >= 0.40: _finish_gate()
		"walk":
			_actor_pos.x += 68.0 * delta
			if _state_elapsed >= 0.85: _enter_state("run")
		"run":
			_actor_pos.x += 142.0 * delta
			if _state_elapsed >= 0.75: _enter_state("jump_start")
		"jump_start":
			_actor_pos.x += 118.0 * delta
			_apply_air_physics(delta)
			if _state_elapsed >= float(FRAME_COUNTS["jump_start"]) / float(FPS["jump_start"]): _enter_state("jump_loop")
		"jump_loop":
			_actor_pos.x += 108.0 * delta
			_apply_air_physics(delta)
			if _velocity.y >= 155.0: _enter_state("fall")
		"fall":
			_actor_pos.x += 92.0 * delta
			_apply_air_physics(delta)
			if _actor_pos.y >= GROUND_Y:
				_actor_pos.y = GROUND_Y
				_velocity.y = 0.0
				_landed = true
				_enter_state("land")
		"land":
			if _state_elapsed >= float(FRAME_COUNTS["land"]) / float(FPS["land"]): _enter_state("idle")
	_update_actor_visual()
	queue_redraw()

func _apply_air_physics(delta: float) -> void:
	_velocity.y += GRAVITY * delta
	_actor_pos.y += _velocity.y * delta
	_max_air_height = maxf(_max_air_height, GROUND_Y - _actor_pos.y)

func _finish_gate() -> void:
	_finished = true
	var failures: Array[String] = []
	if _visited != STATE_ORDER: failures.append("state order mismatch: %s" % [_visited])
	if _actor_pos.x - START_X < 180.0: failures.append("horizontal displacement too small: %.2f" % (_actor_pos.x - START_X))
	if _max_air_height < 35.0: failures.append("jump apex too low: %.2f" % _max_air_height)
	if not _landed: failures.append("landing was not observed")
	if absf(_actor_pos.y - GROUND_Y) > 0.01: failures.append("final actor is not grounded")
	if _state != "idle": failures.append("final state is not idle")
	print("VM02_B1_LOCOMOTION_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_B1_STATE_ORDER=%s" % ["PASS" if _visited == STATE_ORDER else "BLOCKED"])
	print("VM02_B1_HORIZONTAL_DISPLACEMENT=%.2f" % (_actor_pos.x - START_X))
	print("VM02_B1_MAX_AIR_HEIGHT=%.2f" % _max_air_height)
	print("VM02_B1_LANDING=%s" % ("PASS" if _landed else "BLOCKED"))
	for failure in failures: push_error(failure)
	if not failures.is_empty():
		if _capture_and_quit: get_tree().quit(3)
		return
	if _capture_and_quit: call_deferred("_capture_and_quit_gate")

func _capture_and_quit_gate() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-b1"))
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_B1_LOCOMOTION_CAPTURE_NORMALIZED=PASS")
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("failed to save integrated locomotion gate capture")
		get_tree().quit(4)
		return
	print("VM02_B1_LOCOMOTION_CAPTURE=PASS")
	print("VM02_B1_LOCOMOTION_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)

func _draw() -> void:
	draw_line(Vector2(50, GROUND_Y), Vector2(1230, GROUND_Y), Color(0.38, 0.72, 0.95, 0.5), 1.5)
	for x in range(80, 1240, 80):
		draw_line(Vector2(x, GROUND_Y - 4), Vector2(x, GROUND_Y + 4), Color(0.35, 0.42, 0.50, 0.35), 1.0)
