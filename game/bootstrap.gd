extends Node

const Routes = preload("res://game/pier_routes.gd")
const Campaign = preload("res://game/campaign/campaign_state.gd")
const Saves = preload("res://game/campaign/save_store.gd")
const Graph = preload("res://game/world/world_graph.gd")
const Items = preload("res://game/items/item_service.gd")
const Quests = preload("res://game/quests/quest_service.gd")
const Settlements = preload("res://game/settlements/settlement_service.gd")
const Voyage = preload("res://game/travel/voyage_session.gd")
const Progression = preload("res://game/party/progression.gd")
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
var voyage: RefCounted
var river_view: Node3D
var player_boat: MeshInstance3D
var deck_view: Node3D
var shore_positions: Array[Vector3] = []
var hidden_shore: Array[Node3D] = []
var enemy: MeshInstance3D
var shield_mesh: MeshInstance3D
var round_time: float = 0.0
var resolve_left: int = 4
var use_spear: bool = false
var companion_damage_bonus: int = 0
var saves := Saves.new()
var graph := Graph.new()
var active_map: Node3D
var travel_panel := VBoxContainer.new()
var actions_scroll := ScrollContainer.new()
var quests := Quests.new()
var improvement_mesh: MeshInstance3D
var message := Label.new()
var combat_status := Label.new()
var feedback_panel := PanelContainer.new()
var menu_feedback := Label.new()
var hud_battle_text: String:
	set(value):
		combat_status.text = value
		_refresh_feedback()
var hud_message_text: String:
	set(value):
		message.text = value
		_refresh_feedback()
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
	for control: Control in [title_label, start_button, _button("Загрузить", _load_slot), quit_button, menu_feedback]:
		menu.add_child(control)
	start_button.pressed.connect(_start_or_resume)
	quit_button.text = "Выйти"
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	ui.add_child(status_label)
	status_label.position = Vector2(24, 24)
	ui.add_child(actions_scroll)
	actions_scroll.position = Vector2(24, 55)
	actions_scroll.size = Vector2(288, 315)
	actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions_scroll.add_child(travel_panel)
	travel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_feedback(ui)
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
	actions_scroll.hide()
	feedback_panel.hide()
	panel.show()
	menu_feedback.text = ""
	title_label.text = "Пауза" if started else "Огни под Каневом"
	start_button.text = "Продолжить" if started else "Начать"
	start_button.grab_focus()

func _start_or_resume() -> void:
	started = true
	get_tree().paused = false
	panel.hide()
	status_label.show()
	_refresh_actions()
	actions_scroll.show()
	_refresh_feedback()

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
	if get_tree().paused or (voyage != null and combat == null) or not event is InputEventMouseButton:
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
	hud_battle_text = ""
	if voyage != null:
		_add_river_actions()
		return
	if state.current_location == "landing" and not state.flags.get("landing_victory", false):
		travel_panel.add_child(_button("Вступить в бой", _begin_combat))
	for route_id: String in ["pier_to_landing", "landing_to_pier", "pier_to_hideout", "hideout_to_pier", "pier_to_forest", "forest_to_pier"]:
		if graph.can_travel(route_id, state):
			var route := graph.get_route(route_id)
			var names := {"pier": "Каневская пристань", "landing": "Переправа", "hideout": "Тайная стоянка", "forest": "Лесная тропа"}
			var destination: String = names.get(route["to"], route["to"])
			travel_panel.add_child(_button("Путь: " + destination,
				func() -> void: _travel(route_id)))
	_add_quest_actions()
	_add_settlement_actions()
	if state.current_location == "forest":
		travel_panel.add_child(_button("Осмотреть зарубки на столбе", _read_forest_marks))
	travel_panel.add_child(_button("Дружина и опыт", _show_progression))
	travel_panel.add_child(_button("Снаряжение", _show_inventory))
	if state.current_location == "pier":
		travel_panel.add_child(_button("Оковать щит · 1 железо", _upgrade_shield))
	if _has_repair_shop():
		travel_panel.add_child(_button("Починить щит · 1 железо", _repair_shield))
	travel_panel.add_child(_button("Сохранить", _save_slot))
	travel_panel.add_child(_button("Загрузить", _load_slot))

