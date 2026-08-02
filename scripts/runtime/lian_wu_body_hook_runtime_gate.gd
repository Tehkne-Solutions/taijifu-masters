extends Node2D

## VM02-C3 — deterministic body-hook visual + hitbox + timing integration gate.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c3/lian-wu-body-hook-runtime-1920x1080.png"
const EXPECTED_ATTACKS := 2

@onready var player: Node = $Player
@onready var attack_area: Area2D = $Player/AttackArea
@onready var attack_shape: CollisionShape2D = $Player/AttackArea/CollisionShape2D
@onready var dummy: Node = $Dummy
@onready var phase_label: Label = $CanvasLayer/HUD/Phase
@onready var pose_label: Label = $CanvasLayer/HUD/Pose
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics

var _elapsed := 0.0
var _next_attack_at := 0.55
var _attack_requests := 0
var _completed_attacks := 0
var _hit_registered_this_attack := false
var _hits_per_attack: Array[int] = []
var _keyposes_seen: Array[int] = []
var _phases_seen: Array[String] = []
var _active_pose_hit_confirmed := false
var _hitbox_outside_active := false
var _hitbox_audit_skip_frames := 0
var _attack_start_x := 0.0
var _max_attack_drift := 0.0
var _initial_health := 0.0
var _capture := false
var _finished := false

