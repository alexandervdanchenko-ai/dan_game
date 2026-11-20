extends SceneTree

const State = preload("res://game/campaign/campaign_state.gd")

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var legacy := State.new().to_payload()
	legacy.erase("inventory")
	assert(State.new().restore(legacy))
	var game: Node = load("res://scenes/bootstrap.tscn").instantiate()
	root.add_child(game)
	game.start_button.pressed.emit()
	game._upgrade_shield()
	game._repair_shield()
	assert(game.state.inventory["iron"] == 0)
	assert(game._travel("pier_to_landing"))
	var slot := "craft-test-%d" % Time.get_ticks_usec()
	assert(game._save_slot(slot) and game._load_slot(slot))
	assert(game.state.inventory["shield"]["rim"])
	assert(game.state.inventory["shield"]["condition"] == 5)
	game._begin_combat()
	assert(game.resolve_left == 6)
	print("PASS: existing save, smith, travel, reload and combat protection")
	quit()
