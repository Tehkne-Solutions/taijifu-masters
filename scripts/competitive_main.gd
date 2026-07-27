extends "res://scripts/main.gd"

@onready var competitive_runtime: CompetitiveMatchRuntime = $CompetitiveMatchRuntime
@onready var competitive_arena_runtime: CompetitiveArenaRuntime = $CompetitiveArenaRuntime
@onready var vs_analysis_runtime: VsAnalysisRuntime = $VsAnalysisRuntime
@onready var statistics_runtime: SeriesStatisticsRuntime = $SeriesStatisticsRuntime
@onready var history_runtime: MatchHistoryRuntime = $MatchHistoryRuntime
@onready var tournament_runtime: TournamentRuntime = $TournamentRuntime
@onready var player_profile_runtime: PlayerProfileRuntime = $PlayerProfileRuntime

func _ready() -> void:
	super._ready()
	competitive_runtime.round_timeout.connect(_on_round_timeout)

func _start_battle() -> void:
	if _state != MatchState.PREPARATION or not preparation_runtime.all_players_ready():
		return
	_sync_legacy_preparation_state()
	var p1_loadout := preparation_runtime.loadout_for_player(1)
	var p2_loadout := preparation_runtime.loadout_for_player(2)
	preparation_runtime.close()
	competitive_runtime.begin_series(p1_loadout, p2_loadout)
	statistics_runtime.begin_series(
		competitive_runtime.current_config(),
		p1_loadout,
		p2_loadout,
		player_profile_runtime.profile_context_for_player(1),
		player_profile_runtime.profile_context_for_player(2)
	)
	competitive_arena_runtime.configure(competitive_runtime.resolved_arena_rules())
	competitive_arena_runtime.update_score_visual(competitive_runtime.score_snapshot())
	_state = MatchState.ENTRANCE
	var running_headless := DisplayServer.get_name() == "headless" or OS.has_feature("server")
	if not running_headless:
		center_label.text = "LEITURA DO CONFRONTO"
		controls_label.text = "Compare vantagens e riscos antes da entrada."
		vs_analysis_runtime.play(p1_loadout, p2_loadout, competitive_runtime.current_config())
		await vs_analysis_runtime.analysis_finished
		if _state != MatchState.ENTRANCE:
			return
	_cleanup_temporary_loot()
	competitive_arena_runtime.prepare_round()
	_spawn_fighters()
	await _play_round_entrance()

func _play_round_entrance() -> void:
	_state = MatchState.ENTRANCE
	center_label.text = "ENTRADA NA ARENA"
	controls_label.text = "Controles bloqueados até o comando LUTEM."
	entrance_runtime.play(player_one, player_two)
	await entrance_runtime.entrance_finished
	if _state != MatchState.ENTRANCE:
		return
	competitive_arena_runtime.start_round()
	competitive_runtime.start_round(player_one, player_two)
	statistics_runtime.begin_round(
		player_one,
		player_two,
		int(competitive_runtime.score_snapshot().get("round_number", 1))
	)
	competitive_arena_runtime.update_score_visual(competitive_runtime.score_snapshot())
	_state = MatchState.BATTLE
	center_label.text = _arena_header()
	controls_label.text = "P1: A/D • W salto • S queda • Q esquiva • F técnica • G empurrão • E agarrão • C elemento • H eco • R defesa\nP2: Setas • Num0 esquiva • Num1 técnica • Num2 empurrão • Num4 agarrão • Num6 elemento • Num5 eco • Num3 defesa\nGamepads: analógico move • A salto • B esquiva • X técnica • Y empurrão • LB agarrão • RB defesa"

func _on_fighter_defeated(defeated_fighter: FighterController) -> void:
	if _resetting_round or _state != MatchState.BATTLE:
		return
	var winner_index := 2 if defeated_fighter.player_index == 1 else 1
	_resolve_competitive_round(winner_index, "KO")

func _on_round_timeout(winner_index: int, reason: String) -> void:
	if _resetting_round or _state != MatchState.BATTLE:
		return
	_resolve_competitive_round(winner_index, reason)

func _resolve_competitive_round(winner_index: int, reason: String) -> void:
	_resetting_round = true
	_message_sequence += 1
	competitive_runtime.stop_round()
	competitive_arena_runtime.stop_round()
	statistics_runtime.complete_round(winner_index, reason, player_one, player_two)
	var winner_name := player_one.build.character_name.to_upper() if winner_index == 1 else player_two.build.character_name.to_upper()
	center_label.text = "%s VENCE O ROUND • %s" % [winner_name, reason]
	await get_tree().create_timer(1.15).timeout
	var result := competitive_runtime.record_round(winner_index, reason)
	competitive_arena_runtime.update_score_visual(competitive_runtime.score_snapshot())
	if bool(result.get("match_over", false)):
		center_label.text = "%s VENCE A SÉRIE\n%d — %d" % [
			String(result.get("winner_name", winner_name)),
			int(result.get("score_p1", 0)),
			int(result.get("score_p2", 0))
		]
		var series_record := statistics_runtime.complete_series(
			int(result.get("score_p1", 0)),
			int(result.get("score_p2", 0)),
			winner_index
		)
		var tournament_result: Dictionary = {}
		if tournament_runtime.is_tournament_active():
			tournament_result = tournament_runtime.record_series_winner(winner_index)
		history_runtime.play_result(series_record)
		await history_runtime.result_finished
		_cleanup_temporary_loot()
		competitive_arena_runtime.prepare_round()
		_cleanup_fighters()
		competitive_runtime.reset_series()
		competitive_arena_runtime.update_score_visual(competitive_runtime.score_snapshot())
		_resetting_round = false
		_enter_preparation()
		if bool(tournament_result.get("ok", false)):
			if bool(tournament_result.get("finished", false)):
				controls_label.text = "TORNEIO CONCLUÍDO • CAMPEÃO: %s • F10 abre o chaveamento." % tournament_runtime.champion_name()
			else:
				tournament_runtime.prepare_current_match()
				controls_label.text = "%s • confirme os dois competidores para iniciar." % tournament_runtime.ledger.stage_label()
		else:
			controls_label.text = "Configure loadouts • F2 presets • F3 histórico • F8 ranking • F9 perfis • F10 torneio."
		return
	_cleanup_temporary_loot()
	competitive_arena_runtime.prepare_round()
	player_one.reset_fighter(arena.respawn_point(1))
	player_two.reset_fighter(arena.respawn_point(2))
	center_label.text = "ROUND %d\nADAPTE-SE" % int(competitive_runtime.score_snapshot().get("round_number", 2))
	await get_tree().create_timer(0.65).timeout
	_resetting_round = false
	await _play_round_entrance()

func _cleanup_fighters() -> void:
	if is_instance_valid(player_one):
		player_one.queue_free()
	if is_instance_valid(player_two):
		player_two.queue_free()
	player_one = null
	player_two = null

func _show_combat_event(message: String, duration: float) -> void:
	_message_sequence += 1
	var sequence := _message_sequence
	center_label.text = message
	await get_tree().create_timer(duration).timeout
	if sequence == _message_sequence and not _resetting_round:
		center_label.text = _arena_header()

func _arena_header() -> String:
	return "%s\nTAI • JI • FU" % competitive_runtime.arena_title()
