class_name InputGhostMasteryRuntime
extends Node

const PROFILE_PATH := "user://input-ghost-mastery.json"
const BEST_RECORDING_PATH := "user://input-ghost-best.json"
const BRIDGE_VERSION := 1
const MAX_RECORDING_MS := 12000
const LINK_WINDOW_MS := 720
const ACTION_SUFFIXES := ["left", "right", "down", "jump", "dodge", "attack", "push", "grab", "block", "element", "echo", "swap"]
const PATHS := ["tai", "ji", "fu"]
const CERTIFICATION_LABELS := {
	"none": "EM FORMAÇÃO",
	"initiated": "INICIADO",
	"disciple": "DISCÍPULO",
	"master": "MESTRE"
}

var profile: Dictionary = {}
var best_recording: Dictionary = {}
var current_recording: Dictionary = {}
var _recording_active := false
var _record_start_ms := 0
var _record_frames: Array = []
var _record_events: Array = []
var _attempt: Dictionary = {}
var _path_last_at: Dictionary = {}
var _path_chain: Dictionary = {}
var _fighters: Dictionary = {}
var _connected_fighters: Dictionary = {}
var _discover_timer := 0.0
var _web_timer := 0.0
var _overlay_timer := 0.0
var _known_cancel_success := 0
var _callbacks: Array = []
var _window: JavaScriptObject
var _ghost: InputGhostVisual
var _canvas: CanvasLayer
var _overlay: ColorRect
var _overlay_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _default_profile()
	_attempt = _default_attempt()
	_load_profile()
	_load_best_recording()
	_register_actions()
	_create_overlay()
	_register_web_bridge()
	call_deferred("_discover_scene")

func _physics_process(delta: float) -> void:
	_discover_timer -= delta
	_web_timer -= delta
	_overlay_timer -= delta
	if _discover_timer <= 0.0:
		_discover_timer = 0.40
		_discover_scene()
	if _recording_active:
		_capture_frame()
		_detect_cancel_progress()
		if Time.get_ticks_msec() - _record_start_ms >= MAX_RECORDING_MS:
			stop_recording("Limite de 12 segundos concluído.")
	if _overlay_timer <= 0.0:
		_overlay_timer = 0.08
		_refresh_overlay()
	if _web_timer <= 0.0:
		_web_timer = 0.35
		_sync_web_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F6:
				if _recording_active:
					stop_recording("Gravação encerrada pelo atalho F6.")
				else:
					start_recording()
			KEY_F7:
				play_best_recording()
			KEY_F8:
				stop_playback()

func _default_profile() -> Dictionary:
	var styles := {}
	for path_id in PATHS:
		styles[path_id] = _default_style_entry(path_id)
	return {
		"version": BRIDGE_VERSION,
		"styles": styles,
		"challenges": {},
		"certifications": {},
		"best_summary": {},
		"sessions": 0,
		"show_overlay": true
	}

func _default_style_entry(path_id: String) -> Dictionary:
	return {
		"path": path_id,
		"xp": 0.0,
		"uses": 0,
		"hits": 0,
		"blocked": 0,
		"parried": 0,
		"evaded": 0,
		"parries": 0,
		"cancels": 0,
		"best_chain": 0,
		"best_accuracy": 0.0,
		"best_link_ms": 0.0,
		"certification": "none"
	}

func _default_attempt() -> Dictionary:
	var paths := {}
	for path_id in PATHS:
		paths[path_id] = {
			"attempts": 0,
			"hits": 0,
			"max_chain": 0,
			"link_gaps_ms": []
		}
	return {
		"attempts": 0,
		"hits": 0,
		"max_chain": 0,
		"current_chain": 0,
		"parries": 0,
		"cancels": 0,
		"link_gaps_ms": [],
		"last_technique_at": 0,
		"last_event": "",
		"paths": paths
	}

func _sanitize_profile(value: Variant) -> Dictionary:
	var clean := _default_profile()
	if not value is Dictionary:
		return clean
	var source: Dictionary = value
	clean["sessions"] = maxi(0, int(source.get("sessions", 0)))
	clean["show_overlay"] = bool(source.get("show_overlay", true))
	var best = source.get("best_summary", {})
	clean["best_summary"] = best.duplicate(true) if best is Dictionary else {}
	var styles_source: Dictionary = source.get("styles", {})
	for path_id in PATHS:
		var style_source = styles_source.get(path_id, {})
		if style_source is Dictionary:
			clean["styles"][path_id] = _sanitize_style(path_id, style_source as Dictionary)
	var challenges_source: Dictionary = source.get("challenges", {})
	for technique_id in challenges_source.keys():
		var challenge_source = challenges_source[technique_id]
		if challenge_source is Dictionary:
			clean["challenges"][String(technique_id)] = _sanitize_challenge(String(technique_id), challenge_source as Dictionary)
	_update_all_certifications(clean)
	return clean

