class_name ProvisionalSpritePresenter
extends Node2D

var _fighter: FighterController
var _sprite: Sprite2D
var _atlas_texture: AtlasTexture
var _character_id: StringName = &"kael"
var _state_id: StringName = &"idle"
var _frame_index := 0
var _frame_timer := 0.0
var _hurt_timer := 0.0
var _last_health := -1.0
var _active := false
var _preview_enabled := false
var _preview_state: StringName = &"attack"
var _preview_frame := 0

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -17.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_resolve_character()
	_load_sheet()
	if is_instance_valid(_fighter):
		_last_health = _fighter.health
		if _fighter.has_signal("combat_state_changed"):
			_fighter.combat_state_changed.connect(_on_combat_state_changed)
	_update_state(true)

func _process(delta: float) -> void:
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	if not is_instance_valid(_fighter):
		return
	_sprite.flip_h = _fighter.facing < 0.0
	var alpha := 0.48 if _fighter._dodge_timer > 0.0 else 1.0
	if is_instance_valid(_fighter._grabbed_by):
		alpha *= 0.72
	_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _preview_enabled:
		_state_id = _preview_state
		_frame_index = _preview_frame
		_set_frame(_frame_index)
		return
	_update_state(false)
	_advance_animation(delta)

func has_active_sprite() -> bool:
	return _active and is_instance_valid(_sprite) and is_instance_valid(_sprite.texture)

func character_id() -> StringName:
	return _character_id

func current_state_id() -> StringName:
	return _state_id

func current_frame_index() -> int:
	return _frame_index

func current_phase_id() -> StringName:
	return TechniqueVisualTimeline.phase_id(_fighter)

func set_visual_preview(state_id: StringName, frame_index: int) -> void:
	_preview_enabled = true
	_preview_state = state_id
	_preview_frame = clampi(frame_index, 0, CharacterVisualCatalog.columns(_character_id) - 1)
	_state_id = _preview_state
	_frame_index = _preview_frame
	_set_frame(_frame_index)

func clear_visual_preview() -> void:
	if not _preview_enabled:
		return
	_preview_enabled = false
	_update_state(true)

func is_visual_preview_active() -> bool:
	return _preview_enabled

func _resolve_character() -> void:
	if not is_instance_valid(_fighter):
		return
	if is_instance_valid(_fighter.build) and _fighter.build.character_id != &"":
		_character_id = _fighter.build.character_id
		return
	match _fighter.build_preset:
		&"rock_guardian", &"foundation_breaker":
			_character_id = &"nara"
		&"lyra_elementalist":
			_character_id = &"lyra"
		&"rin_challenger":
			_character_id = &"rin"
		_:
			_character_id = &"kael"

func _load_sheet() -> void:
	var path := CharacterVisualCatalog.sheet_path(_character_id)
	if path == "" or not ResourceLoader.exists(path):
		_active = false
		_sprite.visible = false
		push_warning("Atlas animado ausente para %s; usando fallback procedural." % String(_character_id))
		return
	var texture := load(path) as Texture2D
	if not is_instance_valid(texture):
		_active = false
		_sprite.visible = false
		push_warning("Falha ao carregar atlas animado: %s" % path)
		return
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = texture
	_sprite.texture = _atlas_texture
	_sprite.scale = Vector2.ONE * CharacterVisualCatalog.scale_for(_character_id)
	_sprite.visible = true
	_active = true
	_set_frame(0)

func _on_combat_state_changed(_changed_fighter: FighterController) -> void:
	if not is_instance_valid(_fighter):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.01:
		_hurt_timer = 0.26
	_last_health = _fighter.health
	if not _preview_enabled:
		_update_state(false)

func _update_state(force: bool) -> void:
	if _preview_enabled or not has_active_sprite() or not is_instance_valid(_fighter):
		return
	var next_state := &"idle"
	if _hurt_timer > 0.0 or is_instance_valid(_fighter._grabbed_by) or _fighter._is_blocking:
		next_state = &"guard"
	elif _fighter._attack_phase != FighterController.AttackPhase.NONE:
		next_state = &"attack"
	elif not _fighter.is_on_floor() or absf(_fighter.velocity.x) > 24.0:
		next_state = &"move"
	if not force and next_state == _state_id:
		return
	_state_id = next_state
	_frame_index = 0
	_frame_timer = 0.0
	if _state_id == &"attack":
		_frame_index = TechniqueVisualTimeline.frame_for_fighter(_fighter)
	_set_frame(_frame_index)

func _advance_animation(delta: float) -> void:
	if _preview_enabled or not has_active_sprite():
		return
	if _state_id == &"attack":
		var technique_frame := TechniqueVisualTimeline.frame_for_fighter(_fighter)
		if technique_frame != _frame_index:
			_frame_index = technique_frame
			_set_frame(_frame_index)
		return
	var fps := CharacterVisualCatalog.fps_for(_character_id, _state_id)
	_frame_timer += delta
	var frame_duration := 1.0 / fps
	while _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index = wrapi(_frame_index + 1, 0, CharacterVisualCatalog.columns(_character_id))
		_set_frame(_frame_index)

func _set_frame(frame_index: int) -> void:
	if not is_instance_valid(_atlas_texture):
		return
	var row := CharacterVisualCatalog.state_row(_state_id)
	_atlas_texture.region = Rect2(
		Vector2(frame_index * CharacterVisualCatalog.FRAME_SIZE.x, row * CharacterVisualCatalog.FRAME_SIZE.y),
		CharacterVisualCatalog.FRAME_SIZE
	)
