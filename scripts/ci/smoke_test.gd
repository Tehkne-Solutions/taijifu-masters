extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scenes/main.tscn",
	"res://scenes/fighter/fighter.tscn",
	"res://assets/characters/kael/kael_animated_sheet.svg",
	"res://assets/characters/nara/nara_animated_sheet.svg",
	"res://assets/characters/lyra/lyra_animated_sheet.svg",
	"res://assets/characters/rin/rin_animated_sheet.svg",
	"res://scripts/visual/character_visual_catalog.gd",
	"res://scripts/visual/provisional_sprite_presenter.gd",
	"res://scripts/visual/fighter_visual_overlay.gd",
	"res://scripts/runtime/asset_inspector_runtime.gd",
	"res://scripts/runtime/roster_hud_runtime.gd",
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

	for character_id in CharacterVisualCatalog.character_ids():
		failures.append_array(CharacterVisualCatalog.validate_character(character_id))

	var presets := BuildProfile.available_prototype_presets()
	if presets.size() != 6:
		failures.append("O protótipo deveria expor seis builds, mas encontrou %d" % presets.size())
	for preset_id in presets:
		var profile := BuildProfile.prototype_preset(preset_id)
		if not CharacterVisualCatalog.has_character(profile.character_id):
			failures.append("Build %s referencia personagem inválido: %s" % [String(preset_id), String(profile.character_id)])
		if profile.character_name.strip_edges() == "":
			failures.append("Build %s não possui nome de personagem" % String(preset_id))

	await _validate_fighter_presenters(presets, failures)
	await _validate_main_scene(failures)

	if failures.is_empty():
		print("TAIJIFU CI: elenco animado, catálogo, recursos e cena principal válidos.")
		quit(0)
		return

	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_fighter_presenters(presets: Array[StringName], failures: Array[String]) -> void:
	var fighter_scene := load("res://scenes/fighter/fighter.tscn") as PackedScene
	if not is_instance_valid(fighter_scene):
		failures.append("Não foi possível carregar scenes/fighter/fighter.tscn")
		return
	for preset_id in presets:
		var fighter := fighter_scene.instantiate() as FighterController
		if not is_instance_valid(fighter):
			failures.append("Não foi possível instanciar lutador para %s" % String(preset_id))
			continue
		fighter.build_preset = preset_id
		root.add_child(fighter)
		await process_frame
		await process_frame
		var presenter := fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
		var expected := BuildProfile.prototype_preset(preset_id).character_id
		if not is_instance_valid(presenter) or not presenter.has_active_sprite():
			failures.append("Presenter inativo para %s" % String(preset_id))
		elif presenter.character_id() != expected:
			failures.append("Presenter de %s resolveu %s em vez de %s" % [String(preset_id), String(presenter.character_id()), String(expected)])
		fighter.queue_free()
		await process_frame

func _validate_main_scene(failures: Array[String]) -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(main_scene):
		failures.append("Não foi possível carregar scenes/main.tscn")
		return
	var instance := main_scene.instantiate()
	if not is_instance_valid(instance):
		failures.append("Não foi possível instanciar scenes/main.tscn")
		return
	root.add_child(instance)
	await process_frame
	await process_frame
	for node_path in [
		"ImpactDirector",
		"DojoTrainingRuntime",
		"AssetInspectorRuntime",
		"RosterHudRuntime"
	]:
		if not is_instance_valid(instance.get_node_or_null(node_path)):
			failures.append("%s não foi integrado à cena principal" % node_path)
	instance.queue_free()
	await process_frame