func _sanitize_style(path_id: String, value: Dictionary) -> Dictionary:
	var style := _default_style_entry(path_id)
	for key in ["xp", "best_accuracy", "best_link_ms"]:
		style[key] = maxf(0.0, float(value.get(key, style[key])))
	for key in ["uses", "hits", "blocked", "parried", "evaded", "parries", "cancels", "best_chain"]:
		style[key] = maxi(0, int(value.get(key, style[key])))
	style["best_accuracy"] = clampf(float(style["best_accuracy"]), 0.0, 1.0)
	style["certification"] = String(value.get("certification", "none"))
	return style

func _sanitize_challenge(technique_id: String, value: Dictionary) -> Dictionary:
	var path_id := String(value.get("path", "fu"))
	if path_id not in PATHS:
		path_id = "fu"
	return {
		"technique_id": technique_id,
		"display_name": String(value.get("display_name", technique_id)),
		"path": path_id,
		"attempts": maxi(0, int(value.get("attempts", 0))),
		"hits": maxi(0, int(value.get("hits", 0))),
		"best_chain": maxi(0, int(value.get("best_chain", 0))),
		"fastest_link_ms": maxf(0.0, float(value.get("fastest_link_ms", 0.0))),
		"tier": clampi(int(value.get("tier", 0)), 0, 3)
	}

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file != null:
		profile = _sanitize_profile(JSON.parse_string(file.get_as_text()))

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile, "  "))

func _load_best_recording() -> void:
	if not FileAccess.file_exists(BEST_RECORDING_PATH):
		best_recording = {}
		return
	var file := FileAccess.open(BEST_RECORDING_PATH, FileAccess.READ)
	if file == null:
		best_recording = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	best_recording = parsed if parsed is Dictionary else {}

func _save_best_recording() -> void:
	var file := FileAccess.open(BEST_RECORDING_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(best_recording))

func _register_actions() -> void:
	_register_key(&"ghost_record", KEY_F6)
	_register_key(&"ghost_play", KEY_F7)
	_register_key(&"ghost_stop", KEY_F8)

func _register_key(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)

func start_recording() -> bool:
	_discover_scene()
	var fighter = _fighters.get(1)
	if not is_instance_valid(fighter):
		return false
	stop_playback()
	_record_frames.clear()
	_record_events.clear()
	_attempt = _default_attempt()
	_path_last_at.clear()
	_path_chain.clear()
	_record_start_ms = Time.get_ticks_msec()
	_known_cancel_success = _controller_cancel_success()
	_recording_active = true
	current_recording = {}
	_capture_frame()
	_attempt["last_event"] = "Gravação iniciada."
	return true

func stop_recording(message: String = "") -> Dictionary:
	if not _recording_active:
		return current_recording
	_capture_frame()
	_detect_cancel_progress()
	_recording_active = false
	var duration_ms := maxi(0, Time.get_ticks_msec() - _record_start_ms)
	var summary := _summary_from_attempt(_attempt, duration_ms)
	current_recording = {
		"version": BRIDGE_VERSION,
		"created_unix": int(Time.get_unix_time_from_system()),
		"duration_ms": duration_ms,
		"frames": _record_frames.duplicate(true),
		"events": _record_events.duplicate(true),
		"summary": summary,
		"message": message
	}
	profile["sessions"] = int(profile.get("sessions", 0)) + 1
	_apply_attempt_to_styles(summary)
	var previous_best: Dictionary = profile.get("best_summary", {})
	if previous_best.is_empty() or float(summary.get("score", 0.0)) > float(previous_best.get("score", 0.0)):
		profile["best_summary"] = summary.duplicate(true)
		best_recording = current_recording.duplicate(true)
		_save_best_recording()
	_save_profile()
	_sync_web_state()
	return current_recording

func clear_best_recording() -> void:
	best_recording = {}
	profile["best_summary"] = {}
	if FileAccess.file_exists(BEST_RECORDING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BEST_RECORDING_PATH))
	_save_profile()

