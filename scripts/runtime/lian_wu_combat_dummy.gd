extends Node2D

## Deterministic target dummy for VM02-C1.
## Tehkné Solutions

signal hit_received(damage: float, remaining_health: float)

@export var max_health := 100.0
var health := 100.0
var hit_count := 0
var last_damage := 0.0

func _ready() -> void:
	health = max_health
	queue_redraw()

func receive_combat_hit(damage: float) -> void:
	if damage <= 0.0:
		return
	hit_count += 1
	last_damage = damage
	health = maxf(0.0, health - damage)
	hit_received.emit(damage, health)
	queue_redraw()

func _draw() -> void:
	# Minimal deterministic combat target with explicit hurtbox silhouette.
	draw_rect(Rect2(-22, -72, 44, 72), Color(0.30, 0.34, 0.40, 1.0))
	draw_circle(Vector2(0, -86), 16.0, Color(0.38, 0.42, 0.48, 1.0))
	draw_rect(Rect2(-34, -112, 68, 6), Color(0.08, 0.09, 0.11, 0.95))
	var ratio := health / maxf(1.0, max_health)
	draw_rect(Rect2(-34, -112, 68 * ratio, 6), Color(0.88, 0.24, 0.22, 0.95))
