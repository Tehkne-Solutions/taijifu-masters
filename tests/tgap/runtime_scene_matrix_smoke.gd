extends SceneTree

const ROOT := "user://tgap-scene-matrix"
const CATALOG := ROOT + "/install-catalog.json"
const PACK_ROOT := ROOT + "/tgap-current/packs/taijifu_smoke"

var failures: Array[String] = []
var _loader: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_loader = root.get_node_or_null("TgapAssetLoader")
	_check(_loader != null, "autoload TgapAssetLoader ausente")
	_check(root.get_node_or_null("AssetPackRegistry") == null, "autoload AssetPackRegistry legado ainda ativo")
	if _loader == null:
		_finish()
		return
	_prepare_fixture(1, "v1")
	_loader.install_catalog_path = CATALOG
	_loader.alias_catalog_path = ROOT + "/aliases.json"
	_loader.reload_catalog()
	_check(_loader.generation() == 1, "generation 1 não carregada")
	_validate_aliases_and_resources("v1")
	_validate_scene_matrix()
	_validate_generation_invalidation()
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("TGAP_SCENE_MATRIX_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _prepare_fixture(generation: int, marker: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACK_ROOT + "/resources"))
	_write(PACK_ROOT + "/resources/preparation.tres", _resource(marker + "-preparation"))
	_write(PACK_ROOT + "/resources/arena.tres", _sprite_frames(marker + "-arena"))
	_write(PACK_ROOT + "/resources/result.tres", _resource(marker + "-result"))
	_write(ROOT + "/aliases.json", JSON.stringify({
		"schema": "tgap/aliases/v1",
		"aliases": {
			"smoke": {
				"pack_id": "taijifu_smoke"
			}
		},
		"path_aliases": {
			"taijifu_smoke": {
				"preparation_ui": "resources/preparation.tres",
				"arena_animation": "resources/arena.tres",
				"result_ui": "resources/result.tres"
			}
		}
	}, "  "))
	_write(CATALOG, JSON.stringify({
		"schema": "tgap/install-catalog/v1",
		"generation": generation,
		"packs": [{
			"pack_id": "taijifu_smoke",
			"display_name": "Taijifu Smoke",
			"version": "1.0.%d" % generation,
			"state": "integrated"
		}]
	}, "  "))

func _validate_aliases_and_resources(marker: String) -> void:
	var prep: Resource = _loader.load_resource("smoke", "preparation_ui")
	_check(prep != null, "alias preparation_ui não carregou")
	if prep != null:
		_check(str(prep.resource_name) == marker + "-preparation", "preparation retornou geração incorreta")
	var frames: Resource = _loader.load_resource("smoke", "arena_animation")
	_check(frames is SpriteFrames, "arena_animation não retornou SpriteFrames")
	if frames is SpriteFrames:
		_check(frames.has_animation("idle"), "animação idle ausente")
		_check(frames.get_animation_speed("idle") == 8.0, "fps da animação incorreto")
	var result: Resource = _loader.load_resource("smoke", "result_ui")
	_check(result != null, "alias result_ui não carregou")

func _validate_scene_matrix() -> void:
	var scenes: Array[String] = ["res://scenes/vertical_slice/first_playable_menu.tscn"]
	for path in scenes:
		_check(ResourceLoader.exists(path), "cena ausente: " + path)
		var packed: Resource = load(path)
		_check(packed is PackedScene, "recurso não é PackedScene: " + path)
		if packed is PackedScene:
			var node: Node = packed.instantiate()
			_check(node != null, "falha ao instanciar: " + path)
			if node != null:
				node.free()

func _validate_generation_invalidation() -> void:
	var first: Resource = _loader.load_resource("smoke", "preparation_ui")
	_prepare_fixture(2, "v2")
	_loader.reload_catalog()
	_check(_loader.generation() == 2, "generation 2 não carregada")
	var second: Resource = _loader.load_resource("smoke", "preparation_ui")
	_check(second != null, "recurso não recarregou após troca de geração")
	if first != null and second != null:
		_check(str(second.resource_name) == "v2-preparation", "cache não foi invalidado por geração")

func _resource(name: String) -> String:
	return "[gd_resource type=\"Resource\" format=3]\n\n[resource]\nresource_name = \"%s\"\n" % name

func _sprite_frames(name: String) -> String:
	return "[gd_resource type=\"SpriteFrames\" format=3]\n\n[resource]\nresource_name = \"%s\"\nanimations = [{\n\"frames\": [],\n\"loop\": true,\n\"name\": &\"idle\",\n\"speed\": 8.0\n}]\n" % name

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("não foi possível escrever " + path)
		return
	file.store_string(content)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
