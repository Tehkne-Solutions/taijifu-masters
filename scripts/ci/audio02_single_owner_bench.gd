extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-AUDIO-02-OWNER")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.85).timeout
	for _frame in range(8):
		await process_frame

	var audio_nodes: Array[Node] = []
	_collect_audio_directors(battle, audio_nodes)
	if audio_nodes.size() != 1:
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED audio_director_count=%d" % audio_nodes.size(), battle)
		return
	var audio := audio_nodes[0] as FirstPlayableAudioDirector
	if audio == null or audio.name != "AudioDirector":
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED canonical_audio_node=%s" % str(audio_nodes[0].name), battle)
		return
	if audio.get_parent() != battle:
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED parent", battle)
		return

	var environment := battle.get_node_or_null("EnvironmentArt") as FirstPlayableEnvironmentArt
	if environment == null:
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED environment", battle)
		return
	var signature := environment.presentation_signature()
	if StringName(signature.get("audio_owner", &"")) != &"first_playable_scene":
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED owner_signature", battle)
		return
	if bool(signature.get("environment_installs_audio", true)):
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED environment_installs_audio", battle)
		return

	await process_frame
	var final_nodes: Array[Node] = []
	_collect_audio_directors(battle, final_nodes)
	if final_nodes.size() != 1:
		_fail("AUDIO02_SINGLE_OWNER=BLOCKED deferred_duplicate=%d" % final_nodes.size(), battle)
		return

	print("AUDIO02_AUDIO_DIRECTOR_COUNT=PASS count=1")
	print("AUDIO02_AUDIO_OWNER=PASS first_playable_scene")
	print("AUDIO02_ENVIRONMENT_AUDIO_INSTALL=PASS disabled")
	print("AUDIO02_SINGLE_OWNER=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _collect_audio_directors(node: Node, result: Array[Node]) -> void:
	if node is FirstPlayableAudioDirector:
		result.append(node)
	for child in node.get_children():
		_collect_audio_directors(child, result)

func _fail(message: String, battle: Node = null) -> void:
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
