class_name LeaderSlot
extends RefCounted

const LEADER_BONUS_PERCENT := 10

var slot_index := 0
var character_id := ""
var character_definition := {}
var card_instance = null
var skill_ids := []


func _init(new_slot_index: int = 0) -> void:
	slot_index = new_slot_index


func set_character(new_character_id: String, new_character_definition: Dictionary, new_card_instance) -> void:
	character_id = new_character_id
	character_definition = new_character_definition.duplicate(true)
	card_instance = new_card_instance
	skill_ids.clear()
	for skill_id in character_definition.get("skill_ids", []):
		skill_ids.append(str(skill_id))


func clear() -> void:
	character_id = ""
	character_definition = {}
	card_instance = null
	skill_ids.clear()


func is_empty() -> bool:
	return character_id.is_empty()


func get_faction_id() -> String:
	return str(character_definition.get("faction_id", ""))


func get_skill_ids() -> Array:
	return skill_ids.duplicate()


func get_at_power() -> int:
	return _stat("attack") + _card_at_bonus()


func get_hp_power() -> int:
	return _stat("hp") + _card_hp_bonus()


func get_leader_at_bonus() -> int:
	return _percent_bonus(get_at_power())


func get_leader_hp_bonus() -> int:
	return _percent_bonus(get_hp_power())


func get_leader_bonus() -> Dictionary:
	return {
		"at": get_leader_at_bonus(),
		"hp": get_leader_hp_bonus()
	}


func get_summary() -> Dictionary:
	return {
		"slot_index": slot_index,
		"character_id": character_id,
		"faction_id": get_faction_id(),
		"skill_ids": get_skill_ids(),
		"leader_at_bonus": get_leader_at_bonus(),
		"leader_hp_bonus": get_leader_hp_bonus()
	}


func _percent_bonus(value: int) -> int:
	if is_empty() or value <= 0:
		return 0
	return max(1, int(floor(float(value) * float(LEADER_BONUS_PERCENT) / 100.0)))


func _stat(stat_name: String) -> int:
	var base_stats = character_definition.get("base_stats", {})
	if typeof(base_stats) != TYPE_DICTIONARY:
		return 0

	var value = base_stats.get(stat_name, 0)
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0


func _card_at_bonus() -> int:
	if card_instance == null:
		return 0
	return card_instance.get_at_bonus()


func _card_hp_bonus() -> int:
	if card_instance == null:
		return 0
	return card_instance.get_hp_bonus()
