extends Node

const Routes = preload("res://game/pier_routes.gd")
const WALK_SPEED: float = 3.5

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
	_box(Vector3(0, -0.25, 0), Vector3(17, 0.5, 11), Color("#80926a"))
	_box(Vector3(0, -0.4, 9.5), Vector3(21, 0.5, 8), Color("#385b70"))
	_box(Vector3(4, -0.06, 6), Vector3(2, 0.2, 4), Color("#81604a"))
	_box(Vector3(0, 0.95, 0), Vector3(2.9, 1.9, 2.9), Color("#8a6550"))
	_box(Vector3(0, 1.95, 0), Vector3(3.2, 0.25, 3.2), Color("#554134"))
	party.append(_box(Vector3(-5, 0.45, 0), Vector3(0.55, 0.9, 0.55), Color("#e6bc62")))
	party.append(_box(Vector3(-5, 0.45, 1), Vector3(0.55, 0.9, 0.55), Color("#a5c4db")))
	for member in party:
		orders.append(PackedVector2Array())
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(panel)
	panel.position = Vector2(24, 24)
	var menu := VBoxContainer.new()
	panel.add_child(menu)
	for control: Control in [title_label, start_button, quit_button]:
		menu.add_child(control)
	start_button.pressed.connect(_start_or_resume)
	quit_button.text = "Выйти"
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	ui.add_child(status_label)
	status_label.position = Vector2(24, 24)
	status_label.text = "Пристань  ·  ЛКМ — вести дружину  ·  Esc — пауза"
	_show_menu()

func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	shape.material = material
	model.mesh = shape
	world.add_child(model)
	model.position = at
	return model

func _show_menu() -> void:
	get_tree().paused = true
	status_label.hide()
	panel.show()
	title_label.text = "Пауза" if started else "Огни под Каневом"
	start_button.text = "Продолжить" if started else "Начать"
	start_button.grab_focus()

func _start_or_resume() -> void:
	started = true
	get_tree().paused = false
	panel.hide()
	status_label.show()

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
