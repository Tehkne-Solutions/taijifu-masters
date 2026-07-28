extends Node

signal pickup_collected(fighter: FighterController, item_id: String, rarity: String, tags: Array[String])
signal buff_changed(fighter: FighterController, stat: String, total_bonus: float)

const SPAWN_MIN := 6.0
const SPAWN_MAX := 10.0
const PICKUP_LIFETIME := 16.0
const COLLECT_RADIUS := 58.0
const MAX_ACTIVE := 3

const RARITIES := {
	"common": {"weight": 54.0, "duration": 7.0, "power": 1.0, "color": Color(0.58, 0.82, 1.0)},
	"rare": {"weight": 28.0, "duration": 10.0, "power": 1.35, "color": Color(0.55, 0.38, 1.0)},
	"epic": {"weight": 12.0, "duration": 13.0, "power": 1.75, "color": Color(1.0, 0.42, 0.8)},
	"legendary": {"weight": 4.0, "duration": 16.0, "power": 2.25, "color": Color(1.0, 0.76, 0.22)},
	"cursed": {"weight": 2.0, "duration": 14.0, "power": 2.0, "color": Color(0.48, 0.12, 0.62)}
}

const ITEMS := {
	"vital_orb": {"type": "instant", "label": "Orbe Vital", "vfx": "water", "tags": ["vital", "water"]},
	"focus_charm": {"type": "buff", "stat": "focus", "amount": 14.0, "label": "Talismã de Foco", "vfx": "loot_skill", "tags": ["focus", "fu"]},
	"iron_guard": {"type": "buff", "stat": "defense", "amount": 16.0, "label": "Guarda de Ferro", "vfx": "block", "tags": ["defense", "earth"]},
	"wind_step": {"type": "buff", "stat": "agility", "amount": 18.0, "label": "Passo do Vento", "vfx": "air", "tags": ["agility", "air", "tai"]},
	"titan_force": {"type": "buff", "stat": "strength", "amount": 18.0, "label": "Força Titânica", "vfx": "earth", "tags": ["strength", "earth", "ji"]},
	"echo_scroll": {"type": "skill", "label": "Pergaminho de Eco", "vfx": "technique", "tags": ["skill", "fu"]},
	"blood_crown": {"type": "cursed", "label": "Coroa de Sangue", "vfx": "fire", "tags": ["cursed", "strength", "fire"], "positive_stat": "strength", "positive": 32.0, "negative_stat": "defense", "negative": -20.0},
	"void_feather": {"type": "cursed", "label": "Pluma do Vazio", "vfx": "air", "tags": ["cursed", "agility", "void"], "positive_stat": "agility", "positive": 34.0, "negative_stat": "resistance", "negative": -22.0},
	"oracle_mask": {"type": "cursed", "label": "Máscara do Oráculo", "vfx": "loot_skill", "tags": ["cursed", "focus", "fu"], "positive_stat": "focus", "positive": 36.0, "negative_stat": "strength", "negative": -18.0}
}

