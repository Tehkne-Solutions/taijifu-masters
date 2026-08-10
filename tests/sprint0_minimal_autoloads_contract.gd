extends SceneTree

const MAX_AUTOLOADS := 9
const REQUIRED := [
	"TgapAssetLoader",
	"InputBootstrapRuntime",
	"ProceduralArenaPickupRuntime",
	"PickupSynergyRuntime",
	"MedievalUIThemeRuntime",
	"CombatAttributeIntegrationRuntime",
	"ElementalAdvantageRuntime",
	"FirstPlayableCombatFeelRuntime",
	"TaijifuWebBridge",
]
const FORBIDDEN := [
	"AssetPackRegistry",
	"GameModeRuntime",
	"Pack99BattleVisualRuntime",
	"Pack99CombatEventRuntime",
	"Pack08ArenaUnitRuntime",
	"SeriesLootProgressionRuntime",
	"CompleteSeriesModeRuntime",
	"ModeAwarePreparationRuntime",
	"CombatDifficultyTrainingRuntime",
	"TrainingProgressionRuntime",
	"PlayerProgressionProfileRuntime",
	"CosmeticCollectionRuntime",
	"PurchasedItemsApplicationRuntime",
	"PreparationBuildComparisonRuntime",
	"TaijifuGamepadTraining",
	"TaijifuGamepadExperience",
	"TaijifuControllerMastery",
	"TaijifuInputGhostMastery",
	"TaijifuGhostSharing",
	"TaijifuGhostLibrary",
	"TaijifuGhostRaceHistory",
	"TaijifuGhostRaceSeries",
	"TaijifuGhostRivalRanking",
	"TaijifuMultiGhostRace",
	"TaijifuGhostRace",
]

func _init() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		_fail("project.godot não pôde ser lido")
		return
	var source := file.get_as_text()
	var section := source.get_slice("[autoload]", 1).get_slice("[debug]", 0)
	var count := 0
	for line in section.split("\n"):
		if line.contains("=\"*res://"):
			count += 1
	if count > MAX_AUTOLOADS:
		_fail("autoloads acima do limite: %d > %d" % [count, MAX_AUTOLOADS])
		return
	for name in REQUIRED:
		if not section.contains(name + "="):
			_fail("autoload obrigatório ausente: " + name)
			return
	for name in FORBIDDEN:
		if section.contains(name + "="):
			_fail("autoload fora do First Playable ainda ativo: " + name)
			return
	print("SPRINT0_MINIMAL_AUTOLOADS_CONTRACT_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

# Tehkné Solutions
