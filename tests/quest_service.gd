extends SceneTree

const State = preload("res://game/campaign/campaign_state.gd")
const Quest = preload("res://game/quests/quest_service.gd")

func _initialize() -> void:
	var service := Quest.new()
	var state := State.new()
	assert(not service.apply_choice("note", state))
	assert(not service.apply_choice("ward", state))
	assert(service.apply_choice("accept", state))
	assert(not service.apply_choice("accept", state))
	assert(service.apply_choice("ward", state))
	state.current_location = "landing"
	assert(service.apply_choice("invoke", state))
	assert(state.flags["clue"] and state.flags["ward_used"])
	assert(not service.apply_choice("invoke", state))
	assert(not service.apply_choice("note", state))
	state.current_location = "hideout"
	var starting_iron: int = state.inventory["iron"]
	assert(service.apply_choice("open", state))
	assert(state.flags["quest_resolved"] and state.flags["passage_open"])
	assert(not service.apply_choice("seal", state))
	assert(not service.apply_choice("open", state))
	assert(state.inventory["iron"] == starting_iron + 1)
	assert(not service.journal(state).is_empty())

	var alternative := State.new()
	alternative.current_location = "landing"
	assert(service.apply_choice("note", alternative))
	assert(alternative.flags["clue"] and not alternative.flags.has("ward_used"))
	alternative.current_location = "hideout"
	assert(service.apply_choice("seal", alternative))
	assert(alternative.flags["quest_resolved"] and not alternative.flags["passage_open"])
	assert(alternative.inventory["iron"] == starting_iron)
	print("PASS: ward and note paths, exclusive endings and one-time reward")
	quit()
