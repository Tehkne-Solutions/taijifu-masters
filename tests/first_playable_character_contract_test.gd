extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var lian := BuildProfile.prototype_preset(&"lian_wu_first_playable")
	var rival := BuildProfile.prototype_preset(&"training_rival_first_playable")

	_validate_lian(lian, failures)
	_validate_rival(rival, failures)
	_validate_katana_kit(lian, failures)
	_validate_training_saber_kit(rival, failures)

	if failures.is_empty():
		print("FIRST_PLAYABLE_CHARACTER_CONTRACT_OK")
		quit(0)
		return
	for failure in failures:
		printerr("FIRST_PLAYABLE_CHARACTER_CONTRACT_FAILED: %s" % failure)
	quit(1)

func _validate_lian(profile: BuildProfile, failures: Array[String]) -> void:
	if profile.character_id != &"lian_wu" or profile.character_name != "Lian Wu":
		failures.append("Lian Wu identity is invalid")
	if profile.element_id != &"water":
		failures.append("Lian Wu must use water")
	if profile.weapon_id != &"serene_katana" or profile.secondary_weapon_id != &"unarmed":
		failures.append("Lian Wu weapon contract is invalid")
	if profile.technique <= profile.strength or profile.focus <= profile.defense:
		failures.append("Lian Wu must remain a technical/focused fighter")
	if not CharacterVisualCatalog.uses_procedural_fallback(profile.character_id):
		failures.append("Lian Wu procedural render mode is missing")

func _validate_rival(profile: BuildProfile, failures: Array[String]) -> void:
	if profile.character_id != &"training_rival" or profile.character_name != "Rival de Treino":
		failures.append("Training Rival identity is invalid")
	if profile.element_id != &"fire":
		failures.append("Training Rival must use fire")
	if profile.weapon_id != &"wooden_training_saber" or profile.secondary_weapon_id != &"unarmed":
		failures.append("Training Rival weapon contract must match canonical saber art")
	if profile.strength <= profile.technique or profile.resistance <= profile.agility:
		failures.append("Training Rival must remain a heavy pressure fighter")
	if not CharacterVisualCatalog.uses_procedural_fallback(profile.character_id):
		failures.append("Training Rival procedural render mode is missing")

func _validate_katana_kit(lian: BuildProfile, failures: Array[String]) -> void:
	if WeaponKitCatalog.label_for(&"serene_katana") != "KATANA SERENA":
		failures.append("Katana label is invalid")
	if WeaponKitCatalog.preferred_range(&"serene_katana") <= WeaponKitCatalog.preferred_range(&"breaker_gauntlets"):
		failures.append("Katana must have more range than breaker gauntlets")
	for context_id in [&"air", &"low", &"advance", &"neutral_ji", &"neutral_fu"]:
		var technique_id := WeaponKitCatalog.technique_for(&"serene_katana", context_id, lian)
		if technique_id == &"":
			failures.append("Katana context %s has no technique" % String(context_id))
			continue
		var technique := TechniqueCatalog.get_technique(technique_id)
		if technique.technique_id != technique_id or technique.display_name.strip_edges() == "":
			failures.append("Katana context %s resolves an invalid technique" % String(context_id))

func _validate_training_saber_kit(rival: BuildProfile, failures: Array[String]) -> void:
	if WeaponKitCatalog.label_for(&"wooden_training_saber") != "SABRE DE TREINO":
		failures.append("Training saber label is invalid")
	if WeaponKitCatalog.preferred_range(&"wooden_training_saber") <= WeaponKitCatalog.preferred_range(&"breaker_gauntlets"):
		failures.append("Training saber must have more range than breaker gauntlets")
	for context_id in [&"air", &"low", &"advance", &"neutral_ji", &"neutral_fu"]:
		var technique_id := WeaponKitCatalog.technique_for(&"wooden_training_saber", context_id, rival)
		if technique_id == &"":
			failures.append("Training saber context %s has no technique" % String(context_id))
			continue
		if not WeaponKitCatalog.is_technique_for_weapon(&"wooden_training_saber", technique_id):
			failures.append("Training saber context %s escapes its weapon kit" % String(context_id))
			continue
		var technique := TechniqueCatalog.get_technique(technique_id)
		if technique.technique_id != technique_id or technique.display_name.strip_edges() == "":
			failures.append("Training saber context %s resolves an invalid technique" % String(context_id))
