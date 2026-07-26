class_name WeaponKitFighterController
extends ElementalFighterController

signal weapon_swapped(
	fighter: WeaponKitFighterController,
	from_weapon_id: StringName,
	to_weapon_id: StringName,
	slot_id: int
)
signal training_variant_applied(
	fighter: WeaponKitFighterController,
	variant_id: StringName,
	display_name: String
)

const SLOT_UNARMED := -1
const SLOT_PRIMARY := 0
const SLOT_SECONDARY := 1
const SLOT_BORROWED := 2
const WEAPON_SWAP_STAMINA_COST := 8.0
const WEAPON_SWAP_RECOVERY := 0.32

var primary_weapon_id: StringName = &"unarmed"
var secondary_weapon_id: StringName = &"unarmed"
var borrowed_weapon_id: StringName = &""
var active_weapon_slot := SLOT_PRIMARY
var _primary_available := true
var _secondary_available := true
var _borrowed_available := false
var _unlocked_technique_variants: Dictionary = {}

func _ready() -> void:
	super._ready()
	_configure_original_loadout()

func _process_actions() -> void:
	super._process_actions()
	if Input.is_action_just_pressed(_action("swap")):
		_try_swap_weapon()

func _try_contextual_attack() -> void:
	var context_id := &"neutral_fu"
	if not is_on_floor():
		context_id = &"air"
	elif Input.is_action_pressed(_action("down")):
		context_id = &"low"
	elif absf(velocity.x) > build.movement_speed() * 0.52:
		context_id = &"advance"
	elif build.ji_index() > build.fu_index():
		context_id = &"neutral_ji"

	var technique_id := WeaponKitCatalog.technique_for(
		equipped_weapon_id,
		context_id,
		build
	)
	_begin_technique(technique_id)

func _begin_technique(technique_id: StringName) -> bool:
	var began := super._begin_technique(technique_id)
	if not began or not is_instance_valid(_current_technique):
		return began
	var variant_id := StringName(_unlocked_technique_variants.get(String(technique_id), &""))
	if variant_id == &"":
		return true
	MasterTrainingCatalog.apply_variant(_current_technique, variant_id)
	training_variant_applied.emit(self, variant_id, _current_technique.display_name)
	return true

func set_unlocked_variants(variant_mapping: Dictionary) -> void:
	_unlocked_technique_variants = variant_mapping.duplicate(true)

func unlocked_variant_for(technique_id: StringName) -> StringName:
	return StringName(_unlocked_technique_variants.get(String(technique_id), &""))

func can_swap_weapon() -> bool:
	return (
		is_on_floor()
		and stamina >= WEAPON_SWAP_STAMINA_COST
		and _attack_phase == AttackPhase.NONE
		and _dodge_timer <= 0.0
		and not _is_blocking
		and not is_instance_valid(_grabbed_target)
		and not is_instance_valid(_grabbed_by)
		and _next_available_slot() != SLOT_UNARMED
	)

func next_available_weapon_id() -> StringName:
	return _weapon_for_slot(_next_available_slot())

func _try_swap_weapon() -> bool:
	if not can_swap_weapon():
		return false

	var next_slot := _next_available_slot()
	var next_weapon := _weapon_for_slot(next_slot)
	if next_weapon == &"" or next_weapon == equipped_weapon_id:
		return false

	var previous_weapon := equipped_weapon_id
	active_weapon_slot = next_slot
	equipped_weapon_id = next_weapon
	stamina -= WEAPON_SWAP_STAMINA_COST
	_attack_phase = AttackPhase.RECOVERY
	_attack_phase_timer = WEAPON_SWAP_RECOVERY
	_current_technique = null
	attack_shape.set_deferred("disabled", true)
	weapon_swapped.emit(self, previous_weapon, equipped_weapon_id, active_weapon_slot)
	combat_state_changed.emit(self)
	queue_redraw()
	return true

func _next_available_slot() -> int:
	var order := [SLOT_PRIMARY, SLOT_SECONDARY, SLOT_BORROWED]
	var start_index := order.find(active_weapon_slot)
	if start_index < 0:
		start_index = -1
	for step in range(1, order.size() + 1):
		var slot_id: int = order[(start_index + step) % order.size()]
		if _slot_available(slot_id):
			return slot_id
	return SLOT_UNARMED

