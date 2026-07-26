class_name TemporaryLoot
extends Area2D

@export_enum("weapon", "technique") var loot_type: String = "weapon"
@export var item_id: StringName = &""
@export var source_player_index: int = 0
@export var lifetime: float = 14.0

var _source_lock_timer := 0.75
var _pulse := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	add_child(collision)

	body_entered.connect(_on_body_entered)
	queue_redraw()

func configure(type_id: String, content_id: StringName, source_index: int) -> void:
	loot_type = type_id
	item_id = content_id
	source_player_index = source_index

func _process(delta: float) -> void:
	lifetime -= delta
	_source_lock_timer = maxf(0.0, _source_lock_timer - delta)
	_pulse += delta
	if lifetime <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is not FighterController:
		return

	var fighter := body as FighterController
	if fighter.player_index == source_player_index and _source_lock_timer > 0.0:
		return

	var collected := false
	match loot_type:
		"weapon":
			collected = fighter.collect_temporary_weapon(item_id)
		"technique":
			collected = fighter.collect_technique_echo(item_id)

	if collected:
		queue_free()

func _draw() -> void:
	var radius := 11.0 + sin(_pulse * 5.0) * 2.0
	var color := Color(0.95, 0.72, 0.22, 0.92)
	if loot_type == "technique":
		color = Color(0.63, 0.42, 1.0, 0.92)

	draw_circle(Vector2.ZERO, radius + 7.0, Color(color, 0.18))
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, color.lightened(0.22), 2.0)

	if loot_type == "weapon":
		draw_line(Vector2(-7, 6), Vector2(8, -7), Color(0.08, 0.09, 0.12), 4.0)
	else:
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)]),
			Color(0.08, 0.09, 0.12)
		)