func _discover_clue() -> void:
	_choose("note")

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
	_build_location_props()
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
	shield_mesh = null
	improvement_mesh = null
	_sync_reeve()
	_update_shield_model()
	_refresh_improvement()

func _travel(route_id: String) -> bool:
	if combat != null or voyage != null:
		return false
	if not graph.can_travel(route_id, state):
		return false
	var route := graph.get_route(route_id)
	var candidate := Campaign.new()
	candidate.current_location = route["to"]
	candidate.entry = route["entry"]
	candidate.flags = state.flags.duplicate(true)
	candidate.inventory = state.inventory.duplicate(true)
	candidate.settlement = state.settlement.duplicate(true)
	candidate.progression = state.progression.duplicate(true)
	var next_map := _stage_map(candidate)
	if next_map == null:
		hud_message_text = "Путь недоступен. Дружина осталась на прежнем месте."
		return false
	_activate_map(next_map, candidate)
	hud_message_text = ""
	_refresh_actions()
	return true

func _save_slot(slot_id: String = SLOT) -> bool:
	if combat != null or voyage != null:
		return false
	state.party_positions.clear()
	for member in party:
		state.party_positions.append(member.position)
	var saved := saves.write(slot_id, state) == OK
	hud_message_text = "Игра сохранена." if saved else "Не удалось сохранить игру."
	return saved

func _load_slot(slot_id: String = SLOT) -> bool:
	var candidate := saves.read(slot_id)
	if candidate == null:
		_show_load_error("Нет доступного сохранения.")
		return false
	var next_map := _stage_map(candidate)
	if next_map == null:
		_show_load_error("Карта из сохранения недоступна.")
		return false
	_clear_river_view()
	voyage = null
	_activate_map(next_map, candidate)
	_start_or_resume()
	hud_message_text = "Игра загружена."
	return true

func _add_selection_actions() -> void:
	travel_panel.add_child(_button("Выбрать героя", func() -> void: _select_fighters("hero")))
	if "companion" in roster.active_ids():
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
		active_map.get_meta("caption"), selected.size(), roster.active_ids().size()]

func _begin_combat() -> void:
	if combat != null or state.current_location != "landing" or state.flags.get("landing_victory", false):
		return
	_start_fight(roster.active_ids())

func _start_fight(fighters: Array[String]) -> void:
	combat = Combat.new()
	combat.active_members = fighters
	combat.paused = true
	round_time = 0.0
	var shop := Items.new(state.inventory)
	var shield: Dictionary = state.inventory["shield"]
	resolve_left = 3 + int(shop.stats("shield")["defense"]) if shield["condition"] > 0 else 3
	var progress := Progression.new(state.progression)
	resolve_left += progress.level("hero") - 1
	companion_damage_bonus = int(progress.level("companion") >= 2)
	if state.settlement["buildings"].has("guard"):
		resolve_left += 1
	use_spear = false
	for index in orders.size():
		orders[index] = PackedVector2Array()
	enemy = _box(Vector3(ENEMY_CELL.x, 0.5, ENEMY_CELL.y), Vector3(0.75, 1, 0.75), Color("#aa5349"))
	hud_message_text = "Абордаж. Отдайте приказы и снимите паузу." if voyage != null else "Противник у переправы. Отдайте приказы и снимите паузу."
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
		if not member_id in combat.active_members:
			continue
		var distance := party[index].position.distance_to(enemy.position)
		threatened = threatened or distance <= 2.0
		var reach := 1.9 if use_spear else 1.4
		if distance <= reach:
			var damage := 1 if use_spear else 2
			if member_id == "companion":
				damage += companion_damage_bonus
			combat.strike(member_id, damage)
			if combat.outcome == "victory":
				_finish_combat(true)
				return
	if threatened:
		resolve_left -= 1
		Items.new(state.inventory).absorb_wear()
		if resolve_left == 0 and combat.retreat():
			_finish_combat(false)
			return
	_update_combat_status()

