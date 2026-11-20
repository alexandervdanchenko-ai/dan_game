extends SceneTree

const DEFAULT_SECONDS := 120.0
const TARGET_FRAME_MS := 16.7

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var duration := DEFAULT_SECONDS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			var value := arg.trim_prefix("--seconds=")
			if not value.is_valid_float() or value.to_float() <= 0.0:
				push_error("--seconds must be positive")
				quit(1)
				return
			duration = value.to_float()
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	game.start_button.pressed.emit()
	var results: Array[Dictionary] = []
	game._move_party(Vector2i(4, 0))
	results.append(await _sample("pier", duration, func() -> void:
		game._move_party(Vector2i(-4, 2) if game.party[0].position.x > 0 else Vector2i(4, 0))))
	if not game._travel("pier_to_landing"):
		_fail("The ferry benchmark could not load")
		return
	game._begin_combat()
	game._toggle_combat_pause()
	results.append(await _sample("land_combat", duration, func() -> void:
		if game.combat != null:
			game._move_party(Vector2i(-5, 2) if game.party[0].position.z < 1 else Vector2i(-5, 0))))
	game._order_retreat()
	await physics_frame
	await physics_frame
	if not game._travel("pier_to_landing"):
		_fail("The river benchmark could not load")
		return
	game.state.flags["quest_resolved"] = true
	game._claim_landing()
	game._begin_voyage()
	for step in 4:
		game._steer(Vector2i.RIGHT)
	var transition_started := Time.get_ticks_usec()
	game._begin_boarding()
	if game.combat == null:
		_fail("The boarding benchmark could not start")
		return
	await process_frame
	var boarding_ms := (Time.get_ticks_usec() - transition_started) / 1000.0
	game._toggle_combat_pause()
	results.append(await _sample("boarding", duration, func() -> void:
		if game.combat != null:
			game._move_party(Vector2i(-5, 2) if game.party[0].position.z < 1 else Vector2i(-5, 0))))
	print(JSON.stringify({
		"display": DisplayServer.get_name(),
		"viewport": [root.size.x, root.size.y],
		"godot": Engine.get_version_info()["string"],
		"adapter": RenderingServer.get_video_adapter_name(),
		"boarding_setup_to_next_frame_ms": boarding_ms,
		"scenes": results,
	}))
	quit()

func _sample(label: String, seconds: float, action: Callable) -> Dictionary:
	await process_frame
	var began := Time.get_ticks_usec()
	var last := began
	var next_action := began + 1500000
	var samples := PackedFloat64Array()
	var long_frames := 0
	var over_target := 0
	while last - began < seconds * 1000000.0 or samples.size() < 2:
		if last >= next_action:
			action.call()
			next_action += 1500000
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - last) / 1000.0
		samples.append(elapsed)
		long_frames += int(elapsed > 50.0)
		over_target += int(elapsed > TARGET_FRAME_MS)
		last = now
	samples.sort()
	return {
		"scene": label,
		"frame_count": samples.size(),
		"p50_ms": _percentile(samples, 0.50),
		"p95_ms": _percentile(samples, 0.95),
		"max_ms": samples[-1],
		"frames_over_50_ms": long_frames,
		"frames_over_16_7_ms": over_target,
	}

func _percentile(samples: PackedFloat64Array, fraction: float) -> float:
	return samples[ceili(samples.size() * fraction) - 1]

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
