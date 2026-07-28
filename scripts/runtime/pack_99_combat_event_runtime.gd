extends Node

const PACK_07_ROOT := "res://assets/packs/pack_07_heroes_masters/runtime/hd"
const PACK_09_ROOT := "res://assets/packs/pack_09_combat_vfx_skills/runtime/hd"

const PRESET_VISUALS := {
	&"adaptive_staff": {"class": "MONK", "variant": "BASE"},
	&"aerial_flow": {"class": "RANGER", "variant": "ASCENDED"},
	&"rock_guardian": {"class": "WARDEN", "variant": "BASE"},
	&"foundation_breaker": {"class": "REAVER", "variant": "ASCENDED"},
	&"lyra_elementalist": {"class": "MYSTIC", "variant": "ASCENDED"},
	&"rin_challenger": {"class": "SENTINEL", "variant": "BASE"}
}

const EVENT_VFX := {
	"parry": ["TM_VFX_IMPACT_PARRY_008.png", Color(0.55, 0.9, 1.0, 0.95)],
	"posture_break": ["TM_VFX_STATE_SHIELD_BREAK_008.png", Color(1.0, 0.78, 0.25, 0.95)],
	"disarm": ["TM_VFX_IMPACT_CRUSH_006.png", Color(1.0, 0.48, 0.2, 0.95)],
	"loot_weapon": ["TM_VFX_STATE_LOOT_003.png", Color(1.0, 0.78, 0.25, 0.95)],
	"loot_skill": ["TM_VFX_BUFF_FOCUS_007.png", Color(0.65, 0.42, 1.0, 0.95)],
	"grab": ["TM_VFX_DEBUFF_STUN_008.png", Color(1.0, 0.88, 0.35, 0.9)],
	"defeat": ["TM_VFX_STATE_DEATH_004.png", Color(0.32, 0.28, 0.42, 0.95)],
	"block": ["TM_VFX_IMPACT_BLOCK_007.png", Color(0.35, 0.68, 1.0, 0.88)],
	"technique": ["TM_VFX_IMPACT_MAGIC_009.png", Color(0.68, 0.42, 1.0, 0.9)],
	"fire": ["TM_VFX_IMPACT_FIRE_010.png", Color(1.0, 0.32, 0.12, 0.95)],
	"water": ["TM_VFX_PROJECTILE_ICE_ORB_005.png", Color(0.28, 0.72, 1.0, 0.92)],
	"earth": ["TM_VFX_IMPACT_CRUSH_006.png", Color(0.72, 0.52, 0.28, 0.95)],
	"air": ["TM_VFX_BUFF_SPEED_003.png", Color(0.42, 1.0, 0.82, 0.9)]
}

var _fighters: Dictionary = {}
var _last_direction: Dictionary = {}
var _last_technique: Dictionary = {}
var _last_blocking: Dictionary = {}
var _scan_timer := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_discover_fighters()
	for player_index in [1, 2]:
		var fighter: FighterController = _fighters.get(player_index)
		if not is_instance_valid(fighter):
			_fighters.erase(player_index)
			continue
		_update_direction(player_index, fighter)
		_update_action_events(player_index, fighter)

func _discover_fighters() -> void:
	var found: Array[Node] = []
	_collect_fighters(get_tree().root, found)
	for node in found:
		var fighter := node as FighterController
		var player_index := int(fighter.player_index)
		if player_index < 1 or player_index > 2:
			continue
		if _fighters.get(player_index) != fighter:
			_bind_fighter(player_index, fighter)

func _collect_fighters(node: Node, found: Array[Node]) -> void:
	if node is FighterController:
		found.append(node)
	for child in node.get_children():
		_collect_fighters(child, found)

func _bind_fighter(player_index: int, fighter: FighterController) -> void:
	_fighters[player_index] = fighter
	_last_direction[player_index] = ""
	_last_technique[player_index] = ""
	_last_blocking[player_index] = false
	_connect_signal(fighter, "parry_performed", Callable(self, "_on_parry").bind(player_index))
	_connect_signal(fighter, "posture_broken", Callable(self, "_on_posture_broken").bind(player_index))
	_connect_signal(fighter, "weapon_disarmed", Callable(self, "_on_weapon_disarmed").bind(player_index))
	_connect_signal(fighter, "loot_collected", Callable(self, "_on_loot_collected").bind(player_index))
	_connect_signal(fighter, "grab_started", Callable(self, "_on_grab_started").bind(player_index))
	_connect_signal(fighter, "defeated", Callable(self, "_on_defeated").bind(player_index))
	if fighter.has_signal("elemental_state_changed"):
		_connect_signal(fighter, "elemental_state_changed", Callable(self, "_on_elemental_state_changed").bind(player_index))
	if fighter.has_signal("elemental_interaction"):
		_connect_signal(fighter, "elemental_interaction", Callable(self, "_on_elemental_interaction").bind(player_index))
	_update_direction(player_index, fighter, true)

func _connect_signal(source: Object, signal_name: StringName, callable: Callable) -> void:
	if not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)