func _finish_combat(victory: bool) -> void:
	if victory:
		var source := "river_boarding" if voyage != null else "landing_battle"
		Progression.new(state.progression).award(source, combat.active_members, 3)
	enemy.queue_free()
	enemy = null
	combat = null
	for index in orders.size():
		orders[index] = PackedVector2Array()
	if voyage != null:
		_restore_shore()
		_finish_voyage("victory" if victory else "retreated")
		return
	if victory:
		state.flags["landing_victory"] = true
		state.inventory["iron"] += 1
		hud_message_text = "Переправа отбита. Найдена заготовка железа."
		_refresh_actions()
		return
	if _travel("landing_to_pier"):
		hud_message_text = "Дружина отступила к каневской пристани."
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
	hud_battle_text = "%s  ·  Противник: %d  ·  Стойкость дружины: %d\nОружие: %s  ·  Герой: %s  ·  Дружинник: %s" % [
		"Пауза" if combat.paused else "Бой", combat.enemy_health, resolve_left,
		"копьё" if use_spear else "меч", shown[0], shown[1]]

func _update_shield_model() -> void:
	if shield_mesh != null:
		shield_mesh.queue_free()
	var shield: Dictionary = state.inventory["shield"]
	var color := Color("#bac9d0") if shield["rim"] else Color("#996c43")
	shield_mesh = _box(Vector3.ZERO, Vector3(0.13, 0.52, 0.48), color)
	shield_mesh.reparent(party[0], false)
	shield_mesh.position = Vector3(0.33, 0.05, 0)

func _show_inventory() -> void:
	var shop := Items.new(state.inventory)
	var stats := shop.stats("shield")
	var shield: Dictionary = state.inventory["shield"]
	hud_message_text = "Щит героя: защита %d · вес %d · прочность %d/%d · железо: %d" % [
		stats["defense"], stats["weight"], shield["condition"], Items.MAX_CONDITION, state.inventory["iron"]]

func _upgrade_shield() -> void:
	if state.current_location != "pier" or combat != null:
		return
	if Items.new(state.inventory).apply_upgrade("shield", "rim", Items.SMITH):
		_update_shield_model()
		_show_inventory()
	else:
		hud_message_text = "Щит уже окован или не хватает железа."

func _repair_shield() -> void:
	if combat != null or not _has_repair_shop():
		return
	if Items.new(state.inventory).repair("shield", Items.SMITH):
		_show_inventory()
	else:
		hud_message_text = "Щит цел или не хватает железа."

func _add_quest_actions() -> void:
	var choices := {
		"accept": "Поговорить с купцом о пропавшем судне",
		"ward": "Попросить у ведуньи оберег",
		"note": "Прочитать записку перевозчика",
		"invoke": "Использовать оберег у воды",
		"open": "Открыть проход для судов",
		"seal": "Закрыть проход",
	}
	for choice_id: String in choices:
		if quests.available(choice_id, state):
			travel_panel.add_child(_button(choices[choice_id],
				func() -> void: _choose(choice_id)))
	travel_panel.add_child(_button("Журнал заданий", func() -> void: _show_journal()))

func _choose(choice_id: String) -> void:
	if not quests.apply_choice(choice_id, state):
		return
	var reactions := {
		"accept": "Купец: после тумана к берегу прибило пустое судно. Спроси перевозчика о старом ходе.",
		"ward": "Ведунья: опусти оберег в воду. Он покажет ход единожды.",
		"note": "В записке отмечена тайная стоянка. На неё можно выйти от каневской пристани.",
		"invoke": "Оберег рассыпался в воде. Огни указали путь к тайной стоянке.",
		"open": "Ты открыл проход и нашёл железо. Вернись на переправу к старосте.",
		"seal": "Ты закрыл проход. Вернись на переправу к старосте.",
	}
	var detail: String = reactions.get(choice_id, "")
	if choice_id in ["open", "seal"]:
		if Progression.new(state.progression).award("hidden_passage", roster.active_ids(), 3):
			detail += " Участники получили по 3 опыта."
	hud_message_text = detail
	_refresh_actions()

