extends SceneTree

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		_fail("Bootstrap scene must load")
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	game.start_button.pressed.emit()
	if game._travel("pier_to_hideout") or not game._travel("pier_to_landing"):
		_fail("Only the ferry should be available on departure")
		return
	var original_map: Node3D = game.active_map
	var pier_scene: PackedScene = game.locations["pier"]
	game.locations.erase("pier")
	if game._travel("landing_to_pier") or game.active_map != original_map or game.state.current_location != "landing":
		_fail("Failed loading must keep the original map and state")
		return
	game.locations["pier"] = pier_scene
	game._discover_clue()
	var slot := "travel-test-%d" % Time.get_ticks_usec()
	if not game._save_slot(slot) or not game._travel("landing_to_pier") or not game._travel("pier_to_hideout"):
		_fail("The clue should unlock the hidden landing")
		return
	if not game._travel("hideout_to_pier") or not game._load_slot(slot):
		_fail("Return travel and loading should work")
		return
	if game.state.current_location != "landing" or not game.state.flags.get("clue", false):
		_fail("Loading should restore the ferry and clue")
		return
	print("PASS: round trip, rollback, secret route and slot reload")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