func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	_initial_health = float(dummy.health)
	player.set_test_input(0.0, false, false)
	player.attack_phase_changed.connect(_on_attack_phase_changed)
	player.attack_hit_window_changed.connect(_on_hit_window_changed)
	player.body_hook_completed.connect(_on_body_hook_completed)
	dummy.hit_received.connect(_on_dummy_hit)
	print("VM02_C3_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta

	if _attack_requests < EXPECTED_ATTACKS and _elapsed >= _next_attack_at and player.attack_phase == "idle":
		_request_attack()

	if player.attack_phase != "idle":
		var pose_number: int = int(player.attack_keypose) + 1
		if pose_number not in _keyposes_seen:
			_keyposes_seen.append(pose_number)
			print("VM02_C3_KEYPOSE=F%02d" % pose_number)
		_max_attack_drift = maxf(_max_attack_drift, absf(float(player.global_position.x) - _attack_start_x))
		if player.attack_phase == "active":
			_probe_active_overlap()

	if _hitbox_audit_skip_frames > 0:
		_hitbox_audit_skip_frames -= 1
	elif player.attack_phase != "active" and not attack_shape.disabled:
		_hitbox_outside_active = true

	phase_label.text = "PHASE: %s" % String(player.attack_phase).to_upper()
	pose_label.text = "KEYPOSE: F%02d / 06" % (int(player.attack_keypose) + 1)
	metric_label.text = "attacks=%d/%d  hits=%d  dummy_hp=%.1f  drift=%.2f  hitbox=%s" % [
		_completed_attacks, EXPECTED_ATTACKS, int(dummy.hit_count), float(dummy.health), _max_attack_drift,
		"ON" if not attack_shape.disabled else "OFF"
	]

	if _completed_attacks >= EXPECTED_ATTACKS and player.attack_phase == "idle" and _elapsed >= _next_attack_at:
		_finish_gate()

func _request_attack() -> void:
	_attack_requests += 1
	_hit_registered_this_attack = false
	_hits_per_attack.append(0)
	_attack_start_x = float(player.global_position.x)
	player.set_test_attack_edge(true)
	print("VM02_C3_ATTACK_REQUEST=%d" % _attack_requests)

func _on_attack_phase_changed(phase: String) -> void:
	if phase not in _phases_seen:
		_phases_seen.append(phase)
	if phase == "active":
		if int(player.attack_keypose) == 3:
			_active_pose_hit_confirmed = true
	elif phase == "idle" and _attack_requests < EXPECTED_ATTACKS:
		_next_attack_at = _elapsed + 0.30

func _on_hit_window_changed(enabled: bool) -> void:
	_hitbox_audit_skip_frames = 1
	print("VM02_C3_HITBOX_WINDOW=%s" % ("ACTIVE" if enabled else "OFF"))

func _probe_active_overlap() -> void:
	if player.attack_phase != "active" or _hit_registered_this_attack:
		return
	for area in attack_area.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("receive_combat_hit"):
			_hit_registered_this_attack = true
			_hits_per_attack[_hits_per_attack.size() - 1] += 1
			var technique = TechniqueCatalog.get_technique(&"ji_body_hook")
			target.receive_combat_hit(float(technique.damage))
			print("VM02_C3_HIT_CONFIRM=PASS attack=%d keypose=F%02d damage=%.2f" % [
				_attack_requests, int(player.attack_keypose) + 1, float(technique.damage)
			])
			return

func _on_body_hook_completed() -> void:
	_completed_attacks += 1
	_next_attack_at = _elapsed + 0.30
	print("VM02_C3_ATTACK_COMPLETE=%d" % _completed_attacks)

func _on_dummy_hit(_damage: float, _remaining_health: float) -> void:
	queue_redraw()

func _finish_gate() -> void:
	_finished = true
	var failures: Array[String] = []
	var health_delta: float = _initial_health - float(dummy.health)
	var expected_damage: float = float(TechniqueCatalog.get_technique(&"ji_body_hook").damage) * EXPECTED_ATTACKS
	var ordered_poses := [1, 2, 3, 4, 5, 6]
	var required_phases := ["startup", "active", "recovery", "idle"]

	if _attack_requests != EXPECTED_ATTACKS: failures.append("expected 2 attack requests")
	if _completed_attacks != EXPECTED_ATTACKS: failures.append("expected 2 completed attacks")
	if _keyposes_seen != ordered_poses: failures.append("keypose sequence incomplete: %s" % str(_keyposes_seen))
	for phase in required_phases:
		if phase not in _phases_seen: failures.append("missing phase %s" % phase)
	if not _active_pose_hit_confirmed: failures.append("active phase was not bound to F04")
	if _hitbox_outside_active: failures.append("hitbox enabled outside active phase")
	if _hits_per_attack.size() != EXPECTED_ATTACKS: failures.append("missing hit accounting")
	else:
		for count in _hits_per_attack:
			if count != 1: failures.append("expected exactly one hit per attack")
	if int(dummy.hit_count) != EXPECTED_ATTACKS: failures.append("dummy hit count mismatch")
	if absf(health_delta - expected_damage) > 0.01: failures.append("damage mismatch %.2f != %.2f" % [health_delta, expected_damage])
	if _max_attack_drift > 3.0: failures.append("movement lock drift too high %.2f" % _max_attack_drift)
	if player.attack_phase != "idle": failures.append("did not return to idle")
	if not attack_shape.disabled: failures.append("hitbox still enabled after recovery")

	print("VM02_C3_COMBAT_VISUAL_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	print("VM02_C3_KEYPOSE_SEQUENCE=%s" % ("PASS" if _keyposes_seen == ordered_poses else "BLOCKED"))
	print("VM02_C3_PHASE_TIMING=%s" % ("PASS" if required_phases.all(func(p): return p in _phases_seen) else "BLOCKED"))
	print("VM02_C3_ACTIVE_F04_BINDING=%s" % ("PASS" if _active_pose_hit_confirmed else "BLOCKED"))
	print("VM02_C3_HITBOX_WINDOW=%s" % ("PASS" if not _hitbox_outside_active else "BLOCKED"))
	print("VM02_C3_SINGLE_HIT_PER_ATTACK=%s" % ("PASS" if int(dummy.hit_count) == EXPECTED_ATTACKS else "BLOCKED"))
	print("VM02_C3_REATTACK=%s" % ("PASS" if _completed_attacks == EXPECTED_ATTACKS else "BLOCKED"))
	print("VM02_C3_MOVEMENT_LOCK_DRIFT=%.2f" % _max_attack_drift)
	print("VM02_C3_DAMAGE_APPLIED=%.2f" % health_delta)
	print("VM02_C3_RETURN_IDLE=%s" % ("PASS" if player.attack_phase == "idle" else "BLOCKED"))
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c3"))
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C3_CAPTURE_NORMALIZED=PASS")
	var err: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("failed to save C3 capture")
		get_tree().quit(4)
		return
	print("VM02_C3_CAPTURE=PASS")
	print("VM02_C3_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