func play_best_recording() -> bool:
	if best_recording.is_empty():
		return false
	var frames: Array = best_recording.get("frames", [])
	if frames.size() < 2:
		return false
	_discover_scene()
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	if not is_instance_valid(_ghost):
		_ghost = InputGhostVisual.new()
		scene.add_child(_ghost)
		_ghost.playback_finished.connect(_on_ghost_finished)
	return _ghost.play(frames)

func stop_playback() -> void:
	if is_instance_valid(_ghost):
		_ghost.stop()

func _on_ghost_finished() -> void:
	_sync_web_state()

func _capture_frame() -> void:
	var fighter = _fighters.get(1)
	if not is_instance_valid(fighter):
		return
	var elapsed := maxi(0, Time.get_ticks_msec() - _record_start_ms)
	var inputs := {}
	for suffix in ACTION_SUFFIXES:
		var action_id := StringName("p1_%s" % suffix)
		if not InputMap.has_action(action_id):
			continue
		var strength := Input.get_action_strength(action_id)
		if strength > 0.001:
			inputs[suffix] = snappedf(strength, 0.001)
	var position: Vector2 = fighter.global_position
	var velocity: Vector2 = fighter.velocity
	_record_frames.append({
		"t": elapsed,
		"position": [snappedf(position.x, 0.01), snappedf(position.y, 0.01)],
		"velocity": [snappedf(velocity.x, 0.01), snappedf(velocity.y, 0.01)],
		"facing": float(fighter.get("facing")),
		"phase": int(fighter.get("_attack_phase")),
		"technique": String(fighter.get("_last_technique_id")),
		"weapon": String(fighter.get("equipped_weapon_id")),
		"inputs": inputs
	})

func _discover_scene() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	for player_index in [1, 2]:
		var fighter = scene.get("player_one") if player_index == 1 else scene.get("player_two")
		if fighter is FighterController:
			_fighters[player_index] = fighter
			_connect_fighter(fighter)

func _connect_fighter(fighter: FighterController) -> void:
	var instance_id := fighter.get_instance_id()
	if _connected_fighters.has(instance_id):
		return
	_connected_fighters[instance_id] = true
	if fighter.has_signal("technique_started"):
		fighter.connect("technique_started", Callable(self, "_on_technique_started"))
	if fighter.has_signal("technique_experienced"):
		fighter.connect("technique_experienced", Callable(self, "_on_technique_experienced"))
	if fighter.has_signal("parry_performed"):
		fighter.connect("parry_performed", Callable(self, "_on_parry_performed"))
	if fighter.has_signal("weapon_swapped"):
		fighter.connect("weapon_swapped", Callable(self, "_on_weapon_swapped"))

func _on_technique_started(fighter: FighterController, technique_id: StringName) -> void:
	if fighter.player_index != 1:
		return
	var technique := TechniqueCatalog.get_technique(technique_id)
	var path_id := technique.path if technique.path in PATHS else "fu"
	_record_style_event(path_id, "uses", 1.0)
	_record_challenge_attempt(technique_id, technique, path_id)
	if not _recording_active:
		_save_profile()
		return
	var now := Time.get_ticks_msec()
	var last := int(_attempt.get("last_technique_at", 0))
	var gap := now - last if last > 0 else LINK_WINDOW_MS + 1
	var chain := int(_attempt.get("current_chain", 0))
	if gap <= LINK_WINDOW_MS:
		chain += 1
		(_attempt["link_gaps_ms"] as Array).append(gap)
	else:
		chain = 1
	_attempt["current_chain"] = chain
	_attempt["max_chain"] = maxi(int(_attempt.get("max_chain", 0)), chain)
	_attempt["attempts"] = int(_attempt.get("attempts", 0)) + 1
	_attempt["last_technique_at"] = now
	_attempt["last_event"] = "%s • elo %d" % [technique.display_name, chain]
	var path_entry: Dictionary = (_attempt["paths"] as Dictionary)[path_id]
	var path_last := int(_path_last_at.get(path_id, 0))
	var path_gap := now - path_last if path_last > 0 else LINK_WINDOW_MS + 1
	var path_chain_value := int(_path_chain.get(path_id, 0))
	if path_gap <= LINK_WINDOW_MS:
		path_chain_value += 1
		(path_entry["link_gaps_ms"] as Array).append(path_gap)
	else:
		path_chain_value = 1
	path_entry["attempts"] = int(path_entry.get("attempts", 0)) + 1
	path_entry["max_chain"] = maxi(int(path_entry.get("max_chain", 0)), path_chain_value)
	(_attempt["paths"] as Dictionary)[path_id] = path_entry
	_path_last_at[path_id] = now
	_path_chain[path_id] = path_chain_value
	_record_events.append({"t": now - _record_start_ms, "type": "technique", "id": String(technique_id), "path": path_id, "gap_ms": gap})
	_update_challenge_chain(technique_id, chain, gap)

