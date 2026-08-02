extends Node2D

## VM02-C4 — deterministic reactive combat target.
## Tehkné Solutions

signal hit_received(damage: float, remaining_health: float)
signal reaction_phase_changed(phase: String)

@export var max_health := 100.0
@export var hitstun_seconds := 0.18
@export var recovery_seconds := 0.16
@export var knockback_distance := 26.0

var health := 100.0
var hit_count := 0
var last_damage := 0.0
var reaction_phase := "idle"
var reaction_count := 0
var knockback_count := 0
var recovery_count := 0
var _phase_elapsed := 0.0
var _reaction_origin_x := 0.0
var _knockback_target_x := 0.0

func _ready() -> void:
	health = max_health
	queue_redraw()

func _physics_process(delta: float) -> void:
	if reaction_phase == "idle":
		return
	_phase_elapsed += delta
	if reaction_phase == "hitstun":
		var t: float = clampf(_phase_elapsed / maxf(hitstun_seconds, 0.001), 0.0, 1.0)
		global_position.x = lerpf(_reaction_origin_x, _knockback_target_x, t)
		if t >= 1.0:
			knockback_count += 1
			_set_reaction_phase("recovery")
	elif reaction_phase == "recovery" and _phase_elapsed >= recovery_seconds:
		recovery_count += 1
		_set_reaction_phase("idle")

func receive_combat_hit(damage: float) -> void:
	if damage <= 0.0:
		return
	hit_count += 1
	last_damage = damage
	health = maxf(0.0, health - damage)
	reaction_count += 1
	_reaction_origin_x = global_position.x
	_knockback_target_x = _reaction_origin_x + knockback_distance
	_set_reaction_phase("hitstun")
	hit_received.emit(damage, health)
	queue_redraw()

func _set_reaction_phase(next_phase: String) -> void:
	reaction_phase = next_phase
	_phase_elapsed = 0.0
	reaction_phase_changed.emit(reaction_phase)
	print("VM02_C4_REACTION_PHASE=%s" % reaction_phase)
	queue_redraw()

func _draw() -> void:
	var body_color := Color(0.46, 0.50, 0.58, 1.0)
	if reaction_phase == "hitstun": body_color = Color(0.90, 0.48, 0.22, 1.0)
	elif reaction_phase == "recovery": body_color = Color(0.62, 0.54, 0.36, 1.0)
	draw_rect(Rect2(-22, -72, 44, 72), body_color)
	draw_circle(Vector2(0, -86), 16.0, body_color.lightened(0.08))
	draw_rect(Rect2(-34, -112, 68, 6), Color(0.08, 0.09, 0.11, 0.95))
	var ratio := health / maxf(1.0, max_health)
	draw_rect(Rect2(-34, -112, 68 * ratio, 6), Color(0.88, 0.24, 0.22, 0.95))
