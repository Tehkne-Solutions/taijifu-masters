extends Node2D

## VM02-C7 — deterministic ji_body_hook -> ji_sweep combo gate.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-c7/lian-wu-body-hook-sweep-combo-1920x1080.png"

@onready var player: Node = $Player
@onready var attack_area: Area2D = $Player/AttackArea
@onready var dummy: Node = $Dummy
@onready var metric_label: Label = $CanvasLayer/HUD/Metrics
@onready var link_label: Label = $CanvasLayer/HUD/Link

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
var links: Array[StringName] = []
var hit_techniques: Array[StringName] = []

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--capture-and-quit")
	initial_health = float(dummy.health)
	player.set_test_input(0.0,false,false)
	player.combo_completed.connect(_on_combo_completed)
	player.combo_link_started.connect(_on_combo_link_started)
	print("VM02_C7_MODE=AUTOPLAY")

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not first_requested and elapsed >= 0.5 and player.attack_phase == "idle":
		first_requested = true
		player.set_test_attack_edge(true)
		print("VM02_C7_ATTACK_REQUEST=1")
	if first_requested and not second_buffered and player.combo_buffer_open:
		second_buffered = true
		player.set_test_combo_edge(true)
		print("VM02_C7_ATTACK_REQUEST=2_BUFFERED")
	if player.attack_phase == "active" and not hit_latch:
		for area in attack_area.get_overlapping_areas():
			var target := area.get_parent()
			if target != null and target.has_method("receive_combat_hit"):
				hit_latch = true
				var technique = TechniqueCatalog.get_technique(player.current_technique_id)
				target.receive_combat_hit(float(technique.damage))
				hit_techniques.append(player.current_technique_id)
				print("VM02_C7_HIT_CONFIRM=%d technique=%s damage=%.2f" % [int(dummy.hit_count), String(player.current_technique_id), float(technique.damage)])
				seen_first_hit = true
				break
	elif player.attack_phase != "active":
		hit_latch = false
	if seen_first_hit and not combo_done and int(dummy.hit_count) < 2 and player.attack_phase == "idle" and player.combo_index == 0:
		idle_between_hits = true
	link_label.text = "LINK: %s · %s" % [str(int(player.combo_index)), String(player.current_technique_id)]
	metric_label.text = "combo=%d hits=%d hp=%.1f buffered=%s idle_gap=%s" % [completed_combo_hits,int(dummy.hit_count),float(dummy.health),str(second_buffered),str(idle_between_hits)]
	if combo_done and player.attack_phase == "idle" and dummy.reaction_phase == "idle":
		_finish()
	if elapsed > 6.0 and not combo_done:
		push_error("VM02_C7_WATCHDOG=BLOCKED")
		get_tree().quit(3)

func _on_combo_link_started(index: int, technique_id: StringName) -> void:
	links.append(technique_id)
	print("VM02_C7_LINK_START=%d technique=%s" % [index, String(technique_id)])

func _on_combo_completed(hits: int) -> void:
	completed_combo_hits = hits
	combo_done = true
	print("VM02_C7_COMBO_SIGNAL=%d" % hits)

func _finish() -> void:
	set_physics_process(false)
	var body_hook = TechniqueCatalog.get_technique(&"ji_body_hook")
	var sweep = TechniqueCatalog.get_technique(&"ji_sweep")
	var expected_damage := float(body_hook.damage) + float(sweep.damage)
	var damage := initial_health - float(dummy.health)
	var links_ok := links.size() == 2 and links[0] == &"ji_body_hook" and links[1] == &"ji_sweep"
	var hits_ok := hit_techniques.size() == 2 and hit_techniques[0] == &"ji_body_hook" and hit_techniques[1] == &"ji_sweep" and int(dummy.hit_count) == 2
	var damage_ok := absf(damage - expected_damage) < 0.01
	var ok := links_ok and hits_ok and damage_ok and second_buffered and not idle_between_hits and completed_combo_hits == 2
	print("VM02_C7_DISTINCT_LINKS=%s" % ("PASS" if links_ok else "BLOCKED"))
	print("VM02_C7_TWO_HIT_CHAIN=%s" % ("PASS" if hits_ok else "BLOCKED"))
	print("VM02_C7_BUFFER_WINDOW=%s" % ("PASS" if second_buffered else "BLOCKED"))
	print("VM02_C7_NO_IDLE_GAP=%s" % ("PASS" if not idle_between_hits else "BLOCKED"))
	print("VM02_C7_COMPLETED_COMBO_COUNT=%s hits=%d" % [("PASS" if completed_combo_hits == 2 else "BLOCKED"), completed_combo_hits])
	print("VM02_C7_DAMAGE_APPLIED=%.2f expected=%.2f" % [damage,expected_damage])
	print("VM02_C7_DAMAGE_CONTRACT=%s" % ("PASS" if damage_ok else "BLOCKED"))
	print("VM02_C7_RUNTIME=%s" % ("PASS" if ok else "BLOCKED"))
	if not ok:
		if capture: get_tree().quit(3)
		return
	if capture: call_deferred("_capture_and_quit")

func _capture_and_quit() -> void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c7"))
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x,OUTPUT_SIZE.y,Image.INTERPOLATE_LANCZOS)
		print("VM02_C7_CAPTURE_NORMALIZED=PASS")
	var err := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		get_tree().quit(4)
		return
	print("VM02_C7_CAPTURE=PASS")
	print("VM02_C7_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