func _on_technique_experienced(_defender: FighterController, attacker: FighterController, technique_id: StringName, outcome_id: StringName) -> void:
	if not is_instance_valid(attacker) or attacker.player_index != 1:
		return
	var technique := TechniqueCatalog.get_technique(technique_id)
	var path_id := technique.path if technique.path in PATHS else "fu"
	_record_style_event(path_id, String(outcome_id), 1.0)
	_record_challenge_outcome(technique_id, technique, path_id, outcome_id)
	if _recording_active:
		if outcome_id == &"hit":
			_attempt["hits"] = int(_attempt.get("hits", 0)) + 1
			var path_entry: Dictionary = (_attempt["paths"] as Dictionary)[path_id]
			path_entry["hits"] = int(path_entry.get("hits", 0)) + 1
			(_attempt["paths"] as Dictionary)[path_id] = path_entry
		_attempt["last_event"] = "%s • %s" % [technique.display_name, String(outcome_id)]
		_record_events.append({"t": Time.get_ticks_msec() - _record_start_ms, "type": "outcome", "id": String(technique_id), "path": path_id, "outcome": String(outcome_id)})
	else:
		_save_profile()

func _on_parry_performed(fighter: FighterController) -> void:
	if fighter.player_index != 1:
		return
	_record_style_event("ji", "parries", 1.0)
	if _recording_active:
		_attempt["parries"] = int(_attempt.get("parries", 0)) + 1
		_attempt["last_event"] = "Aparo confirmado."
		_record_events.append({"t": Time.get_ticks_msec() - _record_start_ms, "type": "parry"})
	else:
		_save_profile()

func _on_weapon_swapped(fighter: FighterController, _from_weapon_id: StringName, to_weapon_id: StringName, _slot_id: int) -> void:
	if fighter.player_index == 1 and _recording_active:
		_record_events.append({"t": Time.get_ticks_msec() - _record_start_ms, "type": "weapon", "weapon": String(to_weapon_id)})

func _detect_cancel_progress() -> void:
	var current := _controller_cancel_success()
	if current <= _known_cancel_success:
		return
	var difference := current - _known_cancel_success
	_known_cancel_success = current
	_attempt["cancels"] = int(_attempt.get("cancels", 0)) + difference
	_record_style_event("tai", "cancels", float(difference))
	_record_events.append({"t": Time.get_ticks_msec() - _record_start_ms, "type": "cancel", "count": difference})

func _controller_cancel_success() -> int:
	var mastery := get_tree().root.get_node_or_null("TaijifuControllerMastery")
	if is_instance_valid(mastery) and mastery.has_method("current_state"):
		var state: Dictionary = mastery.current_state()
		return int(state.get("metrics", {}).get("cancel_success", 0))
	return 0

func _record_style_event(path_id: String, event_id: String, amount: float) -> void:
	if path_id not in PATHS:
		return
	var styles: Dictionary = profile.get("styles", {})
	var style: Dictionary = styles.get(path_id, _default_style_entry(path_id))
	var count := maxi(1, int(round(amount)))
	var xp_gain := 0.0
	match event_id:
		"uses":
			style["uses"] = int(style.get("uses", 0)) + count
			xp_gain = 1.0 * amount
		"hit":
			style["hits"] = int(style.get("hits", 0)) + count
			xp_gain = 4.0 * amount
		"blocked":
			style["blocked"] = int(style.get("blocked", 0)) + count
			xp_gain = 2.0 * amount
		"parried":
			style["parried"] = int(style.get("parried", 0)) + count
			xp_gain = 0.8 * amount
		"evaded":
			style["evaded"] = int(style.get("evaded", 0)) + count
			xp_gain = 0.4 * amount
		"parries":
			style["parries"] = int(style.get("parries", 0)) + count
			xp_gain = 3.0 * amount
		"cancels":
			style["cancels"] = int(style.get("cancels", 0)) + count
			xp_gain = 3.0 * amount
	style["xp"] = maxf(0.0, float(style.get("xp", 0.0)) + xp_gain)
	styles[path_id] = style
	profile["styles"] = styles
	_update_certification(path_id)

