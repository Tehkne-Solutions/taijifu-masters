extends Node

const PACK_08_ROOT := "res://assets/packs/pack_08_units_champions/runtime/hd"
const SPAWN_DELAY := 3.5
const ENEMY_WAVE_DELAY := 12.0
const CHAMPION_DELAY := 27.0
const UNIT_HIT_COOLDOWN := 0.7

const ARCHETYPES := {
	"soldier": {"file": "TM_UNIT_SOLDIER_SE_BASE_001.png", "health": 42.0, "speed": 88.0, "damage": 4.0, "posture": 6.0, "range": 72.0},
	"archer": {"file": "TM_UNIT_ARCHER_SE_BASE_001.png", "health": 30.0, "speed": 72.0, "damage": 3.2, "posture": 3.0, "range": 210.0},
	"guardian": {"file": "TM_UNIT_GUARDIAN_SE_BASE_001.png", "health": 58.0, "speed": 62.0, "damage": 3.4, "posture": 8.0, "range": 76.0},
	"wraith": {"file": "TM_UNIT_WRAITH_SW_BASE_001.png", "health": 38.0, "speed": 105.0, "damage": 4.8, "posture": 5.0, "range": 68.0},
	"golem": {"file": "TM_UNIT_GOLEM_SW_BASE_001.png", "health": 75.0, "speed": 48.0, "damage": 6.2, "posture": 11.0, "range": 82.0},
	"champion_dragon": {"file": "TM_CHAMPION_DRAGON_SW_BASE_001.png", "health": 145.0, "speed": 68.0, "damage": 8.0, "posture": 14.0, "range": 105.0}
}

var _fighters: Dictionary = {}
var _units: Array[Dictionary] = []
var _scan_timer := 0.0
var _encounter_time := 0.0
var _encounter_active := false
var _allies_spawned := false
var _enemy_wave_spawned := false
var _champion_spawned := false
var _last_fighter_attacks: Dictionary = {}

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_discover_fighters()
	_update_encounter(delta)
	_update_units(delta)
	_resolve_fighter_hits()

func _discover_fighters() -> void:
	var found: Array[Node] = []
	_collect_fighters(get_tree().root, found)
	var current: Dictionary = {}
	for node in found:
		var fighter := node as FighterController
		if fighter.player_index in [1, 2]:
			current[int(fighter.player_index)] = fighter
	_fighters = current
	if _fighters.size() < 2 and _encounter_active:
		_reset_encounter()

func _collect_fighters(node: Node, found: Array[Node]) -> void:
	if node is FighterController:
		found.append(node)
	for child in node.get_children():
		_collect_fighters(child, found)

func _update_encounter(delta: float) -> void:
	if _fighters.size() < 2:
		return
	if not _encounter_active:
		_encounter_active = true
		_encounter_time = 0.0
	_encounter_time += delta
	if not _allies_spawned and _encounter_time >= SPAWN_DELAY:
		_allies_spawned = true
		_spawn_unit("guardian", 1, _fighter_position(1) + Vector2(-110, 0))
		_spawn_unit("archer", 1, _fighter_position(1) + Vector2(-175, -12))
		_spawn_unit("soldier", 2, _fighter_position(2) + Vector2(110, 0))
		_spawn_unit("archer", 2, _fighter_position(2) + Vector2(175, -12))
	if not _enemy_wave_spawned and _encounter_time >= ENEMY_WAVE_DELAY:
		_enemy_wave_spawned = true
		var center := (_fighter_position(1) + _fighter_position(2)) * 0.5
		_spawn_unit("wraith", 0, center + Vector2(-70, -15))
		_spawn_unit("golem", 0, center + Vector2(90, 0))
	if not _champion_spawned and _encounter_time >= CHAMPION_DELAY:
		_champion_spawned = true
		var center := (_fighter_position(1) + _fighter_position(2)) * 0.5
		_spawn_unit("champion_dragon", 0, center + Vector2(0, -35))

