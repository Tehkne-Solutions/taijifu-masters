extends SceneTree

const ROOT := "user://tgap-smoke"
const PACK_ID := "pack_smoke_runtime"
const VERSION := "1.0.0"
const RESOURCE_PATH := "runtime/smoke_resource.tres"
const MAIN_SCENES: Array[String] = ["res://scenes/vertical_slice/first_playable_menu.tscn"]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_fixture()
	var loader: Node = root.get_node_or_null("TgapAssetLoader")
	_check(loader != null, "autoload TgapAssetLoader ausente")
	_check(root.get_node_or_null("AssetPackRegistry") == null, "autoload AssetPackRegistry legado ainda ativo")
	if loader != null:
		loader.runtime_root = ROOT
		loader.catalog_filename = "tgap-catalog.json"
		loader.active_directory = "tgap-current"
		_check(loader.load_catalog(true), "catálogo TGAP de smoke não carregou")
		_check(loader.generation() == 1, "generation inesperada")
		var resolved: String = loader.resolve(PACK_ID, RESOURCE_PATH, VERSION)
		_check(not resolved.is_empty(), "recurso TGAP não foi resolvido")
		_check(loader.resolve(PACK_ID, RESOURCE_PATH, "9.9.9").is_empty(), "versão incompatível foi aceita")
		var resource: Resource = loader.load_resource(PACK_ID, RESOURCE_PATH, VERSION)
		_check(resource != null, "ResourceLoader não carregou recurso TGAP real")
	for scene_path in MAIN_SCENES:
		_check(ResourceLoader.exists(scene_path), "cena principal ausente: %s" % scene_path)
		var packed: Resource = load(scene_path)
		_check(packed is PackedScene, "cena principal inválida: %s" % scene_path)
		if packed is PackedScene:
			var instance: Node = packed.instantiate()
			_check(instance != null, "cena principal não instancia: %s" % scene_path)
			if instance != null:
				instance.free()
	if failures.is_empty():
		print("TGAP_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _prepare_fixture() -> void:
	var pack_root := ROOT.path_join("tgap-current/packs").path_join(PACK_ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pack_root.path_join("runtime")))
	var resource_file := FileAccess.open(pack_root.path_join(RESOURCE_PATH), FileAccess.WRITE)
	resource_file.store_string("[gd_resource type=\"Resource\" format=3]\n\n[resource]\nresource_name = \"TGAP Smoke Resource\"\n")
	resource_file.close()
	var catalog := {
		"schema": "tgap/install-catalog/v1",
		"generation": 1,
		"packs": [{
			"pack_id": PACK_ID,
			"display_name": "Runtime Smoke Pack",
			"version": VERSION,
			"state": "integrated"
		}]
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var catalog_file := FileAccess.open(ROOT.path_join("tgap-catalog.json"), FileAccess.WRITE)
	catalog_file.store_string(JSON.stringify(catalog, "  "))
	catalog_file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
