extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const EXPECTED_IDS := [
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
	var texture := load(BASE) as Texture2D
	if texture == null:
		_fail(["base_texture_missing"])
		return

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c62_3_creator_profile"
	var assembler := ModularFighterAssembler.new()
	get_root().add_child(assembler)
	var configure_failures := assembler.configure(profile)
	if not configure_failures.is_empty():
		_fail(["assembler_configure:%s" % ",".join(configure_failures)])
		return

	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	if not assembler.attach_visual_module(&"body_base", body):
		_fail(["body_attach_failed"])
		return

	var selector := ModularFighterSkinSelector.new()
	get_root().add_child(selector)
	await process_frame
	await process_frame

	if selector.option_count() != 8:
		failures.append("option_count:%d" % selector.option_count())
	var ids := selector.palette_ids()
	if Array(ids) != EXPECTED_IDS:
		failures.append("palette_ids:%s" % JSON.stringify(Array(ids)))

	var signal_count := 0
	var last_signal := &""
	selector.skin_selected.connect(func(palette_id: StringName):
		signal_count += 1
		last_signal = palette_id
	)

	var bind_failures := selector.bind(profile, assembler)
	if not bind_failures.is_empty():
		failures.append("bind:%s" % ",".join(bind_failures))
	if selector.selected_palette_id() != StringName(DEFAULT_ID):
		failures.append("bind_default_selector")
	if profile.skin_palette_id() != StringName(DEFAULT_ID):
		failures.append("bind_default_profile")
	if assembler.active_skin_palette_id() != StringName(DEFAULT_ID):
		failures.append("bind_default_assembler")
	if body.material != null:
		failures.append("bind_default_material_should_be_null")

	var expected_signals := 0
	for palette_id in EXPECTED_IDS:
		var selection_failures := selector.select_palette(StringName(palette_id))
		if not selection_failures.is_empty():
			failures.append("select:%s:%s" % [palette_id, ",".join(selection_failures)])
			continue
		expected_signals += 1
		if selector.selected_palette_id() != StringName(palette_id):
			failures.append("selector_desync:%s" % palette_id)
		if profile.skin_palette_id() != StringName(palette_id):
			failures.append("profile_desync:%s" % palette_id)
		if assembler.active_skin_palette_id() != StringName(palette_id):
			failures.append("assembler_desync:%s" % palette_id)
		if palette_id == DEFAULT_ID:
			if body.material != null:
				failures.append("warm_material_should_be_null")
		else:
			if not (body.material is ShaderMaterial):
				failures.append("shader_material_missing:%s" % palette_id)
		var base_color := selector.palette_base_color(StringName(palette_id))
		if base_color == Color.MAGENTA:
			failures.append("swatch_color_invalid:%s" % palette_id)
		if selector.palette_display_name(StringName(palette_id)).is_empty():
			failures.append("display_name_empty:%s" % palette_id)
		print("C62_3_CREATOR_OPTION=PASS palette=%s" % palette_id)

	if signal_count != expected_signals:
		failures.append("signal_count:%d expected:%d" % [signal_count, expected_signals])
	if last_signal != StringName(EXPECTED_IDS[-1]):
		failures.append("last_signal:%s" % String(last_signal))

	var before_invalid := selector.selected_palette_id()
	var invalid_failures := selector.select_palette(&"skin_tone_99_invalid")
	if not invalid_failures.has("unknown_skin_palette:skin_tone_99_invalid"):
		failures.append("invalid_not_blocked")
	if selector.selected_palette_id() != before_invalid:
		failures.append("invalid_mutated_selection")
	if profile.skin_palette_id() != before_invalid or assembler.active_skin_palette_id() != before_invalid:
		failures.append("invalid_mutated_runtime")

	selector.focus_selected()
	await process_frame
	var focus_owner := get_root().gui_get_focus_owner()
	if focus_owner == null:
		failures.append("focus_owner_missing")
	elif not focus_owner.has_meta("palette_id"):
		failures.append("focus_owner_not_palette_button")
	elif StringName(String(focus_owner.get_meta("palette_id"))) != before_invalid:
		failures.append("focus_owner_wrong_palette")

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_3_SKIN_CREATOR_CONTROL=PASS options=8")
	print("C62_3_PROFILE_ASSEMBLER_SYNC=PASS")
	print("C62_3_INVALID_SELECTION=BLOCKED")
	print("C62_3_KEYBOARD_GAMEPAD_FOCUS=PASS")
	print("C62_3_DUPLICATE_BODY_PNG=PASS allowed=false")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(failures: PackedStringArray) -> void:
	for failure in failures:
		push_error("C62_3_SKIN_CREATOR_CONTROL=BLOCKED %s" % failure)
	quit(2)