func _spawn_unit(archetype: String, team: int, world_position: Vector2) -> void:
	if get_tree().current_scene == null or not ARCHETYPES.has(archetype):
		return
	var spec: Dictionary = Dictionary(ARCHETYPES[archetype]).duplicate(true)
	var node := Node2D.new()
	node.name = "Pack08_%s_%d" % [archetype, _units.size()]
	node.global_position = world_position
	node.z_index = 18 if archetype != "champion_dragon" else 22
	node.add_to_group("pack_08_arena_units")
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.position = Vector2(0, -46 if archetype != "champion_dragon" else -70)
	sprite.scale = Vector2.ONE * (0.22 if archetype != "champion_dragon" else 0.34)
	var path := "%s/%s" % [PACK_08_ROOT, String(spec["file"])]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		sprite.texture = _fallback_unit_texture(team, archetype == "champion_dragon")
	node.add_child(sprite)
	get_tree().current_scene.add_child(node)
	_units.append({
		"node": node,
		"sprite": sprite,
		"archetype": archetype,
		"team": team,
		"health": float(spec["health"]),
		"max_health": float(spec["health"]),
		"speed": float(spec["speed"]),
		"damage": float(spec["damage"]),
		"posture": float(spec["posture"]),
		"range": float(spec["range"]),
		"attack_timer": randf_range(0.1, 0.6),
		"fighter_hit_timer": 0.0
	})
	_spawn_pack_event(node.global_position, "technique")

func _update_units(delta: float) -> void:
	for index in range(_units.size() - 1, -1, -1):
		var unit: Dictionary = _units[index]
		var node := unit.get("node") as Node2D
		if not is_instance_valid(node):
			_units.remove_at(index)
			continue
		unit["attack_timer"] = maxf(0.0, float(unit["attack_timer"]) - delta)
		unit["fighter_hit_timer"] = maxf(0.0, float(unit["fighter_hit_timer"]) - delta)
		var target := _target_for(unit)
		if target == null:
			continue
		var target_position := _target_position(target)
		var distance := node.global_position.distance_to(target_position)
		var direction := signf(target_position.x - node.global_position.x)
		(unit["sprite"] as Sprite2D).flip_h = direction < 0.0
		if distance > float(unit["range"]):
			node.global_position.x += direction * float(unit["speed"]) * delta
		else:
			_attack_target(unit, target)

func _target_for(unit: Dictionary) -> Variant:
	var team := int(unit["team"])
	var candidates: Array[Variant] = []
	if team == 1:
		if _fighters.has(2): candidates.append(_fighters[2])
	elif team == 2:
		if _fighters.has(1): candidates.append(_fighters[1])
	else:
		for fighter in _fighters.values(): candidates.append(fighter)
	for other in _units:
		if other == unit or not is_instance_valid(other.get("node")):
			continue
		var other_team := int(other["team"])
		if team == 0 and other_team != 0:
			candidates.append(other)
		elif team != 0 and other_team == 0:
			candidates.append(other)
	if candidates.is_empty():
		return null
	var origin := (unit["node"] as Node2D).global_position
	var nearest: Variant = candidates[0]
	var nearest_distance := origin.distance_to(_target_position(nearest))
	for candidate in candidates:
		var candidate_distance := origin.distance_to(_target_position(candidate))
		if candidate_distance < nearest_distance:
			nearest = candidate
			nearest_distance = candidate_distance
	return nearest

func _attack_target(unit: Dictionary, target: Variant) -> void:
	if float(unit["attack_timer"]) > 0.0:
		return
	unit["attack_timer"] = UNIT_HIT_COOLDOWN + randf_range(0.0, 0.35)
	var origin := (unit["node"] as Node2D).global_position
	if target is FighterController:
		var fighter := target as FighterController
		var knockback := Vector2(signf(fighter.global_position.x - origin.x) * 55.0, -24.0)
		fighter.receive_hit(float(unit["damage"]), float(unit["posture"]), knockback, origin)
	else:
		_damage_unit(target as Dictionary, float(unit["damage"]) * 1.6, int(unit["team"]))
	_spawn_pack_event(origin + Vector2(0, -35), "technique")