func _record_challenge_attempt(technique_id: StringName, technique: TechniqueData, path_id: String) -> void:
	var challenge := _challenge_entry(technique_id, technique, path_id)
	challenge["attempts"] = int(challenge.get("attempts", 0)) + 1
	profile["challenges"][String(technique_id)] = challenge
	_evaluate_challenge(String(technique_id))

func _record_challenge_outcome(technique_id: StringName, technique: TechniqueData, path_id: String, outcome_id: StringName) -> void:
	var challenge := _challenge_entry(technique_id, technique, path_id)
	if outcome_id == &"hit":
		challenge["hits"] = int(challenge.get("hits", 0)) + 1
	profile["challenges"][String(technique_id)] = challenge
	_evaluate_challenge(String(technique_id))

func _update_challenge_chain(technique_id: StringName, chain: int, gap_ms: int) -> void:
	var key := String(technique_id)
	if not profile["challenges"].has(key):
		return
	var challenge: Dictionary = profile["challenges"][key]
	challenge["best_chain"] = maxi(int(challenge.get("best_chain", 0)), chain)
	if gap_ms <= LINK_WINDOW_MS:
		var fastest := float(challenge.get("fastest_link_ms", 0.0))
		challenge["fastest_link_ms"] = float(gap_ms) if fastest <= 0.0 else minf(fastest, float(gap_ms))
	profile["challenges"][key] = challenge
	_evaluate_challenge(key)

func _challenge_entry(technique_id: StringName, technique: TechniqueData, path_id: String) -> Dictionary:
	var key := String(technique_id)
	var challenges: Dictionary = profile.get("challenges", {})
	if challenges.has(key):
		return challenges[key]
	var challenge := {
		"technique_id": key,
		"display_name": technique.display_name if technique.display_name != "" else key,
		"path": path_id,
		"attempts": 0,
		"hits": 0,
		"best_chain": 0,
		"fastest_link_ms": 0.0,
		"tier": 0
	}
	challenges[key] = challenge
	profile["challenges"] = challenges
	return challenge

func _evaluate_challenge(technique_id: String) -> int:
	var challenge: Dictionary = profile.get("challenges", {}).get(technique_id, {})
	if challenge.is_empty():
		return 0
	var attempts := int(challenge.get("attempts", 0))
	var hits := int(challenge.get("hits", 0))
	var accuracy := float(hits) / float(maxi(1, attempts))
	var tier := 0
	if attempts >= 5 and hits >= 2:
		tier = 1
	if attempts >= 12 and hits >= 6 and int(challenge.get("best_chain", 0)) >= 3:
		tier = 2
	var fastest := float(challenge.get("fastest_link_ms", 0.0))
	if attempts >= 25 and hits >= 15 and accuracy >= 0.65 and fastest > 0.0 and fastest <= 550.0:
		tier = 3
	challenge["tier"] = tier
	profile["challenges"][technique_id] = challenge
	_update_certification(String(challenge.get("path", "fu")))
	return tier

func _apply_attempt_to_styles(summary: Dictionary) -> void:
	var styles: Dictionary = profile.get("styles", {})
	var paths: Dictionary = _attempt.get("paths", {})
	for path_id in PATHS:
		var path_attempt: Dictionary = paths.get(path_id, {})
		var style: Dictionary = styles.get(path_id, _default_style_entry(path_id))
		var attempts := int(path_attempt.get("attempts", 0))
		var hits := int(path_attempt.get("hits", 0))
		var accuracy := float(hits) / float(maxi(1, attempts))
		style["best_chain"] = maxi(int(style.get("best_chain", 0)), int(path_attempt.get("max_chain", 0)))
		style["best_accuracy"] = maxf(float(style.get("best_accuracy", 0.0)), accuracy)
		var link := _minimum_positive(path_attempt.get("link_gaps_ms", []))
		if link > 0.0:
			var existing := float(style.get("best_link_ms", 0.0))
			style["best_link_ms"] = link if existing <= 0.0 else minf(existing, link)
		styles[path_id] = style
	profile["styles"] = styles
	for path_id in PATHS:
		_update_certification(path_id)

