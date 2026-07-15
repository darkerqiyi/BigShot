extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(5):
		await process_frame
	var audio = game.sfx
	_test_bus_layout(audio)
	_test_cue_catalog(audio)
	_test_music_flow(audio)
	_test_voice_limits(audio)
	_test_spatial_mix(audio)
	await _test_pause_mix_controls(game, audio)
	await _test_semantic_duck(audio)
	await _test_event_wiring(game, audio)
	_test_boss_music_transition(game, audio)
	game.queue_free()
	await process_frame
	_finish()


func _test_bus_layout(audio: Node) -> void:
	var contract: Dictionary = audio.get_audio_contract()
	_expect(contract["buses"] == [&"Master", &"Music", &"SFX", &"Weapons", &"Player", &"Enemies", &"Boss", &"UI"], "audio bus order is incomplete")
	_expect(int(contract["max_voices"]) == 20 and int(contract["music_players"]) == 2, "bounded voice/music deck contract changed")
	_expect(int(contract["cue_count"]) >= 55, "expanded semantic cue catalog is incomplete")
	for bus_name in contract["buses"]:
		_expect(AudioServer.get_bus_index(String(bus_name)) >= 0, "missing audio bus: %s" % bus_name)
	for pair in [[&"Music", &"Master"], [&"SFX", &"Master"], [&"Weapons", &"SFX"], [&"Player", &"SFX"], [&"Enemies", &"SFX"], [&"Boss", &"SFX"], [&"UI", &"SFX"]]:
		var index := AudioServer.get_bus_index(String(pair[0]))
		_expect(AudioServer.get_bus_send(index) == String(pair[1]), "%s bus is not routed to %s" % [pair[0], pair[1]])
	var master := AudioServer.get_bus_index("Master")
	_expect(AudioServer.get_bus_effect_count(master) == 1 and AudioServer.get_bus_effect(master, 0) is AudioEffectLimiter, "Master limiter is missing or duplicated")


func _test_cue_catalog(audio: Node) -> void:
	for cue in [
		&"rifle", &"shotgun", &"sniper", &"pistol", &"impact_normal", &"impact_heavy",
		&"rifle_mechanic", &"shotgun_pump", &"sniper_bolt", &"pistol_slide",
		&"rifle_reload", &"shotgun_reload", &"sniper_reload", &"pistol_reload", &"mag_insert", &"reload_complete", &"empty_click",
		&"shield_block", &"guard_break", &"enemy_warning", &"elite_warning", &"enemy_hurt", &"enemy_hurt_heavy",
		&"assault_swing", &"shield_bash", &"elite_attack", &"elite_step", &"player_hurt",
		&"player_death", &"jump", &"footstep", &"heavy_land", &"low_health",
		&"roll", &"projectile_evade", &"grenade_throw", &"grenade_bounce", &"grenade_fuse", &"grenade_explosion", &"grenade_empty",
		&"boss_intro", &"boss_land", &"boss_phase_2", &"boss_phase_3", &"boss_charge_release", &"boss_area_release",
		&"boss_warning_volley", &"boss_warning_charge", &"boss_warning_area", &"boss_failure", &"boss_explosion", &"boss_core_off", &"boss_death",
		&"ui_hover", &"ui_pause", &"ui_resume", &"mission_complete",
	]:
		_expect(audio.has_cue(cue), "procedural cue is missing: %s" % cue)
	_expect(audio.has_cue(&"shot") and audio.has_cue(&"accent_hit") and audio.has_cue(&"kill"), "legacy cue aliases no longer resolve")
	var rifle: Dictionary = audio.get_cue_profile(&"rifle")
	var shotgun: Dictionary = audio.get_cue_profile(&"shotgun")
	var sniper: Dictionary = audio.get_cue_profile(&"sniper")
	var pistol: Dictionary = audio.get_cue_profile(&"pistol")
	_expect(rifle["bus"] == &"Weapons" and shotgun["bus"] == &"Weapons" and sniper["bus"] == &"Weapons" and pistol["bus"] == &"Weapons", "weapon cues escaped the Weapons bus")
	_expect(float(shotgun["synth"][1]) > float(rifle["synth"][1]) and float(sniper["synth"][1]) > float(pistol["synth"][1]), "four weapons do not retain distinct transient lengths")
	_expect(float(shotgun["volume"]) > float(rifle["volume"]) and float(sniper["volume"]) > float(pistol["volume"]), "heavy weapons are not prioritized over sustained/light fire")
	_expect(audio.get_cue_profile(&"boss_warning_charge")["bus"] == &"Boss" and audio.get_cue_profile(&"enemy_warning")["bus"] == &"Enemies", "Boss and enemy warnings are not independently mixable")
	_expect(audio.get_cue_profile(&"grenade_explosion")["bus"] == &"Weapons" and audio.get_cue_profile(&"grenade_empty")["bus"] == &"UI", "grenade combat and empty cues escaped their intended buses")
	for cue in [&"rifle", &"shotgun", &"sniper", &"pistol", &"impact_heavy", &"boss_death"]:
		var peak := _stream_peak(audio._streams[cue] as AudioStreamWAV)
		_expect(peak > 0.04 and peak <= 0.80, "%s source peak is silent or clipping: %.3f" % [cue, peak])


func _test_music_flow(audio: Node) -> void:
	var contract: Dictionary = audio.get_audio_contract()
	_expect(contract["current_track"] == &"level", "level music did not start with the mission")
	_expect((&"level" in contract["music_tracks"]) and (&"boss" in contract["music_tracks"]), "original level/Boss music streams are missing")
	_expect(audio._music_players[audio._active_music_index].bus == "Music", "music deck escaped the Music bus")
	_expect(_stream_peak(audio._music_streams[&"level"]) <= 0.70 and _stream_peak(audio._music_streams[&"boss"]) <= 0.70, "music source peaks leave no limiter headroom")


