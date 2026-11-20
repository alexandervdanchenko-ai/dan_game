extends Node

const Routes = preload("res://game/pier_routes.gd")
const Campaign = preload("res://game/campaign/campaign_state.gd")
const Saves = preload("res://game/campaign/save_store.gd")
const Graph = preload("res://game/world/world_graph.gd")
const SLOT := "campaign"
const WALK_SPEED: float = 3.5

@export var locations: Dictionary[String, PackedScene]

var state := Campaign.new()
var saves := Saves.new()
var graph := Graph.new()
var active_map: Node3D
var travel_panel := VBoxContainer.new()
var message := Label.new()
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
	message.position = Vector2(24, 240)
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
	for index in party.size():
		var origin := Vector2i(roundi(party[index].position.x), roundi(party[index].position.z))
		var goal := destination
		if index > 0:
			for offset: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
				var alternate := destination + offset
				if routes.grid.region.has_point(alternate) and not routes.grid.is_point_solid(alternate):
					goal = alternate
					break
		orders[index] = routes.route(origin, goal)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
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
