class_name SaveStore
extends RefCounted

const State = preload("res://game/campaign/campaign_state.gd")

var last_error: Error = OK
var _directory: String

func _init(directory: String = "user://saves") -> void:
	_directory = ProjectSettings.globalize_path(directory)

func read(slot_id: String) -> State:
	if not _valid_slot_id(slot_id):
		last_error = ERR_INVALID_PARAMETER
		return null
	var primary := _slot_path(slot_id)
	var result := _read_file(primary)
	if last_error == OK or last_error == ERR_UNAVAILABLE:
		return result
	var primary_error := last_error
	result = _read_file(primary + ".bak")
	if last_error == ERR_FILE_NOT_FOUND:
		last_error = primary_error
	return result

func write(slot_id: String, state: State) -> Error:
	last_error = _write_slot(slot_id, state)
	return last_error

func _write_slot(slot_id: String, state: State) -> Error:
	if not _valid_slot_id(slot_id) or state == null:
		return ERR_INVALID_PARAMETER
	var payload := state.to_payload()
	if not State.new().restore(payload):
		return ERR_INVALID_DATA

	var primary := _slot_path(slot_id)
	var backup := primary + ".bak"
	var staging := primary + ".tmp"
	var previous := _read_file(primary)
	if last_error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	_read_file(backup)
	if last_error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE

	var result := DirAccess.make_dir_recursive_absolute(_directory)
	if result != OK:
		return result
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "", true, true))
	file.flush()
	result = file.get_error()
	file.close()
	if result != OK:
		return result
	if _read_file(staging) == null:
		return last_error

	# Keep the last readable generation recoverable if the final rename fails.
	if previous != null:
		result = DirAccess.rename_absolute(primary, backup)
		if result != OK:
			return result
	return DirAccess.rename_absolute(staging, primary)

func _read_file(path: String) -> State:
	last_error = ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = FileAccess.get_open_error()
		return null
	var parser := JSON.new()
	last_error = ERR_FILE_CORRUPT
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return null

	var payload: Dictionary = parser.data
	var version: Variant = payload.get("version")
	if typeof(version) != TYPE_FLOAT and typeof(version) != TYPE_INT:
		return null
	if version > State.SAVE_VERSION:
		last_error = ERR_UNAVAILABLE
		return null
	if version != State.SAVE_VERSION:
		return null
	var state := State.new()
	if not state.restore(payload):
		return null
	last_error = OK
	return state

func _slot_path(slot_id: String) -> String:
	return _directory.path_join(slot_id + ".json")

func _valid_slot_id(slot_id: String) -> bool:
	if slot_id.is_empty() or slot_id.length() > 64:
		return false
	for character: String in slot_id:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			return false
	return slot_id[0] != "-" and slot_id[0] != "_"
