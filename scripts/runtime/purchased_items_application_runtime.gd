extends Node

signal cosmetics_applied(items: Array[String])
signal battle_stat_recorded(winner_player: int)
signal training_session_recorded(focus_id: String)

const BANNER_COLORS := {
	"tai_banner": Color(0.28, 0.72, 1.0, 0.94),
	"ji_banner": Color(0.95, 0.48, 0.22, 0.94),
	"fu_banner": Color(0.62, 0.42, 1.0, 0.94)
}

var _connected_fighters: Dictionary = {}
var _fighter_cosmetics: Dictionary = {}
var _last_training_completion := ""
var _scan_timer := 0.0
var _profile_frame: Panel
var _active_items: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var training := get_node_or_null("/root/CombatDifficultyTrainingRuntime")
	if training != null and training.has_signal("training_objective_completed"):
		training.training_objective_completed.connect(_on_training_completed)
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_signal("shop_purchase_completed"):
		profile.shop_purchase_completed.connect(_on_purchase_completed)
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.25
	_refresh_active_items()
	_discover_and_connect_fighters()
	_apply_profile_frame()

func _refresh_active_items() -> void:
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile == null or not profile.has_method("profile_snapshot"):
		return
	var snapshot: Dictionary = profile.profile_snapshot()
	_active_items.clear()
	for item in Array(snapshot.get("owned_items", [])):
		_active_items.append(String(item))
	if "extra_preset" in _active_items:
		profile.set_meta("extra_preset_slots", 1)

func _discover_and_connect_fighters() -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if not fighter is FighterController:
			continue
		var key := str(fighter.get_instance_id())
		if not _connected_fighters.has(key):
			_connected_fighters[key] = fighter
			fighter.defeated.connect(_on_fighter_defeated.bind(fighter))
		_apply_fighter_cosmetics(fighter)

func _apply_fighter_cosmetics(fighter: FighterController) -> void:
	var key := str(fighter.get_instance_id())
	if _fighter_cosmetics.has(key):
		return
	var applied: Array[String] = []
	for item_id in BANNER_COLORS:
		if item_id in _active_items:
			var banner := Polygon2D.new()
			banner.name = "PurchasedBanner_%s" % item_id
			banner.polygon = PackedVector2Array([Vector2(-18,-92),Vector2(18,-92),Vector2(13,-32),Vector2(0,-18),Vector2(-13,-32)])
			banner.color = BANNER_COLORS[item_id]
			banner.z_index = -1
			fighter.add_child(banner)
			applied.append(item_id)
	if "training_aura" in _active_items:
		var aura := PointLight2D.new()
		aura.name = "TrainingAura"
		aura.energy = 0.65
		aura.texture_scale = 1.3
		aura.color = Color(0.65,0.9,1.0,0.75)
		fighter.add_child(aura)
		applied.append("training_aura")
	_fighter_cosmetics[key] = true
	if not applied.is_empty():
		cosmetics_applied.emit(applied)

func _apply_profile_frame() -> void:
	if "master_frame" not in _active_items:
		if is_instance_valid(_profile_frame):
			_profile_frame.queue_free()
			_profile_frame = null
		return
	if is_instance_valid(_profile_frame):
		return
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile == null:
		return
	var layer: CanvasLayer = profile.get("_layer")
	if not is_instance_valid(layer):
		return
	_profile_frame = Panel.new()
	_profile_frame.name = "MasterProfileFrame"
	_profile_frame.position = Vector2(125,18)
	_profile_frame.size = Vector2(1030,684)
	_profile_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_frame.add_theme_stylebox_override("panel", _frame_style())
	layer.add_child(_profile_frame)
	layer.move_child(_profile_frame, 0)

func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	style.border_color = Color(0.92,0.72,0.22,0.95)
	style.set_border_width_all(5)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style

func _on_fighter_defeated(_defeated: FighterController, bound_fighter: FighterController) -> void:
	var winner := 2 if int(bound_fighter.player_index) == 1 else 1
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_method("record_battle_result"):
		profile.record_battle_result(winner == 1)
	battle_stat_recorded.emit(winner)

func _on_training_completed(focus_id: String) -> void:
	if focus_id == _last_training_completion:
		return
	_last_training_completion = focus_id
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_method("record_training_session"):
		profile.record_training_session()
	training_session_recorded.emit(focus_id)
	call_deferred("_clear_training_guard")

func _clear_training_guard() -> void:
	await get_tree().process_frame
	_last_training_completion = ""

func _on_purchase_completed(_item_id: String, _remaining_tokens: int) -> void:
	_fighter_cosmetics.clear()
	_refresh_active_items()

func active_items() -> Array[String]:
	return _active_items.duplicate()

func extra_preset_slots() -> int:
	return 1 if "extra_preset" in _active_items else 0