func _resolve_fighter_hits() -> void:
	for player_index in [1, 2]:
		var fighter: FighterController = _fighters.get(player_index)
		if not is_instance_valid(fighter):
			continue
		var active := int(fighter._attack_phase) == int(FighterController.AttackPhase.ACTIVE)
		if not active:
			_last_fighter_attacks[player_index] = false
			continue
		if bool(_last_fighter_attacks.get(player_index, false)):
			continue
		_last_fighter_attacks[player_index] = true
		for unit in _units:
			var node := unit.get("node") as Node2D
			if not is_instance_valid(node) or float(unit["fighter_hit_timer"]) > 0.0:
				continue
			if fighter.global_position.distance_to(node.global_position) <= 125.0:
				unit["fighter_hit_timer"] = 0.28
				_damage_unit(unit, 18.0 + fighter.build.strength * 0.12, player_index)

func _damage_unit(unit: Dictionary, damage: float, killer_team: int) -> void:
	unit["health"] = float(unit["health"]) - damage
	var node := unit.get("node") as Node2D
	if is_instance_valid(node):
		_spawn_pack_event(node.global_position + Vector2(0, -42), "posture_break")
	if float(unit["health"]) <= 0.0:
		_defeat_unit(unit, killer_team)

func _defeat_unit(unit: Dictionary, killer_team: int) -> void:
	var node := unit.get("node") as Node2D
	if is_instance_valid(node):
		_spawn_pack_event(node.global_position + Vector2(0, -50), "defeat")
		node.queue_free()
	var fighter: FighterController = _fighters.get(killer_team)
	if is_instance_valid(fighter):
		var champion_bonus := 24.0 if String(unit["archetype"]) == "champion_dragon" else 8.0
		fighter.health = minf(fighter.build.max_health(), fighter.health + champion_bonus)
		fighter.stamina = minf(100.0, fighter.stamina + champion_bonus * 1.5)
		_spawn_pack_event(fighter.global_position + Vector2(0, -72), "loot_skill" if champion_bonus > 10.0 else "loot_weapon")
	_units.erase(unit)

func _spawn_pack_event(position: Vector2, event_id: String) -> void:
	var runtime := get_node_or_null("/root/Pack99CombatEventRuntime")
	if runtime != null and runtime.has_method("_spawn_vfx"):
		var colors := {"technique": Color(0.65, 0.45, 1.0, 0.8), "posture_break": Color(1.0, 0.72, 0.22, 0.9), "defeat": Color(0.32, 0.28, 0.42, 0.9), "loot_weapon": Color(1.0, 0.8, 0.25, 0.9), "loot_skill": Color(0.55, 1.0, 0.72, 0.9)}
		runtime.call("_spawn_vfx", position, "", colors.get(event_id, Color.WHITE), 0.3)

func _target_position(target: Variant) -> Vector2:
	if target is FighterController:
		return (target as FighterController).global_position
	if target is Dictionary:
		var node := (target as Dictionary).get("node") as Node2D
		if is_instance_valid(node): return node.global_position
	return Vector2.ZERO

func _fighter_position(player_index: int) -> Vector2:
	var fighter: FighterController = _fighters.get(player_index)
	return fighter.global_position if is_instance_valid(fighter) else Vector2.ZERO

func _reset_encounter() -> void:
	for unit in _units:
		var node := unit.get("node") as Node2D
		if is_instance_valid(node): node.queue_free()
	_units.clear()
	_encounter_active = false
	_encounter_time = 0.0
	_allies_spawned = false
	_enemy_wave_spawned = false
	_champion_spawned = false
	_last_fighter_attacks.clear()

func _fallback_unit_texture(team: int, champion: bool) -> Texture2D:
	var size := 190 if champion else 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := Color(0.28, 0.72, 1.0, 0.94) if team == 1 else Color(1.0, 0.42, 0.25, 0.94) if team == 2 else Color(0.7, 0.35, 0.85, 0.94)
	var center := Vector2(size * 0.5, size * 0.52)
	var radius := size * (0.42 if champion else 0.36)
	for y in range(size):
		for x in range(size):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= radius:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * (1.0 - distance / radius * 0.35)))
	return ImageTexture.create_from_image(image)