func _slot_available(slot_id: int) -> bool:
	match slot_id:
		SLOT_PRIMARY:
			return _primary_available and primary_weapon_id != &"unarmed"
		SLOT_SECONDARY:
			return _secondary_available and secondary_weapon_id != &"unarmed" and secondary_weapon_id != primary_weapon_id
		SLOT_BORROWED:
			return _borrowed_available and borrowed_weapon_id != &""
		_:
			return false

func _weapon_for_slot(slot_id: int) -> StringName:
	match slot_id:
		SLOT_PRIMARY:
			return primary_weapon_id
		SLOT_SECONDARY:
			return secondary_weapon_id
		SLOT_BORROWED:
			return borrowed_weapon_id
		_:
			return &"unarmed"

func _configure_original_loadout() -> void:
	primary_weapon_id = build.weapon_id
	secondary_weapon_id = build.secondary_weapon_id
	borrowed_weapon_id = &""
	_primary_available = primary_weapon_id != &"unarmed"
	_secondary_available = secondary_weapon_id != &"unarmed" and secondary_weapon_id != primary_weapon_id
	_borrowed_available = false
	active_weapon_slot = SLOT_PRIMARY if _primary_available else SLOT_SECONDARY
	equipped_weapon_id = _weapon_for_slot(active_weapon_slot)
	if equipped_weapon_id == &"":
		equipped_weapon_id = &"unarmed"
		active_weapon_slot = SLOT_UNARMED

func _drop_weapon() -> void:
	if equipped_weapon_id == &"unarmed":
		return
	var dropped_slot := active_weapon_slot
	super._drop_weapon()
	match dropped_slot:
		SLOT_PRIMARY:
			_primary_available = false
		SLOT_SECONDARY:
			_secondary_available = false
		SLOT_BORROWED:
			_borrowed_available = false
			borrowed_weapon_id = &""
	active_weapon_slot = SLOT_UNARMED
	queue_redraw()

func collect_temporary_weapon(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false

	var previous_weapon := equipped_weapon_id
	if weapon_id == primary_weapon_id and not _primary_available:
		_primary_available = true
		active_weapon_slot = SLOT_PRIMARY
	elif weapon_id == secondary_weapon_id and not _secondary_available:
		_secondary_available = true
		active_weapon_slot = SLOT_SECONDARY
	else:
		borrowed_weapon_id = weapon_id
		_borrowed_available = true
		active_weapon_slot = SLOT_BORROWED

	equipped_weapon_id = weapon_id
	disarm_pressure = 0.0
	loot_collected.emit(self, &"weapon", weapon_id)
	weapon_swapped.emit(self, previous_weapon, equipped_weapon_id, active_weapon_slot)
	combat_state_changed.emit(self)
	queue_redraw()
	return true

func reset_fighter(spawn_position: Vector2) -> void:
	super.reset_fighter(spawn_position)
	_configure_original_loadout()
	queue_redraw()

func current_weapon_label() -> String:
	return WeaponKitCatalog.label_for(equipped_weapon_id)

func current_weapon_kit_summary() -> String:
	return WeaponKitCatalog.tactical_summary(equipped_weapon_id)

func active_weapon_slot_label() -> String:
	match active_weapon_slot:
		SLOT_PRIMARY:
			return "PRINCIPAL"
		SLOT_SECONDARY:
			return "SECUNDÁRIA"
		SLOT_BORROWED:
			return "ESPÓLIO"
		_:
			return "DESARMADO"

func weapon_loadout_label() -> String:
	return "%s / %s" % [
		WeaponKitCatalog.label_for(primary_weapon_id),
		WeaponKitCatalog.label_for(secondary_weapon_id)
	]

func is_using_borrowed_weapon() -> bool:
	return active_weapon_slot == SLOT_BORROWED

func _weapon_damage_multiplier() -> float:
	var multiplier := WeaponKitCatalog.damage_multiplier(equipped_weapon_id)
	if steam_timer > 0.0:
		multiplier *= 0.82
	return multiplier

func _weapon_posture_multiplier() -> float:
	var multiplier := WeaponKitCatalog.posture_multiplier(equipped_weapon_id)
	if mud_timer > 0.0:
		multiplier *= 0.88
	return multiplier