func _show_journal() -> void:
	hud_message_text = quests.journal(state)

func _add_settlement_actions() -> void:
	if state.current_location != "landing":
		return
	if not state.settlement["owned"]:
		if state.flags.get("quest_resolved", false):
			travel_panel.add_child(_button("Принять переправу от старосты", _claim_landing))
		return
	travel_panel.add_child(_button("Дела переправы", _show_settlement))
	if not state.flags.get("voyage_complete", false):
		travel_panel.add_child(_button("Выйти на ладье", _begin_voyage))
	travel_panel.add_child(_button(
		"Призвать дружинника" if state.settlement["reeve"] == "companion" else "Назначить дружинника воеводой",
		_toggle_reeve))
	if state.settlement["construction"].is_empty():
		for project_id: String in ["dock", "workshop", "guard"]:
			if not state.settlement["buildings"].has(project_id):
				travel_panel.add_child(_button("Заказать: " + _building_name(project_id),
					func() -> void: _commission(project_id)))
	travel_panel.add_child(_button("Отдохнуть до завтра", _next_day))

func _building_name(project_id: String) -> String:
	return {"dock": "Пристань", "workshop": "Мастерская", "guard": "Караульный пост"}.get(project_id, project_id)

func _claim_landing() -> void:
	if state.current_location == "landing" and state.flags.get("quest_resolved", false):
		if Settlements.new(state.settlement).claim():
			_refresh_actions()
			_show_settlement()

func _show_settlement() -> void:
	var holding := state.settlement
	var building := PackedStringArray()
	for id: String in holding["buildings"]:
		building.append(_building_name(id))
	var project: Dictionary = holding["construction"]
	var work := "Стройки нет."
	if not project.is_empty():
		work = "%s будет готова к дню %d." % [_building_name(project["project_id"]), project["finish_day"]]
	hud_message_text = "День %d · Казна %d · Воевода: %s\n%s Завершено: %s" % [
		holding["day"], holding["treasury"], "дружинник" if holding["reeve"] else "нет",
		work, ", ".join(building) if not building.is_empty() else "ничего"]

func _commission(project_id: String) -> void:
	if state.current_location != "landing":
		return
	if not Settlements.new(state.settlement).queue_building("landing", project_id):
		hud_message_text = "Заказ недоступен. Проверьте казну и текущие работы."
		return
	_refresh_actions()
	_show_settlement()

func _next_day() -> void:
	if state.current_location != "landing" or not state.settlement["owned"]:
		return
	Settlements.new(state.settlement).advance_day(int(state.settlement["day"]) + 1)
	_refresh_improvement()
	_refresh_actions()
	_show_settlement()

func _toggle_reeve() -> void:
	if state.current_location != "landing":
		return
	var member := "" if state.settlement["reeve"] == "companion" else "companion"
	if Settlements.new(state.settlement).assign_reeve(member):
		_sync_reeve()
		_refresh_actions()
		_show_settlement()

func _sync_reeve() -> void:
	var assigned: bool = state.settlement["reeve"] == "companion"
	roster.assign_role("companion", "voevoda" if assigned else "field")
	party[1].visible = not assigned
	orders[1] = PackedVector2Array()

func _refresh_improvement() -> void:
	if improvement_mesh != null:
		improvement_mesh.queue_free()
		improvement_mesh = null
	if state.current_location != "landing" or state.settlement["buildings"].is_empty():
		return
	var buildings: Dictionary = state.settlement["buildings"]
	var tint := Color("#85674b") if buildings.has("dock") else Color("#646d67")
	improvement_mesh = _box(Vector3(-3, 0.3, 5.75), Vector3(3, 0.6, 1.8), tint)


