extends Node

const Routes = preload("res://game/pier_routes.gd")
const Campaign = preload("res://game/campaign/campaign_state.gd")
const Saves = preload("res://game/campaign/save_store.gd")
const Graph = preload("res://game/world/world_graph.gd")
const Party = preload("res://game/party/party_state.gd")
const Combat = preload("res://game/combat/combat_session.gd")
const MEMBER_IDS: Array[String] = ["hero", "companion"]
const ENEMY_CELL := Vector2i(5, 2)
const SLOT := "campaign"
const WALK_SPEED: float = 3.5

@export var locations: Dictionary[String, PackedScene]

var state := Campaign.new()
var roster := Party.new()
var combat: RefCounted
var enemy: MeshInstance3D
var round_time: float = 0.0
var resolve_left: int = 4
var use_spear: bool = false
var saves := Saves.new()
var graph := Graph.new()
var active_map: Node3D
var travel_panel := VBoxContainer.new()
var message := Label.new()
var combat_status := Label.new()
var routes := Routes.new()
var camera := Camera3D.new()
var party: Array[MeshInstance3D] = []
var orders: Array[PackedVector2Array] = []
var world := Node3D.new()
var panel := PanelContainer.new()
var title_label := Label.new()
var start_button := Button.new()
var quit_button := Button.new()
var status_label := Label.new()
var started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(world)
	world.add_child(camera)
	camera.position = Vector3(12, 15, 12)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.shadow_enabled = true
	_activate_map(_stage_map(state), state)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(panel)
	panel.position = Vector2(24, 24)
	var menu := VBoxContainer.new()
	panel.add_child(menu)
	for control: Control in [title_label, start_button, _button("Загрузить", _load_slot), quit_button]:
		menu.add_child(control)
	start_button.pressed.connect(_start_or_resume)
	quit_button.text = "Выйти"
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	ui.add_child(status_label)
	status_label.position = Vector2(24, 24)
	ui.add_child(travel_panel)
	travel_panel.position = Vector2(24, 55)
	combat_status.position = Vector2(24, 390)
	combat_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(combat_status)
	message.position = Vector2(24, 420)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(message)
	_show_menu()

func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	shape.material = material
	model.mesh = shape
	active_map.add_child(model)
	model.position = at
	return model

func _show_menu() -> void:
	get_tree().paused = true
	status_label.hide()
	travel_panel.hide()
	combat_status.hide()
	panel.show()
	title_label.text = "Пауза" if started else "Огни под Каневом"
	start_button.text = "Продолжить" if started else "Начать"
	start_button.grab_focus()

func _start_or_resume() -> void:
	started = true
	get_tree().paused = false
	panel.hide()
	status_label.show()
	_refresh_actions()
	travel_panel.show()
	combat_status.show()

func _input(event: InputEvent) -> void:
	if combat != null and not get_tree().paused and event.is_action_pressed("ui_select"):
		_toggle_combat_pause()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if started and event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_start_or_resume()
		else:
			_show_menu()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if point is Vector3:
		_move_party(Vector2i(roundi(point.x), roundi(point.z)))

func _move_party(destination: Vector2i) -> void:
	if not routes.grid.region.has_point(destination) or routes.grid.is_point_solid(destination):
		return
	var selected: Array[String] = roster.selected_ids()
	if combat != null and not combat.issue_order(selected, {"kind": "move", "destination": destination}):
		return
	for index in party.size():
		if not MEMBER_IDS[index] in selected:
			continue
		var origin := Vector2i(roundi(party[index].position.x), roundi(party[index].position.z))
		var goal := destination
		if index > 0 and selected.size() > 1:
			for offset: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
				var alternate := destination + offset
				if routes.grid.region.has_point(alternate) and not routes.grid.is_point_solid(alternate):
					goal = alternate
					break
		orders[index] = routes.route(origin, goal)
	_update_combat_status()

func _physics_process(delta: float) -> void:
	if get_tree().paused or (combat != null and combat.paused):
		return
	_tick_combat(delta)
	for index in party.size():
		if orders[index].is_empty():
			continue
		var cell := orders[index][0]
		var member := party[index]
		var destination := Vector3(cell.x, member.position.y, cell.y)
		member.position = member.position.move_toward(destination, WALK_SPEED * delta)
		if member.position == destination:
			var remaining := orders[index]
			remaining.remove_at(0)
			orders[index] = remaining

func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	return button

