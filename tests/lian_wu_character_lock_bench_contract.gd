extends SceneTree

## Static contract gate for VM01-A3.
## Tehkné Solutions

const BENCH_SCRIPT := "res://scripts/visual/lian_wu_character_lock_bench.gd"
const FIGHTER_SCENE := "res://scenes/fighter/fighter.tscn"

func _init() -> void:
	var failures: Array[String] = []
	_require_file(BENCH_SCRIPT, failures)
	_require_file(FIGHTER_SCENE, failures)
	var source := FileAccess.get_file_as_string(BENCH_SCRIPT)
	_require(source, "REQUIRED_VIEWPORT := Vector2i(1920, 1080)", "bench viewport must be 1920x1080", failures)
	_require(source, "PIVOT_NORMALIZED := Vector2(0.5, 0.92)", "canonical pivot contract missing", failures)
	_require(source, "_sprite.flip_h = _fighter.facing < 0.0", "runtime facing/flip binding missing", failures)
	_require(source, "lian_wu_neutral.png", "neutral canonical asset contract missing", failures)
	_require(source, "lian_wu_combat_stance.png", "combat stance canonical asset contract missing", failures)
	if failures.is_empty():
		print("VM01_A3_GODOT_BENCH_CONTRACT=PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("VM01_A3_GODOT_BENCH_CONTRACT=BLOCKED")
	quit(1)

func _require_file(path: String, failures: Array[String]) -> void:
	if not FileAccess.file_exists(path):
		failures.append("missing file: %s" % path)

func _require(source: String, token: String, message: String, failures: Array[String]) -> void:
	if source.find(token) < 0:
		failures.append(message)