func _update_all_certifications(target_profile: Dictionary = profile) -> void:
	var previous := profile
	profile = target_profile
	for path_id in PATHS:
		_update_certification(path_id)
	profile = target_profile if target_profile != previous else previous

func _update_certification(path_id: String) -> String:
	if path_id not in PATHS:
		return "none"
	var styles: Dictionary = profile.get("styles", {})
	var style: Dictionary = styles.get(path_id, _default_style_entry(path_id))
	var level := "none"
	var xp := float(style.get("xp", 0.0))
	var uses := int(style.get("uses", 0))
	var hits := int(style.get("hits", 0))
	var chain := int(style.get("best_chain", 0))
	var accuracy := float(style.get("best_accuracy", 0.0))
	if xp >= 40.0 and uses >= 8 and hits >= 3:
		level = "initiated"
	if xp >= 120.0 and uses >= 20 and hits >= 10 and chain >= 3 and accuracy >= 0.45:
		level = "disciple"
	var master_ready := xp >= 300.0 and uses >= 45 and hits >= 24 and chain >= 4 and accuracy >= 0.60
	match path_id:
		"tai":
			master_ready = master_ready and int(style.get("cancels", 0)) >= 2 and float(style.get("best_link_ms", 0.0)) > 0.0 and float(style.get("best_link_ms", 0.0)) <= 560.0
		"ji":
			master_ready = master_ready and int(style.get("parries", 0)) >= 3
		"fu":
			master_ready = master_ready and accuracy >= 0.68 and _completed_challenges_for_path("fu") >= 2
	if master_ready:
		level = "master"
	style["certification"] = level
	styles[path_id] = style
	profile["styles"] = styles
	profile["certifications"][path_id] = level
	return level

func _completed_challenges_for_path(path_id: String) -> int:
	var total := 0
	for challenge_value in profile.get("challenges", {}).values():
		if challenge_value is Dictionary:
			var challenge: Dictionary = challenge_value
			if String(challenge.get("path", "")) == path_id and int(challenge.get("tier", 0)) >= 2:
				total += 1
	return total

func _summary_from_attempt(attempt: Dictionary, duration_ms: int) -> Dictionary:
	var attempts := int(attempt.get("attempts", 0))
	var hits := int(attempt.get("hits", 0))
	var accuracy := float(hits) / float(maxi(1, attempts))
	var gaps: Array = attempt.get("link_gaps_ms", [])
	var average_link := _average(gaps)
	var consistency := _standard_deviation(gaps)
	var max_chain := int(attempt.get("max_chain", 0))
	var parries := int(attempt.get("parries", 0))
	var cancels := int(attempt.get("cancels", 0))
	var speed_factor := 0.0 if average_link <= 0.0 else clampf(1.0 - average_link / float(LINK_WINDOW_MS), 0.0, 1.0)
	var consistency_factor := 0.0 if gaps.size() < 2 else clampf(1.0 - consistency / 240.0, 0.0, 1.0)
	var score := accuracy * 320.0
	score += minf(1.0, float(max_chain) / 6.0) * 220.0
	score += speed_factor * 180.0
	score += consistency_factor * 120.0
	score += minf(3.0, float(parries)) * 30.0
	score += minf(3.0, float(cancels)) * 30.0
	return {
		"duration_ms": duration_ms,
		"attempts": attempts,
		"hits": hits,
		"accuracy": accuracy,
		"max_chain": max_chain,
		"average_link_ms": average_link,
		"consistency_ms": consistency,
		"parries": parries,
		"cancels": cancels,
		"score": roundi(score),
		"last_event": String(attempt.get("last_event", ""))
	}

func _comparison() -> Dictionary:
	var current: Dictionary = current_recording.get("summary", {})
	var best: Dictionary = profile.get("best_summary", {})
	if current.is_empty() or best.is_empty():
		return {"available": false, "current": current, "best": best, "deltas": {}}
	return {
		"available": true,
		"current": current,
		"best": best,
		"better": float(current.get("score", 0.0)) >= float(best.get("score", 0.0)),
		"deltas": {
			"score": float(current.get("score", 0.0)) - float(best.get("score", 0.0)),
			"accuracy": float(current.get("accuracy", 0.0)) - float(best.get("accuracy", 0.0)),
			"max_chain": int(current.get("max_chain", 0)) - int(best.get("max_chain", 0)),
			"average_link_ms": float(current.get("average_link_ms", 0.0)) - float(best.get("average_link_ms", 0.0)),
			"consistency_ms": float(current.get("consistency_ms", 0.0)) - float(best.get("consistency_ms", 0.0))
		}
	}

