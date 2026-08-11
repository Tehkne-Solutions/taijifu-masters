extends SceneTree

func _initialize() -> void:
	var audio := FirstPlayableAudioDirector.new()
	var signature := audio.presentation_signature()
	if String(signature.get("stage", "")) != "AUDIO-04":
		_fail("AUDIO04_PRE_READY_SIGNATURE=BLOCKED stage")
		return
	if absf(float(signature.get("master_ceiling", 0.0)) - 0.86) > 0.001:
		_fail("AUDIO04_PRE_READY_SIGNATURE=BLOCKED ceiling=%s" % signature.get("master_ceiling", null))
		return
	if not bool(signature.get("final_mastering", false)):
		_fail("AUDIO04_PRE_READY_SIGNATURE=BLOCKED final_mastering")
		return
	if not bool(signature.get("accessibility_mix_controls", false)):
		_fail("AUDIO04_PRE_READY_SIGNATURE=BLOCKED accessibility")
		return
	if bool(signature.get("gameplay_timing_owner", true)) or bool(signature.get("damage_owner", true)) or bool(signature.get("ai_owner", true)):
		_fail("AUDIO04_PRE_READY_SIGNATURE=BLOCKED ownership")
		return
	print("AUDIO04_PRE_READY_SIGNATURE=PASS ceiling=0.86")
	print("SIGNATURE=Tehkné Solutions")
	audio.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	quit(2)

# Tehkné Solutions
