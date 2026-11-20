extends SceneTree

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	if not paused:
		_fail("The game should start at the menu")
		return
	game.start_button.pressed.emit()
	game._move_party(Vector2i(4, 0))
	for frame in 300:
		game._physics_process(1.0 / 60.0)
	if game.party[0].position != Vector3(4, 0.45, 0) or game.party[1].position != Vector3(4, 0.45, 1):
		_fail("Both members must reach distinct positions")
		return
	game._move_party(Vector2i(-4, 0))
	var before: Vector3 = game.party[0].position
	game._show_menu()
	game._physics_process(1.0)
	if not paused or game.party[0].position != before:
		_fail("The party must stop while paused")
		return
	print("PASS: pier startup, two members and pause")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