func _weapon_mastery_state() -> Dictionary:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return {}
	var runtime := scene.get_node_or_null("WeaponMasteryRuntime")
	var fighter = _fighters.get(1)
	if not is_instance_valid(runtime) or not is_instance_valid(fighter):
		return {}
	var ledger = runtime.get("ledger")
	if ledger is WeaponMasteryLedger:
		var weapon_id: StringName = fighter.equipped_weapon_id
		var profiles: Dictionary = ledger.data.get("profiles", {})
		return {
			"current_weapon": String(weapon_id),
			"current": ledger.progress_for("p1", weapon_id),
			"entries": (profiles.get("p1", {}) as Dictionary).duplicate(true)
		}
	return {}

func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

func _standard_deviation(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var mean := _average(values)
	var total := 0.0
	for value in values:
		var difference := float(value) - mean
		total += difference * difference
	return sqrt(total / float(values.size()))

func _minimum_positive(values: Array) -> float:
	var selected := 0.0
	for value in values:
		var current := float(value)
		if current > 0.0 and (selected <= 0.0 or current < selected):
			selected = current
	return selected

func _create_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)
	_overlay = ColorRect.new()
	_overlay.anchor_left = 0.32
	_overlay.anchor_top = 0.155
	_overlay.anchor_right = 0.68
	_overlay.anchor_bottom = 0.225
	_overlay.color = Color(0.015, 0.027, 0.047, 0.88)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 12)
	_overlay_label.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	_overlay.add_child(_overlay_label)

func _refresh_overlay() -> void:
	if not is_instance_valid(_overlay):
		return
	var playback := is_instance_valid(_ghost) and _ghost.playing
	_overlay.visible = bool(profile.get("show_overlay", true)) and (_recording_active or playback or not current_recording.is_empty())
	if not _overlay.visible:
		return
	if _recording_active:
		var elapsed := Time.get_ticks_msec() - _record_start_ms
		_overlay_label.text = "● REC  %0.1f s  •  elo %d  •  acertos %d/%d  •  F6 encerra" % [float(elapsed) / 1000.0, int(_attempt.get("max_chain", 0)), int(_attempt.get("hits", 0)), int(_attempt.get("attempts", 0))]
	elif playback:
		var actions := ", ".join(_ghost.current_actions)
		_overlay_label.text = "◇ FANTASMA  %0.1f/%0.1f s  •  %s  •  F8 encerra" % [_ghost.elapsed_ms / 1000.0, _ghost.duration_ms / 1000.0, actions]
	else:
		var summary: Dictionary = current_recording.get("summary", {})
		_overlay_label.text = "TENTATIVA  %d pts  •  precisão %d%%  •  elo %d  •  F7 reproduz o melhor" % [int(summary.get("score", 0)), int(round(float(summary.get("accuracy", 0.0)) * 100.0)), int(summary.get("max_chain", 0))]

func current_state() -> Dictionary:
	var playback := {
		"active": is_instance_valid(_ghost) and _ghost.playing,
		"elapsed_ms": _ghost.elapsed_ms if is_instance_valid(_ghost) else 0.0,
		"duration_ms": _ghost.duration_ms if is_instance_valid(_ghost) else 0.0,
		"actions": _ghost.current_actions.duplicate() if is_instance_valid(_ghost) else []
	}
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"recording": {
			"active": _recording_active,
			"elapsed_ms": Time.get_ticks_msec() - _record_start_ms if _recording_active else int(current_recording.get("duration_ms", 0)),
			"frame_count": _record_frames.size() if _recording_active else (current_recording.get("frames", []) as Array).size(),
			"summary": current_recording.get("summary", {})
		},
		"best": {
			"available": not best_recording.is_empty(),
			"summary": profile.get("best_summary", {}),
			"frame_count": (best_recording.get("frames", []) as Array).size()
		},
		"playback": playback,
		"comparison": _comparison(),
		"styles": profile.get("styles", {}).duplicate(true),
		"certifications": _certification_state(),
		"challenges": profile.get("challenges", {}).duplicate(true),
		"weapon_mastery": _weapon_mastery_state(),
		"sessions": int(profile.get("sessions", 0)),
		"show_overlay": bool(profile.get("show_overlay", true))
	}

