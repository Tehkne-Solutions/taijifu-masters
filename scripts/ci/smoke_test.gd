extends SceneTree

const REQUIRED_RESOURCES := [
	"res://project.godot",
	"res://scenes/main.tscn",
	"res://scenes/fighter/fighter.tscn",
	"res://assets/characters/kael/kael_provisional_sheet.svg",
	"res://assets/characters/nara/nara_provisional_sheet.svg",
	"res://scripts/visual/provisional_sprite_presenter.gd",
	"res://scripts/visual/fighter_visual_overlay.gd",
	"res://scripts/runtime/impact_director.gd",
	"res://scripts/fighter/mastered_weapon_fighter_controller.gd"
]

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(path):
			failures.append("Recurso ausente ou não importável: %s" % path)

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(main_scene):
		failures.append("Não foi possível carregar scenes/main.tscn")
	else:
		var instance := main_scene.instantiate()
		if not is_instance_valid(instance):
			failures.append("Não foi possível instanciar scenes/main.tscn")
		else:
			root.add_child(instance)
			await process_frame
			await process_frame
			var impact_director := instance.get_node_or_null("ImpactDirector")
			var dojo_runtime := instance.get_node_or_null("DojoTrainingRuntime")
			if not is_instance_valid(impact_director):
				failures.append("ImpactDirector não foi integrado à cena principal")
			if not is_instance_valid(dojo_runtime):
				failures.append("DojoTrainingRuntime não foi integrado à cena principal")
			instance.queue_free()
			await process_frame

	if failures.is_empty():
		print("TAIJIFU CI: importação, recursos e cena principal válidos.")
		quit(0)
		return

	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)
