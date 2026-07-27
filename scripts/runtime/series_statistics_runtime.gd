class_name SeriesStatisticsRuntime
extends Node

const MAX_HIGHLIGHTS_PER_ROUND := 24

var history := MatchHistoryLedger.new()
var _series: Dictionary = {}
var _current_round: Dictionary = {}
var _round_started_msec := 0
var _connected_ids: Dictionary = {}

func _ready() -> void:
	history.load_from_disk()

func begin_series(
	config: Dictionary,
	player_one_loadout: Dictionary,
	player_two_loadout: Dictionary,
	player_one_profile: Dictionary = {},
	player_two_profile: Dictionary = {}
) -> void:
	var now := int(Time.get_unix_time_from_system())
	_series = {
		"match_id": "match_%d_%d" % [now, Time.get_ticks_msec() % 100000],
		"started_unix": now,
		"config": CompetitiveMatchCatalog.sanitize(config),
		"players": [
			_player_record(1, player_one_loadout, player_one_profile),
			_player_record(2, player_two_loadout, player_two_profile)
		],
		"rounds": [],
		"totals": [_empty_stats(), _empty_stats()]
	}
	_current_round = {}
	_connected_ids.clear()

func begin_round(player_one: FighterController, player_two: FighterController, round_number: int) -> void:
	_connect_fighter(player_one)
	_connect_fighter(player_two)
	_round_started_msec = Time.get_ticks_msec()
	_current_round = {
		"round_number": maxi(1, round_number),
		"started_msec": _round_started_msec,
		"stats": [_empty_stats(), _empty_stats()],
		"highlights": []
	}

func complete_round(
	winner_index: int,
	reason: String,
	player_one: FighterController,
	player_two: FighterController
) -> Dictionary:
	if _current_round.is_empty():
		begin_round(player_one, player_two, 1)
	var duration := maxf(0.0, float(Time.get_ticks_msec() - _round_started_msec) / 1000.0)
	var stats: Array = _current_round.get("stats", [_empty_stats(), _empty_stats()])
	var highlights: Array = _current_round.get("highlights", [])
	var round_record := {
		"round_number": int(_current_round.get("round_number", 1)),
		"winner_index": clampi(winner_index, 1, 2),
		"reason": reason,
		"duration_seconds": duration,
		"stats": stats.duplicate(true),
		"highlights": highlights.duplicate(true),
		"resources": [
			_resource_snapshot(player_one),
			_resource_snapshot(player_two)
		]
	}
	var rounds: Array = _series.get("rounds", [])
	rounds.append(round_record)
	_series["rounds"] = rounds
	_accumulate_totals(stats)
	_current_round = {}
	return round_record.duplicate(true)

func complete_series(score_p1: int, score_p2: int, winner_index: int) -> Dictionary:
	if _series.is_empty():
		return {}
	_series["completed_unix"] = int(Time.get_unix_time_from_system())
	_series["score_p1"] = maxi(0, score_p1)
	_series["score_p2"] = maxi(0, score_p2)
	_series["winner_index"] = clampi(winner_index, 1, 2)
	var stored := history.append_series(_series)
	_series = {}
	_current_round = {}
	_connected_ids.clear()
	return stored

func current_series_snapshot() -> Dictionary:
	return _series.duplicate(true)

func recent_matches(limit: int = 10) -> Array[Dictionary]:
	return history.recent(limit)

func filtered_matches(filters: Dictionary, limit: int = 20) -> Array[Dictionary]:
	return history.filtered(filters, limit)

func aggregate_history(filters: Dictionary = {}) -> Dictionary:
	return history.aggregate(filters)

func add_test_stat(player_index: int, stat_id: StringName, amount: float = 1.0) -> void:
	_increment_stat(player_index, stat_id, amount)

func add_test_highlight(player_index: int, event_id: StringName, label: String, value: float = 0.0) -> void:
	_append_highlight(player_index, event_id, label, value)

