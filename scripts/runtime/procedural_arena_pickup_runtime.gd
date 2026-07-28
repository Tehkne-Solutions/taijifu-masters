extends Node

const SPAWN_MIN := 6.0
const SPAWN_MAX := 10.0
const PICKUP_LIFETIME := 16.0
const COLLECT_RADIUS := 58.0
const MAX_ACTIVE := 3

const RARITIES := {
	"common": {"weight": 58.0, "duration": 7.0, "power": 1.0, "color": Color(0.58, 0.82, 1.0)},
	"rare": {"weight": 28.0, "duration": 10.0, "power": 1.35, "color": Color(0.55, 0.38, 1.0)},
	"epic": {"weight": 11.0, "duration": 13.0, "power": 1.75, "color": Color(1.0, 0.42, 0.8)},
	"legendary": {"weight": 3.0, "duration": 16.0, "power": 2.25, "color": Color(1.0, 0.76, 0.22)}
}

const ITEMS := {
	"vital_orb": {"type": "instant", "label": "Orbe Vital", "vfx": "water"},
	"focus_charm": {"type": "buff", "stat": "focus", "amount": 14.0, "label": "Talismã de Foco", "vfx": "loot_skill"},
	"iron_guard": {"type": "buff", "stat": "defense", "amount": 16.0, "label": "Guarda de Ferro", "vfx": "block"},
	"wind_step": {"type": "buff", "stat": "agility", "amount": 18.0, "label": "Passo do Vento", "vfx": "air"},
	"titan_force": {"type": "buff", "stat": "strength", "amount": 18.0, "label": "Força Titânica", "vfx": "earth"},
	"echo_scroll": {"type": "skill", "label": "Pergaminho de Eco", "vfx": "technique"}
}

var _fighters: Dictionary = {}
var _pickups: Array[Dictionary] = []
var _buffs: Array[Dictionary] = []
var _spawn_timer := 4.5
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	set_process(true)

func _process(delta: float) -> void:
	_discover_fighters()
	_update_pickups(delta)
	_update_buffs(delta)
	if _fighters.size() < 2:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _pickups.size() < MAX_ACTIVE:
		_spawn_random_pickup()
		_spawn_timer = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if node is FighterController:
			_fighters[int(node.player_index)] = node
	if _fighters.size() < 2:
		var found: Array[Node] = []
		_collect_fighters(get_tree().root, found)
		for node in found:
			var fighter := node as FighterController
			_fighters[int(fighter.player_index)] = fighter

func _collect_fighters(node: Node, found: Array[Node]) -> void:
	if node is FighterController:
		found.append(node)
	for child in node.get_children():
		_collect_fighters(child, found)

