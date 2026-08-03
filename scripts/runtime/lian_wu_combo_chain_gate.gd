extends Node2D

## VM02-C5 — deterministic two-hit combo gate.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-c5/lian-wu-basic-combo-1920x1080.png"

@onready var player: Node = $Player
@onready var attack_area: Area2D = $Player/AttackArea
@onready var dummy: Node = $Dummy
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics

var elapsed := 0.0
var first_requested := false
var second_buffered := false
var hit_latch := false
var combo_done := false
var idle_between_hits := false
var seen_first_hit := false
var initial_health := 0.0
var capture := false
var completed_combo_hits := 0

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	initial_health = float(dummy.health)
	player.set_test_input(0.0,false,false)
	player.combo_completed.connect(_on_combo_completed)
	print("VM02_C5_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not first_requested and elapsed >= 0.5 and player.attack_phase == "idle":
		first_requested = true
		player.set_test_attack_edge(true)
		print("VM02_C5_ATTACK_REQUEST=1")
	if first_requested and not second_buffered and player.combo_buffer_open:
		second_buffered = true
		player.set_test_combo_edge(true)
		print("VM02_C5_ATTACK_REQUEST=2_BUFFERED")
	if player.attack_phase == "active" and not hit_latch:
		for area in attack_area.get_overlapping_areas():
			var target := area.get_parent()
			if target != null and target.has_method("receive_combat_hit"):
				hit_latch = true
				var technique = TechniqueCatalog.get_technique(&"ji_body_hook")
				target.receive_combat_hit(float(technique.damage))
				print("VM02_C5_HIT_CONFIRM=%d" % int(dummy.hit_count))
				seen_first_hit = true
				break
	elif player.attack_phase != "active":
		hit_latch = false
	if seen_first_hit and not combo_done and int(dummy.hit_count) < 2 and player.attack_phase == "idle" and player.combo_index == 0:
		idle_between_hits = true
	var combo_display: int = completed_combo_hits if combo_done else int(player.combo_index)
	metric_label.text = "combo=%d  hits=%d  hp=%.1f  buffered=%s  idle_gap=%s" % [combo_display,int(dummy.hit_count),float(dummy.health),str(second_buffered),str(idle_between_hits)]
	if combo_done and player.attack_phase == "idle": _finish()
	if elapsed > 5.0 and not combo_done:
		push_error("VM02_C5_WATCHDOG=BLOCKED")
		get_tree().quit(3)

func _on_combo_completed(hits: int) -> void:
	completed_combo_hits = hits
	combo_done = true
	print("VM02_C5_COMBO_SIGNAL=%d" % hits)

func _finish() -> void:
	set_physics_process(false)
	metric_label.text = "combo=%d  hits=%d  hp=%.1f  buffered=%s  idle_gap=%s" % [completed_combo_hits,int(dummy.hit_count),float(dummy.health),str(second_buffered),str(idle_between_hits)]
	var expected_damage := float(TechniqueCatalog.get_technique(&"ji_body_hook").damage) * 2.0
	var damage := initial_health - float(dummy.health)
	var ok := int(dummy.hit_count) == 2 and completed_combo_hits == 2 and absf(damage-expected_damage) < 0.01 and not idle_between_hits and second_buffered
	print("VM02_C5_TWO_HIT_CHAIN=%s" % ("PASS" if int(dummy.hit_count)==2 else "BLOCKED"))
	print("VM02_C5_BUFFER_WINDOW=%s" % ("PASS" if second_buffered else "BLOCKED"))
	print("VM02_C5_NO_IDLE_GAP=%s" % ("PASS" if not idle_between_hits else "BLOCKED"))
	print("VM02_C5_COMPLETED_COMBO_COUNT=%s hits=%d" % [("PASS" if completed_combo_hits == 2 else "BLOCKED"), completed_combo_hits])
	print("VM02_C5_DAMAGE_APPLIED=%.2f" % damage)
	print("VM02_C5_RUNTIME=%s" % ("PASS" if ok else "BLOCKED"))
	if not ok:
		if capture: get_tree().quit(3)
		return
	if capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c5"))
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x,OUTPUT_SIZE.y,Image.INTERPOLATE_LANCZOS)
		print("VM02_C5_CAPTURE_NORMALIZED=PASS")
	var err := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		get_tree().quit(4)
		return
	print("VM02_C5_CAPTURE=PASS")
	print("VM02_C5_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
