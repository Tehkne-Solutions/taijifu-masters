extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const PALETTE_IDS := [
	"skin_tone_01_porcelain",
	"skin_tone_02_light_neutral",
	"skin_tone_03_warm",
	"skin_tone_04_olive",
	"skin_tone_05_tan",
	"skin_tone_06_brown",
	"skin_tone_07_deep",
	"skin_tone_08_ebony",
]
const DEFAULT_ID := "skin_tone_03_warm"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var base_texture := load(BASE) as Texture2D
	if base_texture == null:
		_fail(["base_texture_missing"])
		return

	for palette_id in PALETTE_IDS:
		var profile := ModularFighterProfile.new()
		profile.profile_id = StringName("profile_%s" % palette_id)
		profile.set_skin_palette_id(StringName(palette_id))
		var profile_failures := profile.validate_against_standard()
		if not profile_failures.is_empty():
			failures.append("profile_validation:%s:%s" % [palette_id, ",".join(profile_failures)])
			continue
		if String(profile.skin_palette_id()) != palette_id:
			failures.append("profile_getter:%s" % palette_id)
		var runtime := profile.to_runtime_dictionary()
		if String(runtime.get("palette", {}).get("skin", "")) != palette_id:
			failures.append("runtime_serialization:%s" % palette_id)

		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var configure_failures := assembler.configure(profile)
		if not configure_failures.is_empty():
			failures.append("configure:%s:%s" % [palette_id, ",".join(configure_failures)])
			assembler.queue_free()
			continue
		if String(assembler.active_skin_palette_id()) != palette_id:
			failures.append("configure_active_palette:%s" % palette_id)

		var body := Sprite2D.new()
		body.texture = base_texture
		if not assembler.attach_visual_module(&"body_base", body):
			failures.append("body_attach:%s" % palette_id)
		if palette_id == DEFAULT_ID:
			if body.material != null:
				failures.append("default_material_should_be_null:%s" % palette_id)
		else:
			if not (body.material is ShaderMaterial):
				failures.append("profile_material_missing:%s" % palette_id)

		var assembly_failures := assembler.assemble_base01_default_identity()
		if not assembly_failures.is_empty():
			failures.append("default_identity:%s:%s" % [palette_id, ",".join(assembly_failures)])
		elif String(assembler.active_skin_palette_id()) != palette_id:
			failures.append("default_identity_overrode_profile:%s" % palette_id)

		print("C62_2_PROFILE_SKIN=PASS palette=%s" % palette_id)
		assembler.queue_free()

	var invalid := ModularFighterProfile.new()
	invalid.profile_id = &"invalid_skin_profile"
	invalid.set_skin_palette_id(&"skin_tone_99_invalid")
	var invalid_failures := invalid.validate_against_standard()
	if not invalid_failures.has("unknown_skin_palette:skin_tone_99_invalid"):
		failures.append("invalid_skin_not_blocked")

	var clear_profile := ModularFighterProfile.new()
	clear_profile.profile_id = &"clear_skin_profile"
	clear_profile.set_skin_palette_id(&"skin_tone_06_brown")
	clear_profile.set_skin_palette_id(&"")
	if clear_profile.skin_palette_id() != &"" or clear_profile.palette.has("skin"):
		failures.append("skin_clear_failed")

	var implicit_default := ModularFighterProfile.new()
	implicit_default.profile_id = &"implicit_default_profile"
	var implicit_assembler := ModularFighterAssembler.new()
	get_root().add_child(implicit_assembler)
	var implicit_failures := implicit_assembler.configure(implicit_default)
	if not implicit_failures.is_empty():
		failures.append("implicit_configure:%s" % ",".join(implicit_failures))
	elif implicit_assembler.active_skin_palette_id() != &"":
		failures.append("implicit_palette_should_start_empty")
	else:
		implicit_failures = implicit_assembler.assemble_base01_default_identity()
		if not implicit_failures.is_empty():
			failures.append("implicit_default_identity:%s" % ",".join(implicit_failures))
		elif String(implicit_assembler.active_skin_palette_id()) != DEFAULT_ID:
			failures.append("implicit_default_not_warm")
	implicit_assembler.queue_free()

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_2_PROFILE_SKIN_SELECTION=PASS palettes=8")
	print("C62_2_INVALID_SKIN=BLOCKED")
	print("C62_2_PROFILE_PRESERVATION=PASS")
	print("C62_2_IMPLICIT_DEFAULT=PASS palette=%s" % DEFAULT_ID)
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(failures: PackedStringArray) -> void:
	for failure in failures:
		push_error("C62_2_PROFILE_SKIN_SELECTION=BLOCKED %s" % failure)
	quit(2)