func _spawn_random_pickup() -> void:
	if get_tree().current_scene == null:
		return
	var rarity := _roll_rarity()
	var item_ids := ITEMS.keys()
	var item_id: String = String(item_ids[_rng.randi_range(0, item_ids.size() - 1)])
	var node := Node2D.new()
	node.name = "ArenaPickup_%s_%s" % [item_id, rarity]
	node.position = Vector2(_rng.randf_range(360.0, 2100.0), _rng.randf_range(360.0, 540.0))
	node.z_index = 70
	var sprite := Sprite2D.new()
	sprite.texture = _pickup_texture(RARITIES[rarity]["color"])
	node.add_child(sprite)
	var label := Label.new()
	label.position = Vector2(-70, -52)
	label.size = Vector2(140, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s • %s" % [String(ITEMS[item_id]["label"]).to_upper(), rarity.to_upper()]
	label.add_theme_font_size_override("font_size", 10)
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	_pickups.append({"node": node, "item_id": item_id, "rarity": rarity, "life": PICKUP_LIFETIME})
	if get_node_or_null("/root/Pack99CombatEventRuntime") != null:
		get_node("/root/Pack99CombatEventRuntime")._spawn_vfx(node.global_position, "", RARITIES[rarity]["color"], 0.28)

func _update_pickups(delta: float) -> void:
	for index in range(_pickups.size() - 1, -1, -1):
		var pickup: Dictionary = _pickups[index]
		var node: Node2D = pickup["node"]
		if not is_instance_valid(node):
			_pickups.remove_at(index)
			continue
		pickup["life"] = float(pickup["life"]) - delta
		node.rotation += delta * 0.8
		node.position.y += sin(Time.get_ticks_msec() * 0.004 + index) * 0.08
		var collector := _nearest_fighter(node.global_position)
		if collector != null and collector.global_position.distance_to(node.global_position) <= COLLECT_RADIUS:
			_collect_pickup(collector, pickup)
			_pickups.remove_at(index)
		elif float(pickup["life"]) <= 0.0:
			node.queue_free()
			_pickups.remove_at(index)

func _collect_pickup(fighter: FighterController, pickup: Dictionary) -> void:
	var item_id: String = pickup["item_id"]
	var rarity: String = pickup["rarity"]
	var spec: Dictionary = ITEMS[item_id]
	var rarity_spec: Dictionary = RARITIES[rarity]
	match String(spec["type"]):
		"instant":
			fighter.health = minf(fighter.build.max_health(), fighter.health + 18.0 * float(rarity_spec["power"]))
			fighter.stamina = minf(100.0, fighter.stamina + 24.0 * float(rarity_spec["power"]))
		"skill":
			fighter.borrowed_technique_id = fighter.build.technique_for("fu", 1)
			fighter.stamina = minf(100.0, fighter.stamina + 12.0)
		"buff":
			_apply_buff(fighter, String(spec["stat"]), float(spec["amount"]) * float(rarity_spec["power"]), float(rarity_spec["duration"]), item_id)
	var vfx_runtime := get_node_or_null("/root/Pack99CombatEventRuntime")
	if vfx_runtime != null:
		vfx_runtime._spawn_event(fighter, String(spec["vfx"]), Vector2(0, -70), 0.38)
	var node: Node2D = pickup["node"]
	if is_instance_valid(node):
		node.queue_free()

func _apply_buff(fighter: FighterController, stat: String, amount: float, duration: float, source_id: String) -> void:
	var original := float(fighter.build.get(stat))
	fighter.build.set(stat, clampf(original + amount, 1.0, 100.0))
	_buffs.append({"fighter": fighter, "stat": stat, "original": original, "remaining": duration, "source": source_id})
	fighter.combat_state_changed.emit(fighter)

func _update_buffs(delta: float) -> void:
	for index in range(_buffs.size() - 1, -1, -1):
		var buff: Dictionary = _buffs[index]
		var fighter: FighterController = buff["fighter"]
		if not is_instance_valid(fighter):
			_buffs.remove_at(index)
			continue
		buff["remaining"] = float(buff["remaining"]) - delta
		if float(buff["remaining"]) <= 0.0:
			fighter.build.set(String(buff["stat"]), float(buff["original"]))
			fighter.combat_state_changed.emit(fighter)
			_buffs.remove_at(index)

func _nearest_fighter(position: Vector2) -> FighterController:
	var nearest: FighterController
	var best := INF
	for fighter in _fighters.values():
		if not is_instance_valid(fighter):
			continue
		var distance := fighter.global_position.distance_to(position)
		if distance < best:
			best = distance
			nearest = fighter
	return nearest

func _roll_rarity() -> String:
	var roll := _rng.randf_range(0.0, 100.0)
	var cursor := 0.0
	for rarity in ["common", "rare", "epic", "legendary"]:
		cursor += float(RARITIES[rarity]["weight"])
		if roll <= cursor:
			return rarity
	return "common"

func _pickup_texture(color: Color) -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(48, 48)
	for y in range(96):
		for x in range(96):
			var distance := Vector2(x, y).distance_to(center)
			if distance < 34.0:
				var alpha := clampf(1.0 - distance / 34.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.35 + alpha * 0.65))
	return ImageTexture.create_from_image(image)

func active_pickup_count() -> int:
	return _pickups.size()

func active_buff_count() -> int:
	return _buffs.size()