var _fighters: Dictionary = {}
var _pickups: Array[Dictionary] = []
var _buffs: Array[Dictionary] = []
var _base_stats: Dictionary = {}
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
	var item_ids := _eligible_items(rarity)
	var item_id: String = String(item_ids[_rng.randi_range(0, item_ids.size() - 1)])
	var node := Node2D.new()
	node.name = "ArenaPickup_%s_%s" % [item_id, rarity]
	node.position = Vector2(_rng.randf_range(360.0, 2100.0), _rng.randf_range(360.0, 540.0))
	node.z_index = 70
	var sprite := Sprite2D.new()
	sprite.texture = _pickup_texture(RARITIES[rarity]["color"])
	node.add_child(sprite)
	var label := Label.new()
	label.position = Vector2(-86, -52)
	label.size = Vector2(172, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s • %s" % [String(ITEMS[item_id]["label"]).to_upper(), rarity.to_upper()]
	label.add_theme_font_size_override("font_size", 10)
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	_pickups.append({"node": node, "item_id": item_id, "rarity": rarity, "life": PICKUP_LIFETIME})
	var vfx_runtime := get_node_or_null("/root/Pack99CombatEventRuntime")
	if vfx_runtime != null:
		vfx_runtime._spawn_vfx(node.global_position, "", RARITIES[rarity]["color"], 0.28)

func _eligible_items(rarity: String) -> Array:
	var result: Array = []
	for item_id in ITEMS:
		var is_cursed := String(ITEMS[item_id]["type"]) == "cursed"
		if (rarity == "cursed") == is_cursed:
			result.append(item_id)
	return result

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
		"cursed":
			_apply_buff(fighter, String(spec["positive_stat"]), float(spec["positive"]), float(rarity_spec["duration"]), item_id)
			_apply_buff(fighter, String(spec["negative_stat"]), float(spec["negative"]), float(rarity_spec["duration"]), item_id)
	var vfx_runtime := get_node_or_null("/root/Pack99CombatEventRuntime")
	if vfx_runtime != null:
		vfx_runtime._spawn_event(fighter, String(spec["vfx"]), Vector2(0, -70), 0.38)
	pickup_collected.emit(fighter, item_id, rarity, _string_array(spec.get("tags", [])))
	var node: Node2D = pickup["node"]
	if is_instance_valid(node):
		node.queue_free()

func _apply_buff(fighter: FighterController, stat: String, amount: float, duration: float, source_id: String) -> void:
	var key := "%d:%s" % [fighter.get_instance_id(), stat]
	if not _base_stats.has(key):
		_base_stats[key] = float(fighter.build.get(stat))
	_buffs.append({"fighter": fighter, "stat": stat, "amount": amount, "remaining": duration, "source": source_id, "key": key})
	_recalculate_stat(fighter, stat, key)

func _update_buffs(delta: float) -> void:
	var dirty: Dictionary = {}
	for index in range(_buffs.size() - 1, -1, -1):
		var buff: Dictionary = _buffs[index]
		var fighter: FighterController = buff["fighter"]
		if not is_instance_valid(fighter):
			_buffs.remove_at(index)
			continue
		buff["remaining"] = float(buff["remaining"]) - delta
		if float(buff["remaining"]) <= 0.0:
			dirty[String(buff["key"])] = {"fighter": fighter, "stat": String(buff["stat"])}
			_buffs.remove_at(index)
	for key in dirty:
		var entry: Dictionary = dirty[key]
		_recalculate_stat(entry["fighter"], entry["stat"], key)

func _recalculate_stat(fighter: FighterController, stat: String, key: String) -> void:
	if not is_instance_valid(fighter) or not _base_stats.has(key):
		return
	var total := 0.0
	for buff in _buffs:
		if String(buff["key"]) == key:
			total += float(buff["amount"])
	fighter.build.set(stat, clampf(float(_base_stats[key]) + total, 1.0, 100.0))
	fighter.combat_state_changed.emit(fighter)
	buff_changed.emit(fighter, stat, total)
	if is_zero_approx(total):
		_base_stats.erase(key)

func add_external_buff(fighter: FighterController, stat: String, amount: float, duration: float, source_id: String) -> void:
	_apply_buff(fighter, stat, amount, duration, source_id)

func active_sources_for(fighter: FighterController) -> Array[String]:
	var sources: Array[String] = []
	for buff in _buffs:
		if buff["fighter"] == fighter:
			var source := String(buff["source"])
			if not sources.has(source):
				sources.append(source)
	return sources

func _nearest_fighter(position: Vector2) -> FighterController:
	var nearest: FighterController
	var best := INF
	for fighter in _fighters.values():
		if not is_instance_valid(fighter):
			continue
		var typed_fighter := fighter as FighterController
		var distance: float = typed_fighter.global_position.distance_to(position)
		if distance < best:
			best = distance
			nearest = typed_fighter
	return nearest

func _roll_rarity() -> String:
	var roll := _rng.randf_range(0.0, 100.0)
	var cursor := 0.0
	for rarity in ["common", "rare", "epic", "legendary", "cursed"]:
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

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func active_pickup_count() -> int:
	return _pickups.size()

func active_buff_count() -> int:
	return _buffs.size()
