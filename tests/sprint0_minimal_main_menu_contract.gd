extends SceneTree

const MENU_PATH := "res://scripts/runtime/main_menu_runtime.gd"

func _init() -> void:
	var source := FileAccess.get_file_as_string(MENU_PATH)
	var required := [
		"JOGAR",
		"TREINO",
		"OPÇÕES",
		"competitive_duel",
		"training",
		"FIRST PLAYABLE"
	]
	for marker in required:
		if not source.contains(marker):
			_fail("marcador ausente: %s" % marker)

	var forbidden := [
		"PERFIL E PROGRESSÃO",
		"LOJA DE TREINO",
		"COLEÇÃO",
		"ESCOLHA SUA PROVA",
		"roguelite_series",
		"champion_challenge",
		"arena_loot"
	]
	for marker in forbidden:
		if source.contains(marker):
			_fail("conteúdo legado ainda exposto: %s" % marker)

	print("SPRINT0_MINIMAL_MAIN_MENU_CONTRACT_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

# Tehkné Solutions
