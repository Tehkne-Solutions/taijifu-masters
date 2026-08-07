extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	# Sprint 0 forbids these as permanent autoloads. The library smoke only needs
	# their real classes for package creation and CRUD validation.
	var sharing := GhostSharingRuntime.new()
	sharing.name = "TaijifuGhostSharing"
	root.add_child(sharing)
	var library := GhostLibraryRuntime.new()
	library.name = "TaijifuGhostLibrary"
	root.add_child(library)
	if not is_instance_valid(library) or not is_instance_valid(sharing):
		failures.append("Runtimes temporários da biblioteca não puderam ser montados")
		_cleanup(library, sharing)
		_finish(failures)
		return

	library.items.clear()
	library.selected_id = ""
	var recording := {
		"version": 1,
		"created_unix": 123456,
		"duration_ms": 400,
		"frames": [
			{"t": 0, "position": [100.0, 200.0], "velocity": [0.0, 0.0], "facing": 1.0, "phase": 0, "technique": "", "weapon": "staff", "inputs": {}},
			{"t": 400, "position": [140.0, 200.0], "velocity": [100.0, 0.0], "facing": 1.0, "phase": 2, "technique": "horizon_thrust", "weapon": "staff", "inputs": {"attack": 1.0}}
		],
		"summary": {"score": 720, "accuracy": 0.75, "max_chain": 4}
	}
	var package := sharing.package_for_test(recording)
	var added := library.add_package(package)
	if not bool(added.get("ok", false)):
		failures.append("Pacote válido não entrou na biblioteca")
	var state := library.current_state()
	if int(state.get("count", 0)) != 1:
		failures.append("Contagem da biblioteca incorreta")
	var items: Array = state.get("items", [])
	if items.is_empty() or int(((items[0] as Dictionary).get("challenge", {}) as Dictionary).get("score", 0)) != 720:
		failures.append("Métricas do desafio não foram preservadas")
	var item_id := String((items[0] as Dictionary).get("id", "")) if not items.is_empty() else ""
	if not bool(library.select_item(item_id).get("ok", false)):
		failures.append("Fantasma não pôde ser selecionado")
	if not bool(library.remove_item(item_id).get("ok", false)):
		failures.append("Fantasma não pôde ser removido")
	if int(library.current_state().get("count", 0)) != 0:
		failures.append("Biblioteca não ficou vazia após remoção")

	_cleanup(library, sharing)
	_finish(failures)

func _cleanup(library: Node, sharing: Node) -> void:
	if is_instance_valid(library):
		library.free()
	if is_instance_valid(sharing):
		sharing.free()

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_LIBRARY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