func _refresh_actions() -> void:
	for child in travel_panel.get_children():
		travel_panel.remove_child(child)
		child.queue_free()
	status_label.text = "%s  ·  ЛКМ — вести дружину  ·  Esc — пауза" % active_map.get_meta("caption")
	_add_selection_actions()
	if combat != null:
		travel_panel.add_child(_button("Тактическая пауза / продолжить", _toggle_combat_pause))
		travel_panel.add_child(_button("Атаковать", _order_attack))
		travel_panel.add_child(_button("Удерживать позицию", _order_hold))
		travel_panel.add_child(_button("Сменить оружие", _switch_weapon))
		travel_panel.add_child(_button("Отступить к пристани", _order_retreat))
		_update_combat_status()
		return
	combat_status.text = ""
	if state.current_location == "landing" and not state.flags.get("landing_victory", false):
		travel_panel.add_child(_button("Вступить в бой", _begin_combat))
	for route_id: String in ["pier_to_landing", "landing_to_pier", "pier_to_hideout", "hideout_to_pier"]:
		if graph.can_travel(route_id, state):
			var route := graph.get_route(route_id)
			var names := {"pier": "Каневская пристань", "landing": "Переправа", "hideout": "Тайная стоянка"}
			var destination: String = names.get(route["to"], route["to"])
			travel_panel.add_child(_button("Путь: " + destination,
				func() -> void: _travel(route_id)))
	if state.current_location == "landing" and not state.flags.get("clue", false):
		travel_panel.add_child(_button("Прочитать записку перевозчика", _discover_clue))
	travel_panel.add_child(_button("Сохранить", _save_slot))
	travel_panel.add_child(_button("Загрузить", _load_slot))

func _discover_clue() -> void:
	state.flags["clue"] = true
	message.text = "За старой пристанью теперь известен путь к тайной стоянке."
	_refresh_actions()

func _stage_map(candidate: Campaign) -> Node3D:
	var scene: PackedScene = locations.get(candidate.current_location)
	if scene == null:
		return null
	var next_map := scene.instantiate() as Node3D
	if next_map == null:
		return null
	var marker := next_map.get_node_or_null(NodePath(candidate.entry)) as Marker3D
	if marker == null:
		next_map.free()
		return null
	return next_map

func _activate_map(next_map: Node3D, candidate: Campaign) -> void:
	if active_map != null:
		world.remove_child(active_map)
		active_map.queue_free()
	active_map = next_map
	var marker := active_map.get_node(NodePath(candidate.entry)) as Marker3D
	world.add_child(active_map)
	state = candidate
	combat = null
	enemy = null
	roster.select_all()
	party.clear()
	orders.clear()
	var ground: Color = active_map.get_meta("ground")
	_box(Vector3(0, -0.25, 0), Vector3(17, 0.5, 11), ground)
	_box(Vector3(0, -0.4, 9.5), Vector3(21, 0.5, 8), Color("#385b70"))
	_box(Vector3(4, -0.06, 6), Vector3(2, 0.2, 4), Color("#81604a"))
	_box(Vector3(0, 0.95, 0), Vector3(2.9, 1.9, 2.9), Color("#8a6550"))
	_box(Vector3(0, 1.95, 0), Vector3(3.2, 0.25, 3.2), Color("#554134"))
	var colors: Array[Color] = [Color("#e6bc62"), Color("#a5c4db")]
	for index in colors.size():
		var spawn := marker.position + Vector3(0, 0, index)
		if candidate.party_positions.size() == colors.size():
			var saved: Vector3 = candidate.party_positions[index]
			var cell := Vector2i(roundi(saved.x), roundi(saved.z))
			if routes.grid.region.has_point(cell) and not routes.grid.is_point_solid(cell):
				spawn = Vector3(saved.x, marker.position.y, saved.z)
		party.append(_box(spawn, Vector3(0.55, 0.9, 0.55), colors[index]))
		orders.append(PackedVector2Array())

func _travel(route_id: String) -> bool:
	if combat != null:
		return false
	if not graph.can_travel(route_id, state):
		return false
	var route := graph.get_route(route_id)
	var candidate := Campaign.new()
	candidate.current_location = route["to"]
	candidate.entry = route["entry"]
	candidate.flags = state.flags.duplicate(true)
	var next_map := _stage_map(candidate)
	if next_map == null:
		message.text = "Путь недоступен. Дружина осталась на прежнем месте."
		return false
	_activate_map(next_map, candidate)
	message.text = ""
	_refresh_actions()
	return true

func _save_slot(slot_id: String = SLOT) -> bool:
	if combat != null:
		return false
	state.party_positions.clear()
	for member in party:
		state.party_positions.append(member.position)
	var saved := saves.write(slot_id, state) == OK
	message.text = "Игра сохранена." if saved else "Не удалось сохранить игру."
	return saved

func _load_slot(slot_id: String = SLOT) -> bool:
	var candidate := saves.read(slot_id)
	if candidate == null:
		message.text = "Нет доступного сохранения."
		return false
	var next_map := _stage_map(candidate)
	if next_map == null:
		message.text = "Карта из сохранения недоступна."
		return false
	_activate_map(next_map, candidate)
	_start_or_resume()
	message.text = "Игра загружена."
	return true

