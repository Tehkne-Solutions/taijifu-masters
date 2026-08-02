class_name LianWuPlayerLocomotionController
extends CharacterBody2D

## Player-controlled Lian Wu locomotion using the approved 36/36 frame set.
## Tehkné Solutions

signal locomotion_state_changed(state: String)
signal landed

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

const CANONICAL_SOURCE := "res://assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
const VISUAL_HEIGHT := 150.0
const WALK_SPEED := 105.0
const RUN_SPEED := 210.0
const GROUND_ACCEL := 1250.0
const GROUND_DECEL := 1650.0
const AIR_ACCEL := 520.0
const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1250.0
const JUMP_VELOCITY := -390.0

var facing := 1.0
var locomotion_state := "idle"
var state_elapsed := 0.0
var max_air_height := 0.0
var takeoff_y := 0.0
var state_history: Array[String] = []

var _textures: Dictionary = {}
var _bounds: Dictionary = {}
var _sprite: Sprite2D
var _scale_factor := 1.0
var _was_on_floor := false
var _test_override := false
var _test_direction := 0.0
var _test_run := false
var _test_jump_edge := false

func _ready() -> void:
	var failures := _load_frames()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		set_physics_process(false)
		return
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * _scale_factor
	_sprite.z_index = 10
	add_child(_sprite)
	_enter_state("idle")
	_was_on_floor = is_on_floor()
	_update_visual()

func set_test_input(direction: float, run_pressed: bool, jump_edge: bool) -> void:
	_test_override = true
	_test_direction = clampf(direction, -1.0, 1.0)
	_test_run = run_pressed
	_test_jump_edge = jump_edge

func clear_test_input() -> void:
	_test_override = false
	_test_direction = 0.0
	_test_run = false
	_test_jump_edge = false

func _physics_process(delta: float) -> void:
	state_elapsed += delta
	var was_grounded := is_on_floor()
	var direction := _read_direction()
	var wants_run := _read_run()
	var jump_edge := _consume_jump_edge()

	if absf(direction) > 0.01:
		facing = signf(direction)

	if was_grounded and jump_edge and locomotion_state not in ["jump_start", "jump_loop", "fall"]:
		velocity.y = JUMP_VELOCITY
		takeoff_y = global_position.y
		max_air_height = 0.0
		_enter_state("jump_start")

	if not is_on_floor():
		velocity.y += (GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN) * delta
		velocity.y = minf(velocity.y, 980.0)

	var target_speed := 0.0
	if absf(direction) > 0.01:
		target_speed = direction * (RUN_SPEED if wants_run else WALK_SPEED)
	var accel := AIR_ACCEL if not is_on_floor() else GROUND_ACCEL
	var rate := accel if absf(target_speed) > absf(velocity.x) else (AIR_ACCEL if not is_on_floor() else GROUND_DECEL)
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	move_and_slide()
	var grounded := is_on_floor()
	if not grounded and takeoff_y != 0.0:
		max_air_height = maxf(max_air_height, takeoff_y - global_position.y)

	if not was_grounded and grounded:
		velocity.y = 0.0
		_enter_state("land")
		landed.emit()
	elif not grounded:
		_update_air_state()
	else:
		_update_ground_state(direction, wants_run)

	_update_visual()
	_was_on_floor = grounded

func _read_direction() -> float:
	if _test_override:
		return _test_direction
	return Input.get_axis(&"p1_left", &"p1_right")

func _read_run() -> bool:
	if _test_override:
		return _test_run
	return Input.is_key_pressed(KEY_SHIFT)

func _consume_jump_edge() -> bool:
	if _test_override:
		var value := _test_jump_edge
		_test_jump_edge = false
		return value
	return Input.is_action_just_pressed(&"p1_jump")

func _update_air_state() -> void:
	if locomotion_state == "jump_start":
		var duration := float(FRAME_COUNTS["jump_start"]) / float(FPS["jump_start"])
		if state_elapsed >= duration:
			_enter_state("jump_loop")
		return
	if velocity.y < 0.0:
		if locomotion_state != "jump_loop":
			_enter_state("jump_loop")
	else:
		if locomotion_state != "fall":
			_enter_state("fall")

func _update_ground_state(direction: float, wants_run: bool) -> void:
	if locomotion_state == "land":
		var duration := float(FRAME_COUNTS["land"]) / float(FPS["land"])
		if state_elapsed < duration:
			return
	if absf(direction) <= 0.01:
		if locomotion_state != "idle": _enter_state("idle")
	elif wants_run:
		if locomotion_state != "run": _enter_state("run")
	else:
		if locomotion_state != "walk": _enter_state("walk")

func _enter_state(next_state: String) -> void:
	if locomotion_state == next_state and not state_history.is_empty():
		return
	locomotion_state = next_state
	state_elapsed = 0.0
	state_history.append(next_state)
	locomotion_state_changed.emit(next_state)
	print("VM02_B2_STATE_ENTER=%s" % next_state)

func _current_frame_index() -> int:
	var count := int(FRAME_COUNTS[locomotion_state])
	var raw := int(floor(state_elapsed * float(FPS[locomotion_state])))
	if bool(LOOPING[locomotion_state]):
		return raw % count
	return mini(raw, count - 1)

func _update_visual() -> void:
	if _sprite == null or not _textures.has(locomotion_state):
		return
	var frames: Array = _textures[locomotion_state]
	var bounds_list: Array = _bounds[locomotion_state]
	if frames.is_empty(): return
	var index := _current_frame_index()
	_sprite.texture = frames[index]
	_sprite.flip_h = facing < 0.0
	var b: Rect2i = bounds_list[index]
	var pivot := Vector2(float(b.position.x) + float(b.size.x - 1) * 0.5, float(b.position.y + b.size.y - 1))
	if facing >= 0.0:
		_sprite.position = -pivot * _scale_factor
	else:
		var mirrored_pivot_x := float(_sprite.texture.get_width() - 1) - pivot.x
		_sprite.position = -Vector2(mirrored_pivot_x, pivot.y) * _scale_factor

func _frame_path(state: String, frame_number: int) -> String:
	return "res://assets/pack_01_characters/lian_wu/frames/%s/char_lian_wu__%s__f%02d.png" % [state, state, frame_number]

func _load_png_texture(path: String) -> Texture2D:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute): return null
	var image := Image.load_from_file(absolute)
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

func _load_frames() -> Array[String]:
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
				failures.append("empty frame %s" % path)
				continue
			frames.append(texture)
			state_bounds.append(bounds)
			total += 1
		_textures[state] = frames
		_bounds[state] = state_bounds
	var canonical := _load_png_texture(CANONICAL_SOURCE)
	if canonical == null:
		failures.append("canonical source missing")
	else:
		var cb := _alpha_bounds(canonical)
		_scale_factor = VISUAL_HEIGHT / maxf(1.0, float(cb.size.y))
	if total != 36:
		failures.append("expected 36 frames, loaded %d" % total)
	else:
		print("VM02_B2_LOCOMOTION_FRAME_TOTAL=36")
	return failures
