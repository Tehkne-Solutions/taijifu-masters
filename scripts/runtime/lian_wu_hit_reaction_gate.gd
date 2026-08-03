extends Node2D

## VM02-C4 — hit reaction + hitstun + knockback + recovery gate.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c4/lian-wu-hit-reaction-1920x1080.png"
const WATCHDOG_SECONDS := 5.0

@onready var player: Node = $Player
@onready var attack_area: Area2D = $Player/AttackArea
@onready var dummy: Node = $Dummy
@onready var phase_label: Label = $CanvasLayer/HUD/Phase
@onready var reaction_label: Label = $CanvasLayer/HUD/Reaction
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics

var _elapsed := 0.0
var _attack_requested := false
var _hit_registered := false
var _attack_completed := false
var _reaction_phases: Array[String] = []
var _dummy_start_x := 0.0
var _capture := false
var _finished := false

func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	_dummy_start_x = float(dummy.global_position.x)
	player.set_test_input(0.0, false, false)
	player.body_hook_completed.connect(_on_attack_completed)
	dummy.reaction_phase_changed.connect(_on_reaction_phase_changed)
	print("VM02_C4_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	if _finished: return
	_elapsed += delta
	if _elapsed >= WATCHDOG_SECONDS:
		_watchdog_abort()
		return
	if not _attack_requested and _elapsed >= 0.55 and player.attack_phase == "idle":
		_attack_requested = true
		player.set_test_attack_edge(true)
		print("VM02_C4_ATTACK_REQUEST=1")
	if player.attack_phase == "active" and not _hit_registered:
		for area in attack_area.get_overlapping_areas():
			var target := area.get_parent()
			if target != null and target.has_method("receive_combat_hit"):
				_hit_registered = true
				var technique = TechniqueCatalog.get_technique(&"ji_body_hook")
				target.receive_combat_hit(float(technique.damage))
				print("VM02_C4_HIT_CONFIRM=PASS damage=%.2f" % float(technique.damage))
				break
	phase_label.text = "ATTACK: %s · F%02d" % [String(player.attack_phase).to_upper(), int(player.attack_keypose) + 1]
	reaction_label.text = "TARGET: %s" % String(dummy.reaction_phase).to_upper()
	metric_label.text = "hits=%d  hp=%.1f  knockback=%.1f  reactions=%d recoveries=%d" % [int(dummy.hit_count), float(dummy.health), float(dummy.global_position.x) - _dummy_start_x, int(dummy.reaction_count), int(dummy.recovery_count)]
	if _attack_completed and dummy.reaction_phase == "idle" and _elapsed > 1.15:
		_finish_gate()

func _on_attack_completed() -> void:
	_attack_completed = true
	print("VM02_C4_ATTACK_COMPLETE=PASS")

func _on_reaction_phase_changed(phase: String) -> void:
	if phase not in _reaction_phases: _reaction_phases.append(phase)

func _watchdog_abort() -> void:
	_finished = true
	print("VM02_C4_WATCHDOG=BLOCKED elapsed=%.2f attack=%s attack_completed=%s hit=%s reaction=%s hits=%d reactions=%d knockbacks=%d recoveries=%d dummy_x=%.2f" % [
		_elapsed, String(player.attack_phase), str(_attack_completed), str(_hit_registered), String(dummy.reaction_phase), int(dummy.hit_count), int(dummy.reaction_count), int(dummy.knockback_count), int(dummy.recovery_count), float(dummy.global_position.x)
	])
	push_error("C4 runtime watchdog expired")
	get_tree().quit(9)

func _finish_gate() -> void:
	_finished = true
	var failures: Array[String] = []
	var knockback: float = float(dummy.global_position.x) - _dummy_start_x
	if not _hit_registered: failures.append("attack never hit target")
	if int(dummy.hit_count) != 1: failures.append("expected one target hit")
	if int(dummy.reaction_count) != 1: failures.append("expected one reaction")
	if "hitstun" not in _reaction_phases: failures.append("missing hitstun")
	if "recovery" not in _reaction_phases: failures.append("missing recovery")
	if "idle" not in _reaction_phases: failures.append("missing idle handoff")
	if int(dummy.knockback_count) != 1 or knockback < 20.0: failures.append("knockback contract failed")
	if int(dummy.recovery_count) != 1: failures.append("recovery count failed")
	if dummy.reaction_phase != "idle": failures.append("target did not return idle")
	print("VM02_C4_HIT_REACTION=%s" % ("PASS" if int(dummy.reaction_count) == 1 else "BLOCKED"))
	print("VM02_C4_HITSTUN=%s" % ("PASS" if "hitstun" in _reaction_phases else "BLOCKED"))
	print("VM02_C4_KNOCKBACK=%s distance=%.2f" % [("PASS" if knockback >= 20.0 else "BLOCKED"), knockback])
	print("VM02_C4_RECOVERY=%s" % ("PASS" if int(dummy.recovery_count) == 1 else "BLOCKED"))
	print("VM02_C4_RETURN_IDLE=%s" % ("PASS" if dummy.reaction_phase == "idle" else "BLOCKED"))
	print("VM02_C4_RUNTIME=%s" % ("PASS" if failures.is_empty() else "BLOCKED"))
	for failure in failures: push_error(failure)
	if not failures.is_empty():
		if _capture: get_tree().quit(3)
		return
	if _capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c4"))
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C4_CAPTURE_NORMALIZED=PASS")
	var err := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("failed C4 capture")
		get_tree().quit(4)
		return
	print("VM02_C4_CAPTURE=PASS")
	print("VM02_C4_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