func _has_repair_shop() -> bool:
	return state.current_location == "pier" or (
		state.current_location == "landing" and state.settlement["buildings"].has("workshop"))

func _begin_voyage() -> void:
	if state.current_location != "landing" or not state.settlement["owned"] or voyage != null:
		return
	if state.flags.get("voyage_complete", false):
		return
	voyage = Voyage.new(roster.active_ids(), 1 if state.settlement["buildings"].has("dock") else 0)
	active_map.hide()
	river_view = Node3D.new()
	world.add_child(river_view)
	_river_box(Vector3(0, -0.2, 0), Vector3(12, 0.3, 10), Color("#386e85"))
	_river_box(Vector3(0, -0.02, -1), Vector3(3, 0.1, 1), Color("#baa86f"))
	_river_box(Vector3(3, 0.2, 0), Vector3(1.7, 0.45, 0.7), Color("#a95e4d"))
	player_boat = _river_box(Vector3.ZERO, Vector3(1.05, 0.35, 0.62), Color("#e6bc62"))
	_update_boat()
	hud_message_text = "Речной патруль впереди. Светлая полоса — мель."
	_refresh_actions()

func _river_box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var model := _box(at, size, color)
	model.reparent(river_view, false)
	return model

func _update_boat() -> void:
	var position_on_river: Vector2 = voyage.position
	var direction: Vector2 = voyage.heading
	player_boat.position = Vector3(position_on_river.x - 5, 0.2, position_on_river.y - 4)
	player_boat.rotation.y = -direction.angle()

func _add_river_actions() -> void:
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var label: String = {
			Vector2i.UP: "На север", Vector2i.DOWN: "На юг",
			Vector2i.LEFT: "На запад", Vector2i.RIGHT: "На восток",
		}[direction]
		travel_panel.add_child(_button(label, func() -> void: _steer(direction)))
	if voyage.can_board():
		travel_panel.add_child(_button("Договориться с патрулём", func() -> void: _finish_voyage("negotiated")))
		travel_panel.add_child(_button("Взять на абордаж", _begin_boarding))
	if voyage.position.x == 10:
		travel_panel.add_child(_button("Пройти дальше по реке", func() -> void: _finish_voyage("passed")))
	travel_panel.add_child(_button("Вернуться к берегу", func() -> void: _finish_voyage("retreated")))
	hud_battle_text = "Речной переход · Ладья: %d, %d · Груз: %d" % [
		voyage.position.x, voyage.position.y, voyage.cargo]

func _steer(direction: Vector2i) -> void:
	if voyage == null or combat != null:
		return
	if not voyage.steer(direction):
		hud_message_text = "Ладья не может пройти в этом направлении."
		return
	_update_boat()
	hud_message_text = ""
	_refresh_actions()

func _begin_boarding() -> void:
	if voyage == null or combat != null or not voyage.start_boarding(Voyage.PATROL_ID):
		return
	_clear_river_view()
	active_map.show()
	shore_positions.clear()
	hidden_shore.clear()
	for child: Node in active_map.get_children():
		if child is MeshInstance3D and not child in party and child.visible:
			hidden_shore.append(child)
			child.hide()
	for index in party.size():
		shore_positions.append(party[index].position)
		party[index].position = Vector3(-5, 0.45, index)
	deck_view = Node3D.new()
	active_map.add_child(deck_view)
	_deck_box(Vector3(0, -0.35, 0), Vector3(20, 0.3, 14), Color("#386e85"))
	_deck_box(Vector3(0, -0.16, -3), Vector3(17, 0.3, 5), Color("#826043"))
	_deck_box(Vector3(0, -0.16, 3), Vector3(17, 0.3, 5), Color("#694b38"))
	_deck_box(Vector3(0, -0.15, 0), Vector3(17, 0.3, 1), Color("#a18a69"))
	_deck_box(Vector3(0, 0.5, 0), Vector3(2.9, 1, 2.9), Color("#995e3b"))
	_start_fight(voyage.boarding_crew())

