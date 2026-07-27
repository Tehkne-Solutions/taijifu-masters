class_name ProvisionalSpritePresenter
extends Node2D

const FRAME_SIZE := Vector2(128.0, 128.0)
const CHARACTER_SHEETS := {
	&"kael": "res://assets/characters/kael/kael_provisional_sheet.svg",
	&"nara": "res://assets/characters/nara/nara_provisional_sheet.svg"
}
const STATE_FRAMES := {
	&"idle": 0,
	&"move": 1,
	&"attack": 2,
	&"guard": 3
}

var _fighter: FighterController
var _sprite: Sprite2D
var _atlas_texture: AtlasTexture
var _character_id: StringName = &"kael"
var _state_id: StringName = &"idle"
var _hurt_timer := 0.0
var _last_health := -1.0
var _active := false

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -17.0)
	_sprite.scale = Vector2(0.78, 0.78)
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
	_update_state(false)

func has_active_sprite() -> bool:
	return _active and is_instance_valid(_sprite) and is_instance_valid(_sprite.texture)

func character_id() -> StringName:
	return _character_id

func current_state_id() -> StringName:
	return _state_id

func _resolve_character() -> void:
	if not is_instance_valid(_fighter):
		return
	match _fighter.build_preset:
		&"rock_guardian", &"foundation_breaker":
			_character_id = &"nara"
		_:
			_character_id = &"kael"

func _load_sheet() -> void:
	var path := String(CHARACTER_SHEETS.get(_character_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		_active = false
		_sprite.visible = false
		push_warning("Spritesheet provisório ausente para %s; usando fallback procedural." % String(_character_id))
		return
	var texture := load(path) as Texture2D
	if not is_instance_valid(texture):
		_active = false
		_sprite.visible = false
		push_warning("Falha ao carregar spritesheet provisório: %s" % path)
		return
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = texture
	_sprite.texture = _atlas_texture
	_sprite.visible = true
	_active = true

func _on_combat_state_changed(_changed_fighter: FighterController) -> void:
	if not is_instance_valid(_fighter):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.01:
		_hurt_timer = 0.26
	_last_health = _fighter.health
	_update_state(false)

func _update_state(force: bool) -> void:
	if not has_active_sprite() or not is_instance_valid(_fighter):
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
	var frame := int(STATE_FRAMES.get(_state_id, 0))
	_atlas_texture.region = Rect2(Vector2(frame * FRAME_SIZE.x, 0.0), FRAME_SIZE)
