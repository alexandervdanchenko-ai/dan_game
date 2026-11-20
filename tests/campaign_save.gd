extends SceneTree

var failures: int = 0

func _initialize() -> void:
	var state_script := load("res://game/campaign/campaign_state.gd") as GDScript
	var store_script := load("res://game/campaign/save_store.gd") as GDScript
	if state_script == null or store_script == null:
		push_error("Missing campaign persistence scripts")
		quit(1)
		return

	var directory := "user://save_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store: RefCounted = store_script.new(directory)
	var state: RefCounted = state_script.new()
	state.current_location = "landing"
	state.entry = "river"
	state.flags = {"clue": true}
	state.party_positions.assign([Vector3(1.25, 0.5, 6), Vector3(2, 0.5, -2)])

	_check(store.write("session", state) == OK, "First write succeeds")
	var loaded: RefCounted = store.read("session")
	_check(loaded != null and loaded.current_location == "landing"
		and loaded.entry == "river" and loaded.flags == {"clue": true}
		and loaded.party_positions == state.party_positions, "Campaign round-trips")

	state.current_location = "pier"
	_check(store.write("session", state) == OK, "Second write succeeds")
	loaded = store.read("session")
	_check(loaded != null and loaded.current_location == "pier", "Primary is latest")

	var primary := directory.path_join("session.json")
	_write_text(primary, "{broken")
	loaded = store.read("session")
	_check(loaded != null and loaded.current_location == "landing", "Corruption falls back to backup")
	_check(store.write("session", state) == OK, "A new valid save can replace corruption")
	_write_text(primary, "{broken")
	loaded = store.read("session")
	_check(loaded != null and loaded.current_location == "landing", "Corruption never replaces the valid backup")

	var future := '{"version":999}'
	_write_text(primary, future)
	_check(store.read("session") == null and store.last_error == ERR_UNAVAILABLE,
		"Future version is reported without loading the older backup")
	_check(store.write("session", state) == ERR_UNAVAILABLE
		and FileAccess.get_file_as_string(primary) == future, "Future version is preserved")
	_check(store.write("../outside", state) == ERR_INVALID_PARAMETER, "Traversal slot rejected")

	var absolute_directory := ProjectSettings.globalize_path(directory)
	for file: String in DirAccess.get_files_at(absolute_directory):
		DirAccess.remove_absolute(absolute_directory.path_join(file))
	DirAccess.remove_absolute(absolute_directory)
	if failures == 0:
		print("PASS: campaign save, backup recovery and version protection")
	quit(1 if failures else 0)

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Test fixture can write " + path)
		return
	file.store_string(content)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