func _deck_box(at: Vector3, size: Vector3, color: Color) -> void:
	_box(at, size, color).reparent(deck_view, false)

func _restore_shore() -> void:
	if deck_view == null:
		return
	deck_view.queue_free()
	deck_view = null
	for node in hidden_shore:
		node.show()
	hidden_shore.clear()
	for index in party.size():
		party[index].position = shore_positions[index]
	shore_positions.clear()

func _clear_river_view() -> void:
	if river_view != null:
		river_view.queue_free()
		river_view = null
	player_boat = null

func _finish_voyage(outcome_id: String) -> void:
	if voyage == null or combat != null or not voyage.resolve_encounter(outcome_id):
		return
	_clear_river_view()
	active_map.show()
	if outcome_id != "retreated":
		state.flags["voyage_complete"] = true
		state.flags["voyage_" + outcome_id] = true
		state.inventory["iron"] = mini(999, int(state.inventory["iron"]) + int(voyage.cargo))
	var reactions := {
		"victory": "Патруль побеждён. Груз доставлен на переправу.",
		"negotiated": "Патруль пропустил ладью. Дружина вернулась с грузом.",
		"passed": "Ладья миновала патруль и вернулась на переправу.",
		"retreated": "Дружина вернулась к берегу. Можно попробовать снова.",
	}
	hud_message_text = reactions.get(outcome_id, "")
	voyage = null
	_refresh_actions()

func _build_location_props() -> void:
	if state.current_location == "forest":
		_box(Vector3(0, 0.4, 0), Vector3(2.9, 0.8, 2.9), Color("#606458"))
		for index in 7:
			var x := float(index - 3) * 2.5
			_box(Vector3(x, 0.65, 5.2), Vector3(0.25, 1.3, 0.25), Color("#6f5344"))
			_box(Vector3(x, 1.65, 5.2), Vector3(1.0, 1.1, 1.0), Color("#31594b"))
		return
	_box(Vector3(0, -0.4, 9.5), Vector3(21, 0.5, 8), Color("#385b70"))
	_box(Vector3(4, -0.06, 6), Vector3(2, 0.2, 4), Color("#81604a"))
	var wall := Color("#8a6550")
	var roof := Color("#554134")
	match state.current_location:
		"landing":
			wall = Color("#826f55")
			roof = Color("#665141")
		"hideout":
			wall = Color("#5d665d")
			roof = Color("#46554b")
	_box(Vector3(0, 0.95, 0), Vector3(2.9, 1.9, 2.9), wall)
	_box(Vector3(0, 1.95, 0), Vector3(3.2, 0.25, 3.2), roof)

func _read_forest_marks() -> void:
	if state.current_location == "forest":
		hud_message_text = "На столбе две зарубки: одна над водой, другая под водой. Перевозчик помечал здесь высоту разлива."
func _build_feedback(ui: CanvasLayer) -> void:
	ui.add_child(feedback_panel)
	feedback_panel.position = Vector2(24, 386)
	feedback_panel.custom_minimum_size.x = 530
	feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.075, 0.09, 0.88)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		background.set_content_margin(side, 10.0)
	feedback_panel.add_theme_stylebox_override("panel", background)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_panel.add_child(lines)
	for label: Label in [combat_status, message]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(label)
	_refresh_feedback()

func _refresh_feedback() -> void:
	combat_status.visible = not combat_status.text.is_empty()
	message.visible = not message.text.is_empty()
	feedback_panel.visible = started and not get_tree().paused and (
		combat_status.visible or message.visible)

func _show_load_error(detail: String) -> void:
	if get_tree().paused:
		menu_feedback.text = detail
	else:
		hud_message_text = detail
func _show_progression() -> void:
	var progress := Progression.new(state.progression)
	hud_message_text = "Герой: уровень %d · опыт %d. Дружинник: уровень %d · опыт %d." % [
		progress.level("hero"), progress.xp("hero"), progress.level("companion"), progress.xp("companion")]