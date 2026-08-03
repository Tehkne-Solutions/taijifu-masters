class_name OpponentAIFoundation
extends Node2D

## VM02-C8 — deterministic opponent AI foundation.
## Tehkné Solutions

signal ai_state_changed(state: String)
signal ai_attack_started(technique_id: StringName)
signal ai_attack_active
signal ai_attack_completed

const TECHNIQUE_ID := &"ji_shove"

@export var approach_speed := 92.0
@export var preferred_distance := 72.0
@export var disengage_distance := 46.0
@export var max_health := 100.0
@export var hitstun_seconds := 0.16

var target: Node2D
var health := 100.0
var ai_state := "idle"
var attack_phase := "idle"
var attack_elapsed := 0.0
var attack_count := 0
var hit_count := 0
var reaction_count := 0
var facing := -1.0
var _technique
var _hitstun_elapsed := 0.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

func _ready() -> void:
	health = max_health
	_technique = TechniqueCatalog.get_technique(TECHNIQUE_ID)
	attack_shape.disabled = true
	queue_redraw()

func set_target(value: Node2D) -> void:
	target = value

func _physics_process(delta: float) -> void:
	if ai_state == "hitstun":
		_hitstun_elapsed += delta
		if _hitstun_elapsed >= hitstun_seconds:
			_set_state("idle")
		return
	if attack_phase != "idle":
		_advance_attack(delta)
		return
	if target == null:
		_set_state("idle")
		return
	var dx: float = target.global_position.x - global_position.x
	facing = 1.0 if dx >= 0.0 else -1.0
	var distance := absf(dx)
	if distance > preferred_distance:
		_set_state("approach")
		global_position.x += signf(dx) * minf(approach_speed * delta, distance - preferred_distance)
	elif distance < disengage_distance:
		_set_state("retreat")
		global_position.x -= signf(dx) * approach_speed * 0.55 * delta
	else:
		_set_state("hold")
		_begin_attack()
	queue_redraw()

func _begin_attack() -> void:
	if _technique == null or attack_phase != "idle": return
	attack_count += 1
	attack_phase = "startup"
	attack_elapsed = 0.0
	_set_state("attack")
	_configure_hitbox()
	_set_hitbox(false)
	ai_attack_started.emit(TECHNIQUE_ID)
	print("VM02_C8_AI_ATTACK_START=%d technique=%s" % [attack_count, String(TECHNIQUE_ID)])

func _advance_attack(delta: float) -> void:
	attack_elapsed += delta
	if attack_phase == "startup" and attack_elapsed >= float(_technique.startup_seconds()):
		attack_phase = "active"
		attack_elapsed = 0.0
		_set_hitbox(true)
		ai_attack_active.emit()
		print("VM02_C8_AI_ATTACK_PHASE=active")
	elif attack_phase == "active" and attack_elapsed >= float(_technique.active_seconds()):
		attack_phase = "recovery"
		attack_elapsed = 0.0
		_set_hitbox(false)
		print("VM02_C8_AI_ATTACK_PHASE=recovery")
	elif attack_phase == "recovery" and attack_elapsed >= float(_technique.recovery_seconds()):
		attack_phase = "idle"
		attack_elapsed = 0.0
		_set_hitbox(false)
		_set_state("idle")
		ai_attack_completed.emit()
		print("VM02_C8_AI_ATTACK_COMPLETE=%d" % attack_count)

func receive_combat_hit(damage: float) -> void:
	if damage <= 0.0: return
	hit_count += 1
	reaction_count += 1
	health = maxf(0.0, health - damage)
	attack_phase = "idle"
	attack_elapsed = 0.0
	_set_hitbox(false)
	_hitstun_elapsed = 0.0
	_set_state("hitstun")
	global_position.x += -facing * 12.0
	print("VM02_C8_AI_RECEIVE_HIT=PASS damage=%.2f hp=%.2f" % [damage, health])
	queue_redraw()

func _set_state(next_state: String) -> void:
	if ai_state == next_state: return
	ai_state = next_state
	ai_state_changed.emit(ai_state)
	print("VM02_C8_AI_STATE=%s" % ai_state)
	queue_redraw()

func _set_hitbox(enabled: bool) -> void:
	attack_shape.set_deferred("disabled", not enabled)

func _configure_hitbox() -> void:
	var rect := attack_shape.shape as RectangleShape2D
	if rect != null: rect.size = _technique.hitbox_size
	attack_area.position = Vector2(_technique.hitbox_offset.x * facing, _technique.hitbox_offset.y)

func _draw() -> void:
	var c := Color(0.55,0.60,0.68,1.0)
	if ai_state == "approach": c = Color(0.32,0.55,0.78,1.0)
	elif ai_state == "attack": c = Color(0.82,0.34,0.25,1.0)
	elif ai_state == "hitstun": c = Color(0.95,0.68,0.24,1.0)
	draw_rect(Rect2(-22,-72,44,72),c)
	draw_circle(Vector2(0,-88),16.0,c.lightened(0.08))
	draw_rect(Rect2(-34,-116,68,6),Color(0.08,0.09,0.11,0.95))
	draw_rect(Rect2(-34,-116,68.0*(health/maxf(1.0,max_health)),6),Color(0.88,0.24,0.22,0.95))
