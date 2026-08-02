extends Node2D

## VM02-C1 — deterministic combat foundation gate.
## Reuses TechniqueCatalog timings and validates separated hitbox/hurtbox behavior.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c1/lian-wu-combat-foundation-1920x1080.png"
const TECHNIQUE_ID := &"ji_body_hook"

@onready var player: Node = $Player
@onready var attack_area: Area2D = $Player/AttackArea
@onready var attack_shape: CollisionShape2D = $Player/AttackArea/CollisionShape2D
@onready var dummy: Node = $Dummy
@onready var phase_label: Label = $CanvasLayer/HUD/Phase
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics

var _technique
var _phase := "idle"
var _phase_timer := 0.0
var _elapsed := 0.0
var _attack_started := false
var _active_observed := false
var _recovery_observed := false
var _hit_registered := false
var _hitbox_enabled_outside_active := false
var _initial_health := 0.0
var _capture := false
var _finished := false

func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	_technique = TechniqueCatalog.get_technique(TECHNIQUE_ID)
	_initial_health = float(dummy.health)
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_shape.disabled = true
	player.set_test_input(0.0, false, false)
	dummy.hit_received.connect(_on_dummy_hit)
	print("VM02_C1_TECHNIQUE=%s" % String(TECHNIQUE_ID))
	print("VM02_C1_STARTUP_SECONDS=%.4f" % float(_technique.startup_seconds()))
	print("VM02_C1_ACTIVE_SECONDS=%.4f" % float(_technique.active_seconds()))
	print("VM02_C1_RECOVERY_SECONDS=%.4f" % float(_technique.recovery_seconds()))

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_phase_timer = maxf(0.0, _phase_timer - delta)

	if not _attack_started and _elapsed >= 0.65:
		_begin_attack()

	if _phase == "startup" and _phase_timer <= 0.0:
		_enter_active()
	elif _phase == "active":
		_active_observed = true
		_probe_active_overlaps()
		if _phase_timer <= 0.0:
			_enter_recovery()
	elif _phase == "recovery" and _phase_timer <= 0.0:
		_end_attack()

	if _phase != "active" and not attack_shape.disabled:
		_hitbox_enabled_outside_active = true

	phase_label.text = "PHASE: %s" % _phase.to_upper()
	metric_label.text = "hits=%d  dummy_hp=%.1f  hitbox=%s" % [int(dummy.hit_count), float(dummy.health), "ON" if not attack_shape.disabled else "OFF"]

	if _phase == "idle" and _attack_started and _elapsed >= 1.25:
		_finish_gate()

func _begin_attack() -> void:
	_attack_started = true
	_phase = "startup"
	_phase_timer = float(_technique.startup_seconds())
	_configure_hitbox()
	attack_shape.set_deferred("disabled", true)
	print("VM02_C1_PHASE=startup")

func _enter_active() -> void:
	_phase = "active"
	_phase_timer = float(_technique.active_seconds())
	_active_observed = true
	attack_shape.set_deferred("disabled", false)
	print("VM02_C1_PHASE=active")
	call_deferred("_probe_active_overlaps")

func _enter_recovery() -> void:
	_phase = "recovery"
	_phase_timer = float(_technique.recovery_seconds())
	_recovery_observed = true
	attack_shape.set_deferred("disabled", true)
	print("VM02_C1_PHASE=recovery")

func _end_attack() -> void:
	_phase = "idle"
	attack_shape.set_deferred("disabled", true)
	print("VM02_C1_PHASE=idle")

func _configure_hitbox() -> void:
	var rectangle := attack_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = _technique.hitbox_size
	attack_area.position = Vector2(_technique.hitbox_offset.x, _technique.hitbox_offset.y)

func _probe_active_overlaps() -> void:
	if _phase != "active" or _hit_registered:
		return
	for area in attack_area.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("receive_combat_hit"):
			_register_hit(target)
			return

func _register_hit(target: Node) -> void:
	if _phase != "active" or _hit_registered:
		return
	_hit_registered = true
	var damage := float(_technique.damage)
	target.receive_combat_hit(damage)
	print("VM02_C1_HIT_CONFIRM=PASS damage=%.2f" % damage)

func _on_dummy_hit(_damage: float, _remaining_health: float) -> void:
	queue_redraw()

func _finish_gate() -> void:
	_finished = true
	var failures: Array[String] = []
	var health_delta: float = _initial_health - float(dummy.health)
	if not _attack_started: failures.append("attack never started")
	if not _active_observed: failures.append("active phase not observed")
	if not _recovery_observed: failures.append("recovery phase not observed")
	if not _hit_registered: failures.append("no hit registered")
	if int(dummy.hit_count) != 1: failures.append("expected exactly one hit, got %d" % int(dummy.hit_count))
	if health_delta <= 0.0: failures.append("dummy health did not decrease")
	if _hitbox_enabled_outside_active: failures.append("hitbox enabled outside active phase")
	if _phase != "idle": failures.append("attack did not return to idle")

	print("VM02_C1_COMBAT_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_C1_ATTACK_PHASES=%s" % ("PASS" if _active_observed and _recovery_observed else "BLOCKED"))
	print("VM02_C1_HITBOX_WINDOW=%s" % ("PASS" if not _hitbox_enabled_outside_active else "BLOCKED"))
	print("VM02_C1_SINGLE_HIT=%s" % ("PASS" if int(dummy.hit_count) == 1 else "BLOCKED"))
	print("VM02_C1_DAMAGE_APPLIED=%.2f" % health_delta)
	print("VM02_C1_RETURN_IDLE=%s" % ("PASS" if _phase == "idle" else "BLOCKED"))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		if _capture: get_tree().quit(3)
		return
	if _capture:
		call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c1"))
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C1_CAPTURE_NORMALIZED=PASS")
	var err := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("failed to save C1 combat capture")
		get_tree().quit(4)
		return
	print("VM02_C1_CAPTURE=PASS")
	print("VM02_C1_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