func _certification_state() -> Dictionary:
	var result := {}
	for path_id in PATHS:
		var style: Dictionary = profile.get("styles", {}).get(path_id, _default_style_entry(path_id))
		var level := String(style.get("certification", "none"))
		result[path_id] = {
			"level": level,
			"label": CERTIFICATION_LABELS.get(level, "EM FORMAÇÃO"),
			"requirements": _certification_requirements(path_id, style)
		}
	return result

func _certification_requirements(path_id: String, style: Dictionary) -> Dictionary:
	return {
		"xp": {"current": float(style.get("xp", 0.0)), "master": 300.0},
		"uses": {"current": int(style.get("uses", 0)), "master": 45},
		"hits": {"current": int(style.get("hits", 0)), "master": 24},
		"chain": {"current": int(style.get("best_chain", 0)), "master": 4},
		"accuracy": {"current": float(style.get("best_accuracy", 0.0)), "master": 0.60 if path_id != "fu" else 0.68},
		"special": _special_requirement(path_id, style)
	}

func _special_requirement(path_id: String, style: Dictionary) -> Dictionary:
	match path_id:
		"tai":
			return {"label": "2 cancels e link ≤ 560 ms", "current": "%d cancels • %d ms" % [int(style.get("cancels", 0)), int(style.get("best_link_ms", 0.0))]}
		"ji":
			return {"label": "3 aparos", "current": "%d aparos" % int(style.get("parries", 0))}
		"fu":
			return {"label": "2 desafios de domínio", "current": "%d desafios" % _completed_challenges_for_path("fu")}
	return {}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"start_recording":
			start_recording()
		&"stop_recording":
			stop_recording("Gravação encerrada pela interface Web.")
		&"play_best":
			play_best_recording()
		&"stop_playback":
			stop_playback()
		&"clear_best":
			clear_best_recording()
		&"set_overlay":
			profile["show_overlay"] = bool(request.get("enabled", true))
			_save_profile()
		&"reset_progress":
			profile = _default_profile()
			current_recording = {}
			clear_best_recording()
			_save_profile()
	return current_state()

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var command_callback := JavaScriptBridge.create_callback(_web_command)
	var state_callback := JavaScriptBridge.create_callback(_web_state)
	_callbacks = [command_callback, state_callback]
	_window.taijifuGhostMasteryCommand = command_callback
	_window.taijifuGhostMasteryState = state_callback
	_window.taijifuGhostMasteryVersion = BRIDGE_VERSION
	_window.taijifuGhostMasteryReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify(current_state())
	var parsed: Variant = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return JSON.stringify(current_state())
	return JSON.stringify(command(parsed as Dictionary))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGhostMasteryStateJson = JSON.stringify(current_state())
	_window.taijifuGhostMasteryReady = true

func summary_for_test(attempt: Dictionary, duration_ms: int) -> Dictionary:
	return _summary_from_attempt(attempt, duration_ms)

func compare_for_test(current: Dictionary, best: Dictionary) -> Dictionary:
	current_recording = {"summary": current}
	profile["best_summary"] = best
	return _comparison()

func record_style_event_for_test(path_id: String, event_id: String, amount: float = 1.0) -> String:
	_record_style_event(path_id, event_id, amount)
	return _update_certification(path_id)

func set_style_metrics_for_test(path_id: String, values: Dictionary) -> String:
	var style := _default_style_entry(path_id)
	for key in values.keys():
		style[key] = values[key]
	profile["styles"][path_id] = _sanitize_style(path_id, style)
	return _update_certification(path_id)

func record_challenge_for_test(technique_id: String, path_id: String, attempts: int, hits: int, chain: int, link_ms: float) -> int:
	profile["challenges"][technique_id] = {
		"technique_id": technique_id,
		"display_name": technique_id,
		"path": path_id,
		"attempts": attempts,
		"hits": hits,
		"best_chain": chain,
		"fastest_link_ms": link_ms,
		"tier": 0
	}
	return _evaluate_challenge(technique_id)

func set_best_recording_for_test(frames: Array, summary: Dictionary) -> bool:
	best_recording = {"frames": frames.duplicate(true), "summary": summary.duplicate(true), "duration_ms": int(summary.get("duration_ms", 0))}
	profile["best_summary"] = summary.duplicate(true)
	return (best_recording.get("frames", []) as Array).size() >= 2