func _connect_fighter(fighter: FighterController) -> void:
	if not is_instance_valid(fighter):
		return
	var instance_id := fighter.get_instance_id()
	if _connected_ids.has(instance_id):
		return
	_connected_ids[instance_id] = true
	if fighter.has_signal("impact_resolved"):
		fighter.connect("impact_resolved", Callable(self, "_on_impact_resolved"))
	if fighter.has_signal("parry_performed"):
		fighter.connect("parry_performed", Callable(self, "_on_parry_performed"))
	if fighter.has_signal("posture_broken"):
		fighter.connect("posture_broken", Callable(self, "_on_posture_broken"))
	if fighter.has_signal("weapon_disarmed"):
		fighter.connect("weapon_disarmed", Callable(self, "_on_weapon_disarmed"))
	if fighter.has_signal("grab_started"):
		fighter.connect("grab_started", Callable(self, "_on_grab_started"))
	if fighter.has_signal("elemental_interaction"):
		fighter.connect("elemental_interaction", Callable(self, "_on_elemental_interaction"))
	if fighter.has_signal("loot_collected"):
		fighter.connect("loot_collected", Callable(self, "_on_loot_collected"))

func _on_impact_resolved(
	_target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if not is_instance_valid(attacker):
		return
	var player_index := attacker.player_index
	_increment_stat(player_index, &"contacts", 1.0)
	match result_id:
		&"hit", &"posture_break":
			_increment_stat(player_index, &"hits", 1.0)
			_increment_stat(player_index, &"damage_dealt", damage_applied)
			_increment_stat(player_index, &"posture_damage", posture_applied)
			if damage_applied >= 18.0 or posture_applied >= 24.0:
				var technique_name := technique.display_name if is_instance_valid(technique) else "Técnica decisiva"
				_append_highlight(player_index, &"heavy_impact", "%s conecta um impacto decisivo" % technique_name, maxf(damage_applied, posture_applied))
		&"blocked":
			_increment_stat(player_index, &"blocked_contacts", 1.0)
		&"parried":
			_increment_stat(player_index, &"parried_contacts", 1.0)
		&"evaded":
			_increment_stat(player_index, &"evaded_contacts", 1.0)

func _on_parry_performed(fighter: FighterController) -> void:
	if is_instance_valid(fighter):
		_increment_stat(fighter.player_index, &"parries", 1.0)
		_append_highlight(fighter.player_index, &"parry", "Aparo técnico interrompe a pressão", 1.0)

func _on_posture_broken(fighter: FighterController, region_id: StringName) -> void:
	if is_instance_valid(fighter):
		var opponent_index := 2 if fighter.player_index == 1 else 1
		_increment_stat(opponent_index, &"posture_breaks", 1.0)
		_append_highlight(opponent_index, &"posture_break", "Quebra de postura na região %s" % String(region_id).to_upper(), 1.0)

func _on_weapon_disarmed(fighter: FighterController, weapon_id: StringName) -> void:
	if is_instance_valid(fighter):
		var opponent_index := 2 if fighter.player_index == 1 else 1
		_increment_stat(opponent_index, &"disarms", 1.0)
		_append_highlight(opponent_index, &"disarm", "Desarme de %s" % WeaponKitCatalog.label_for(weapon_id), 1.0)

func _on_grab_started(attacker: FighterController, _target: FighterController) -> void:
	if is_instance_valid(attacker):
		_increment_stat(attacker.player_index, &"grabs", 1.0)
		_append_highlight(attacker.player_index, &"grab", "Agarrão estabelece controle de posição", 1.0)

func _on_elemental_interaction(fighter: FighterController, interaction_id: StringName, element_id: StringName) -> void:
	if is_instance_valid(fighter):
		_increment_stat(fighter.player_index, &"elemental_interactions", 1.0)
		_append_highlight(fighter.player_index, &"elemental", "Interação %s com %s" % [String(interaction_id).to_upper(), String(element_id).to_upper()], 1.0)

func _on_loot_collected(fighter: FighterController, loot_type: StringName, item_id: StringName) -> void:
	if is_instance_valid(fighter):
		_increment_stat(fighter.player_index, &"loot_collected", 1.0)
		_append_highlight(fighter.player_index, &"loot", "Coleta %s: %s" % [String(loot_type).to_upper(), String(item_id).to_upper()], 1.0)

func _append_highlight(player_index: int, event_id: StringName, label: String, value: float = 0.0) -> void:
	if _current_round.is_empty() or player_index not in [1, 2]:
		return
	var highlights: Array = _current_round.get("highlights", [])
	if highlights.size() >= MAX_HIGHLIGHTS_PER_ROUND:
		return
	var elapsed := maxf(0.0, float(Time.get_ticks_msec() - _round_started_msec) / 1000.0)
	highlights.append({
		"time_seconds": elapsed,
		"player_index": player_index,
		"event_id": String(event_id),
		"label": label.left(96),
		"value": value
	})
	_current_round["highlights"] = highlights

func _increment_stat(player_index: int, stat_id: StringName, amount: float) -> void:
	if _current_round.is_empty() or player_index not in [1, 2]:
		return
	var stats: Array = _current_round.get("stats", [_empty_stats(), _empty_stats()])
	while stats.size() < 2:
		stats.append(_empty_stats())
	var player_stats: Dictionary = stats[player_index - 1]
	var key := String(stat_id)
	player_stats[key] = float(player_stats.get(key, 0.0)) + amount
	stats[player_index - 1] = player_stats
	_current_round["stats"] = stats

func _accumulate_totals(round_stats: Array) -> void:
	var totals: Array = _series.get("totals", [_empty_stats(), _empty_stats()])
	while totals.size() < 2:
		totals.append(_empty_stats())
	for index in range(mini(2, round_stats.size())):
		if not (round_stats[index] is Dictionary):
			continue
		var total: Dictionary = totals[index]
		var round_data: Dictionary = round_stats[index]
		for key in round_data.keys():
			total[String(key)] = float(total.get(String(key), 0.0)) + float(round_data[key])
		totals[index] = total
	_series["totals"] = totals

func _player_record(player_index: int, loadout: Dictionary, profile_context: Dictionary = {}) -> Dictionary:
	var clean := BattleLoadoutCatalog.sanitize(loadout)
	var build := BuildProfile.prototype_preset(StringName(clean.get("preset_id", &"adaptive_staff")))
	return {
		"player_index": player_index,
		"profile_id": String(profile_context.get("profile_id", "profile_p%d" % player_index)),
		"profile_name": PlayerProfileLedger.sanitize_name(String(profile_context.get("profile_name", "JOGADOR %d" % player_index)), "JOGADOR %d" % player_index),
		"character_id": String(build.character_id),
		"character_name": build.character_name,
		"build_name": build.display_name,
		"loadout": clean
	}

func _resource_snapshot(fighter: FighterController) -> Dictionary:
	if not is_instance_valid(fighter):
		return {}
	return {
		"health": fighter.health,
		"health_ratio": fighter.health / maxf(1.0, fighter.build.max_health()),
		"posture": fighter.posture,
		"posture_ratio": fighter.posture / maxf(1.0, fighter.build.max_posture()),
		"stamina": fighter.stamina
	}

func _empty_stats() -> Dictionary:
	return {
		"contacts": 0.0,
		"hits": 0.0,
		"damage_dealt": 0.0,
		"posture_damage": 0.0,
		"blocked_contacts": 0.0,
		"parried_contacts": 0.0,
		"evaded_contacts": 0.0,
		"parries": 0.0,
		"posture_breaks": 0.0,
		"disarms": 0.0,
		"grabs": 0.0,
		"elemental_interactions": 0.0,
		"loot_collected": 0.0
	}
