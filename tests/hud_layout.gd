extends SceneTree

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var game: Node = load("res://scenes/bootstrap.tscn").instantiate()
	root.add_child(game)
	game.start_button.pressed.emit()
	assert(game._travel("pier_to_landing"))
	game._begin_combat()
	game._order_attack()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		var commands: Rect2 = game.actions_scroll.get_global_rect()
		var status: Rect2 = game.combat_status.get_global_rect()
		var message: Rect2 = game.message.get_global_rect()
		if commands.end.y > status.position.y or status.end.y > message.position.y:
			push_error("HUD sections intersect at %s" % resolution)
			quit(1)
			return
	game._show_menu()
	assert(not game.combat_status.is_visible_in_tree() and not game.message.is_visible_in_tree())
	print("PASS: battle HUD separation and pause menu visibility")
	quit()