func _add_selection_actions() -> void:
	travel_panel.add_child(_button("Выбрать героя", func() -> void: _select_fighters("hero")))
	travel_panel.add_child(_button("Выбрать дружинника", func() -> void: _select_fighters("companion")))
	travel_panel.add_child(_button("Выбрать всех", func() -> void: _select_fighters("")))
	_update_selection()

func _select_fighters(member_id: String) -> void:
	if member_id.is_empty():
		roster.select_all()
	else:
		roster.select(member_id)
	_update_selection()
	_update_combat_status()

func _update_selection() -> void:
	var selected: Array[String] = roster.selected_ids()
	for index in party.size():
		party[index].scale = Vector3.ONE if MEMBER_IDS[index] in selected else Vector3(0.82, 0.82, 0.82)
	status_label.text = "%s  ·  Выбрано: %d из %d  ·  Esc — меню" % [
		active_map.get_meta("caption"), selected.size(), party.size()]

func _begin_combat() -> void:
	if combat != null or state.current_location != "landing" or state.flags.get("landing_victory", false):
		return
	combat = Combat.new()
	combat.active_members = roster.active_ids()
	combat.paused = true
	round_time = 0.0
	resolve_left = 4
	use_spear = false
	for index in orders.size():
		orders[index] = PackedVector2Array()
	enemy = _box(Vector3(ENEMY_CELL.x, 0.5, ENEMY_CELL.y), Vector3(0.75, 1, 0.75), Color("#aa5349"))
	message.text = "Противник у переправы. Отдайте приказы и снимите паузу."
	_refresh_actions()

func _toggle_combat_pause() -> void:
	if combat != null:
		combat.paused = not combat.paused
		_update_combat_status()

func _switch_weapon() -> void:
	use_spear = not use_spear
	_update_combat_status()

func _order_attack() -> void:
	var selected: Array[String] = roster.selected_ids()
	if combat == null or not combat.issue_order(selected, {"kind": "attack"}):
		return
	for index in party.size():
		if not MEMBER_IDS[index] in selected:
			continue
		var at := party[index].position
		var origin := Vector2i(roundi(at.x), roundi(at.z))
		var goal := ENEMY_CELL + (Vector2i.LEFT if index == 0 else Vector2i.DOWN)
		orders[index] = routes.route(origin, goal)
	_update_combat_status()

func _order_hold() -> void:
	var selected: Array[String] = roster.selected_ids()
	if combat == null or not combat.issue_order(selected, {"kind": "hold"}):
		return
	for index in party.size():
		if MEMBER_IDS[index] in selected:
			orders[index] = PackedVector2Array()
	_update_combat_status()

func _order_retreat() -> void:
	var selected: Array[String] = roster.active_ids()
	if combat == null or not combat.issue_order(selected, {"kind": "retreat"}):
		return
	_update_combat_status()

func _tick_combat(delta: float) -> void:
	if combat == null:
		return
	var current_orders: Dictionary = combat.orders
	var retreat_order: Dictionary = current_orders.get("hero", {})
	if retreat_order.get("kind") == "retreat" and combat.retreat():
		_finish_combat(false)
		return
	round_time += delta
	if round_time < 1.0:
		return
	round_time -= 1.0
	var threatened := false
	for index in party.size():
		var member_id := MEMBER_IDS[index]
		var distance := party[index].position.distance_to(enemy.position)
		threatened = threatened or distance <= 2.0
		var reach := 1.9 if use_spear else 1.4
		if distance <= reach:
			combat.strike(member_id, 1 if use_spear else 2)
			if combat.outcome == "victory":
				_finish_combat(true)
				return
	if threatened:
		resolve_left -= 1
		if resolve_left == 0 and combat.retreat():
			_finish_combat(false)
			return
	_update_combat_status()

func _finish_combat(victory: bool) -> void:
	enemy.queue_free()
	enemy = null
	combat = null
	for index in orders.size():
		orders[index] = PackedVector2Array()
	if victory:
		state.flags["landing_victory"] = true
		message.text = "Переправа отбита."
		_refresh_actions()
		return
	if _travel("landing_to_pier"):
		message.text = "Дружина отступила к каневской пристани."
	else:
		_refresh_actions()

func _update_combat_status() -> void:
	if combat == null:
		return
	var current_orders: Dictionary = combat.orders
	var labels := {"move": "движение", "attack": "атака", "hold": "удержание", "retreat": "отход"}
	var shown := PackedStringArray()
	for member_id in MEMBER_IDS:
		var order: Dictionary = current_orders.get(member_id, {})
		shown.append(labels.get(order.get("kind"), "ожидает приказа"))
	combat_status.text = "%s  ·  Противник: %d  ·  Стойкость дружины: %d\nОружие: %s  ·  Герой: %s  ·  Дружинник: %s" % [
		"Пауза" if combat.paused else "Бой", combat.enemy_health, resolve_left,
		"копьё" if use_spear else "меч", shown[0], shown[1]]
