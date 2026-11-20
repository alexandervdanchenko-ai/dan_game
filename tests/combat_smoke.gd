extends SceneTree

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		_fail("Scene must load")
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	game.start_button.pressed.emit()
	if not game._travel("pier_to_landing"):
		_fail("The ferry must be reachable")
		return
	game._begin_combat()
	game._select_fighters("hero")
	game._order_attack()
	game._switch_weapon()
	if game.combat.orders.has("companion") or not game.use_spear:
		_fail("A single fighter should receive the selected order")
		return
	game._select_fighters("companion")
	game._order_hold()
	var before: Vector3 = game.party[0].position
	game._physics_process(3.0)
	if game.party[0].position != before or game.combat.enemy_health != 6:
		_fail("Movement and attacks must stop on tactical pause")
		return
	game._order_retreat()
	game._toggle_combat_pause()
	game._physics_process(1.0 / 60.0)
	if game.combat != null or game.state.current_location != "pier":
		_fail("Retreat must return the party to the pier")
		return
	game._travel("pier_to_landing")
	game._begin_combat()
	game._order_attack()
	game._toggle_combat_pause()
	for frame in 900:
		game._physics_process(1.0 / 60.0)
	if game.combat != null or not game.state.flags.get("landing_victory", false):
		_fail("A group attack must defeat the opponent")
		return
	var slot := "combat-test-%d" % Time.get_ticks_usec()
	if not game._save_slot(slot) or not game._load_slot(slot):
		_fail("Victory must be saveable")
		return
	game._begin_combat()
	if game.combat != null:
		_fail("Reloading must not resurrect the defeated opponent")
		return
	print("PASS: individual orders, weapon switch, pause, retreat and saved victory")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
