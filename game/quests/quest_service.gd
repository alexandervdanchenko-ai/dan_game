extends RefCounted

const State = preload("res://game/campaign/campaign_state.gd")
const MAX_IRON := 999

func available(choice_id: String, state: State) -> bool:
	var flags := state.flags
	match choice_id:
		"accept":
			return state.current_location == "pier" and not flags.get("quest_accepted", false) and not flags.get("quest_resolved", false)
		"ward":
			return state.current_location == "pier" and flags.get("quest_accepted", false) and not flags.get("ward_received", false) and not flags.get("clue", false)
		"pilot":
			return state.current_location == "pier" and flags.get("quest_accepted", false) and not flags.get("pilot_joined", false) and not flags.get("quest_resolved", false)
		"note":
			return state.current_location == "landing" and not flags.get("clue", false)
		"invoke":
			return state.current_location == "landing" and flags.get("ward_received", false) and not flags.get("ward_used", false) and not flags.get("clue", false)
		"open", "seal":
			return state.current_location == "hideout" and flags.get("clue", false) and not flags.get("quest_resolved", false)
		_:
			return false

func apply_choice(choice_id: String, state: State) -> bool:
	if not available(choice_id, state):
		return false
	match choice_id:
		"accept":
			state.flags["quest_accepted"] = true
		"ward":
			state.flags["ward_received"] = true
		"pilot":
			state.flags["pilot_joined"] = true
		"note":
			state.flags["clue"] = true
		"invoke":
			state.flags["ward_used"] = true
			state.flags["clue"] = true
		"open", "seal":
			var is_open := choice_id == "open"
			state.flags["quest_resolved"] = true
			state.flags["passage_open"] = is_open
			if is_open:
				state.inventory["iron"] = mini(MAX_IRON, int(state.inventory["iron"]) + 1)
	return true

func journal(state: State) -> String:
	var flags := state.flags
	var pilot: bool = flags.get("pilot_joined", false)
	if flags.get("quest_resolved", false):
		var outcome := "Проход оставлен открытым. На стоянке найдено железо." if flags.get("passage_open", false) \
			else "Проход запечатан. Огни над водой погасли."
		if pilot:
			return outcome + " Кормчая знает брод через мель у переправы."
		return outcome + " Без кормчей мель у переправы придётся обходить."
	if flags.get("clue", false):
		return "Тайный ход найден. Путь к стоянке начинается на пристани."
	if flags.get("ward_received", false):
		return "Оберег в сумке. На переправе его можно поднести к воде."
	if flags.get("quest_accepted", false):
		if pilot:
			return "Кормчая узнала в пустом судне ладью своей семьи. Она советует искать записку перевозчика на переправе."
		return "Купец просит узнать, кто зажигает огни на переправе."
	return "На пристани купец ищет дружину для разведки переправы."