func _test_voice_limits(audio: Node) -> void:
	var rejected_before: int = int(audio.get_rejected_play_count())
	for _index in range(48):
		audio.play_cue(&"impact_normal")
	for cue in [&"rifle", &"shotgun", &"sniper", &"pistol", &"enemy_shot", &"enemy_kill_light", &"boss_hit_heavy", &"ui_adjust"]:
		audio.play_cue(cue)
	_expect(audio.get_active_voice_count() <= 20 and audio.get_peak_voice_count() <= 20, "SFX peak escaped the fixed 20-voice pool")
	_expect(audio.get_rejected_play_count() > rejected_before, "same-cue cooldown did not merge dense repeated hits")
	var player_nodes := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			player_nodes += 1
	_expect(player_nodes == 22, "audio playback created unbounded temporary players")


func _test_spatial_mix(audio: Node) -> void:
	var listener := Vector2.ZERO
	var near_db: float = audio.calculate_world_attenuation(Vector2(100.0, 0.0), listener)
	var far_db: float = audio.calculate_world_attenuation(Vector2(2000.0, 0.0), listener)
	var far_warning_db: float = audio.calculate_world_attenuation(Vector2(2000.0, 0.0), listener, true)
	_expect(is_equal_approx(near_db, 0.0), "near world sounds are attenuated unexpectedly")
	_expect(far_db <= -13.9, "off-screen ordinary combat sounds are not attenuated")
	_expect(far_warning_db >= -6.01 and far_warning_db > far_db, "important off-screen warnings lost their priority floor")


func _test_pause_mix_controls(game: Node, audio: Node) -> void:
	var initial: Dictionary = audio.get_mix_snapshot()
	_expect(int(initial[&"Master"]["percent"]) == 100 and int(initial[&"Music"]["percent"]) == 72 and int(initial[&"SFX"]["percent"]) == 86, "default mix levels are incorrect")
	_expect(game.hud.audio_value_labels[&"Music"].text == "072%", "pause UI did not receive the initial mix snapshot")
	game.hud.toggle_pause()
	await process_frame
	_expect(paused and game.hud.audio_settings.visible and audio._music_ducked, "pause did not expose audio controls and duck music")
	game.hud._on_audio_step_pressed(&"Music", -1)
	_expect(int(audio.get_mix_snapshot()[&"Music"]["percent"]) == 62 and game.hud.audio_value_labels[&"Music"].text == "062%", "Music decrement did not update bus and UI")
	game.hud._on_audio_mute_pressed(&"SFX")
	_expect(bool(audio.get_mix_snapshot()[&"SFX"]["muted"]) and game.hud.audio_mute_buttons[&"SFX"].text == "UNMUTE", "SFX mute did not update bus and UI")
	game.hud._on_audio_mute_pressed(&"SFX")
	game.hud._on_audio_step_pressed(&"Music", 1)
	game.hud.toggle_pause()
	await process_frame
	_expect(not paused and not game.hud.audio_settings.visible and not audio._music_ducked, "resume did not close settings and restore music")


func _test_semantic_duck(audio: Node) -> void:
	var active: AudioStreamPlayer = audio._music_players[audio._active_music_index]
	audio.duck_music(0.04, 5.0)
	await create_timer(0.065, true, false, true).timeout
	_expect(active.volume_db <= -7.5, "semantic Boss/death duck did not lower the active music deck")
	await create_timer(0.26, true, false, true).timeout
	_expect(absf(active.volume_db - -3.0) < 0.15, "semantic music duck did not recover cleanly")


func _test_event_wiring(game: Node, audio: Node) -> void:
	var jump_before: int = audio.get_play_count(&"jump")
	game.player.jumped.emit(game.player.global_position)
	await process_frame
	_expect(audio.get_play_count(&"jump") == jump_before + 1, "player jump event is not wired to audio")
	var reload_before: int = audio.get_play_count(&"rifle_reload")
	game.player.reload_stage.emit(&"start", &"rifle")
	await process_frame
	_expect(audio.get_play_count(&"rifle_reload") == reload_before + 1, "weapon-specific reload start is not wired")
	var hover_before: int = audio.get_play_count(&"ui_hover")
	game.hud._on_ui_hover()
	await process_frame
	_expect(audio.get_play_count(&"ui_hover") == hover_before + 1, "pause UI hover selection is not wired")


func _test_boss_music_transition(game: Node, audio: Node) -> void:
	game._debug_unlock_boss_for_tests()
	game.player.global_position.x = 17850.0
	game._process(0.0)
	_expect(game.run_state == "boss" and audio.get_audio_contract()["current_track"] == &"boss", "Boss entry did not crossfade to Boss music")
	_expect(audio.get_cue_profile(&"boss_phase_2")["priority"] == 4 and audio.get_cue_profile(&"boss_death")["priority"] == 5, "Boss phase/death cues can be stolen by low-priority fire")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _stream_peak(stream: AudioStreamWAV) -> float:
	var peak := 0.0
	for index in range(0, stream.data.size(), 2):
		peak = maxf(peak, absf(float(stream.data.decode_s16(index)) / 32767.0))
	return peak


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("AUDIO_SYSTEM_PASS eight buses, Master limiter, original level/Boss loops, four weapon signatures and reload layers, spatial semantic combat/Boss/UI cues, bounded 20-voice pool, pause mix controls and semantic duck")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