func _update_direction(player_index: int, fighter: FighterController, force := false) -> void:
	var direction := _direction_for(fighter)
	if not force and String(_last_direction.get(player_index, "")) == direction:
		return
	_last_direction[player_index] = direction
	var sprite := fighter.get_node_or_null("Pack99CharacterVisual") as Sprite2D
	if sprite == null:
		return
	var visual := visual_for_preset(fighter.build_preset)
	var path := hero_texture_path(String(visual["class"]), direction, String(visual["variant"]))
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
		sprite.flip_h = false
	else:
		# O fallback existente é espelhado para comunicar direção mesmo sem binários.
		sprite.flip_h = fighter.facing < 0.0

func _direction_for(fighter: FighterController) -> String:
	var airborne := not fighter.is_on_floor() and absf(fighter.velocity.y) > 45.0
	if fighter.facing >= 0.0:
		return "NE" if airborne else "SE"
	return "NW" if airborne else "SW"

func visual_for_preset(preset_id: StringName) -> Dictionary:
	return Dictionary(PRESET_VISUALS.get(preset_id, {"class": "MONK", "variant": "BASE"})).duplicate(true)

func hero_texture_path(class_id: String, direction: String, variant: String) -> String:
	return "%s/TM_HERO_%s_%s_%s_001.png" % [PACK_07_ROOT, class_id, direction, variant]

func _update_action_events(player_index: int, fighter: FighterController) -> void:
	var technique := fighter.current_technique_label()
	var previous_technique := String(_last_technique.get(player_index, ""))
	var attack_active := int(fighter._attack_phase) != int(FighterController.AttackPhase.NONE)
	if attack_active and technique != previous_technique and not technique.is_empty():
		_last_technique[player_index] = technique
		_spawn_event(fighter, "technique", Vector2(0, -62), 0.34)
	elif not attack_active:
		_last_technique[player_index] = ""

	var blocking := bool(fighter._is_blocking)
	if blocking and not bool(_last_blocking.get(player_index, false)):
		_spawn_event(fighter, "block", Vector2(0, -52), 0.3)
	_last_blocking[player_index] = blocking

func _spawn_event(fighter: FighterController, event_id: String, offset := Vector2.ZERO, scale := 0.4) -> void:
	if not is_instance_valid(fighter):
		return
	var spec: Array = EVENT_VFX.get(event_id, EVENT_VFX["technique"])
	var path := "%s/%s" % [PACK_09_ROOT, String(spec[0])]
	_spawn_vfx(fighter.global_position + offset, path, spec[1] as Color, scale)

func _spawn_vfx(world_position: Vector2, texture_path: String, fallback_color: Color, initial_scale := 0.4) -> void:
	if get_tree().current_scene == null:
		return
	var sprite := Sprite2D.new()
	sprite.global_position = world_position
	sprite.z_index = 90
	sprite.scale = Vector2.ONE * initial_scale
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		sprite.texture = _fallback_vfx_texture(fallback_color)
	get_tree().current_scene.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 1.55, 0.24)
	tween.tween_property(sprite, "rotation", 0.16, 0.24)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(sprite.queue_free)

func _fallback_vfx_texture(color: Color) -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(64, 64)
	for y in range(128):
		for x in range(128):
			var distance := Vector2(x, y).distance_to(center)
			if distance < 54.0:
				var alpha := clampf(1.0 - distance / 54.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * color.a))
	return ImageTexture.create_from_image(image)

func _on_parry(fighter: FighterController, _player_index: int) -> void:
	_spawn_event(fighter, "parry", Vector2(0, -58), 0.38)

func _on_posture_broken(fighter: FighterController, _region_id: StringName, _player_index: int) -> void:
	_spawn_event(fighter, "posture_break", Vector2(0, -44), 0.46)

func _on_weapon_disarmed(fighter: FighterController, _weapon_id: StringName, _player_index: int) -> void:
	_spawn_event(fighter, "disarm", Vector2(0, -35), 0.44)

func _on_loot_collected(fighter: FighterController, loot_type: StringName, _item_id: StringName, _player_index: int) -> void:
	_spawn_event(fighter, "loot_weapon" if loot_type == &"weapon" else "loot_skill", Vector2(0, -78), 0.36)

func _on_grab_started(attacker: FighterController, target: FighterController, _player_index: int) -> void:
	_spawn_event(attacker, "grab", Vector2(0, -45), 0.32)
	_spawn_event(target, "grab", Vector2(0, -38), 0.28)

func _on_defeated(fighter: FighterController, _player_index: int) -> void:
	_spawn_event(fighter, "defeat", Vector2(0, -58), 0.52)

func _on_elemental_state_changed(fighter: FighterController, _status_id: StringName, _player_index: int) -> void:
	_spawn_event(fighter, String(fighter.build.element_id), Vector2(0, -62), 0.38)

func _on_elemental_interaction(fighter: FighterController, _interaction_id: StringName, element_id: StringName, _player_index: int) -> void:
	_spawn_event(fighter, String(element_id), Vector2(0, -52), 0.42)
