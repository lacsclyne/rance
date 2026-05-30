class_name CollectionState
extends RefCounted

const CardInstanceScript := preload("res://src/cards_characters/card_instance.gd")
const FactionSquadStateScript := preload("res://src/cards_characters/faction_squad_state.gd")

var content_indexes := {}
var _cards_by_character_id := {}


func _init(validated_content: Dictionary = {}) -> void:
	if not validated_content.is_empty():
		set_validated_content(validated_content)


func set_validated_content(validated_content: Dictionary) -> void:
	content_indexes = validated_content.get("indexes", validated_content).duplicate(true)


func add_character_card(
	character_id: String,
	duplicate_training_points: int = CardInstanceScript.DEFAULT_DUPLICATE_TRAINING_POINTS
):
	if not has_character_definition(character_id):
		return null

	if _cards_by_character_id.has(character_id):
		var existing = _cards_by_character_id[character_id]
		existing.add_duplicate(duplicate_training_points)
		return existing

	var card = CardInstanceScript.new(character_id)
	_cards_by_character_id[character_id] = card
	return card


func add_character_cards(character_ids: Array) -> Array:
	var added := []
	for character_id in character_ids:
		var card = add_character_card(str(character_id))
		if card != null:
			added.append(card)
	return added


func has_character_card(character_id: String) -> bool:
	return _cards_by_character_id.has(character_id)


func get_card_instance(character_id: String):
	return _cards_by_character_id.get(character_id)


func get_owned_character_ids() -> Array:
	var ids := _cards_by_character_id.keys()
	ids.sort()
	return ids


func get_owned_card_instances() -> Array:
	var cards := []
	for character_id in get_owned_character_ids():
		cards.append(_cards_by_character_id[character_id])
	return cards


func has_character_definition(character_id: String) -> bool:
	return not get_character_definition(character_id).is_empty()


func get_character_definition(character_id: String) -> Dictionary:
	return _definition("characters", character_id)


func get_faction_definition(faction_id: String) -> Dictionary:
	return _definition("factions", faction_id)


func get_skill_definition(skill_id: String) -> Dictionary:
	return _definition("skills", skill_id)


func get_faction_ids() -> Array:
	var ids := _table("factions").keys()
	ids.sort()
	return ids


func get_character_power(character_id: String) -> Dictionary:
	var character := get_character_definition(character_id)
	var card = get_card_instance(character_id)
	if character.is_empty() or card == null:
		return {}

	var base_stats: Dictionary = character.get("base_stats", {})
	var base_at := _int_value(base_stats.get("attack", 0))
	var base_hp_value := _int_value(base_stats.get("hp", 0))
	var at_value: int = base_at + card.get_at_bonus()
	var hp_value: int = base_hp_value + card.get_hp_bonus()

	return {
		"character_id": character_id,
		"faction_id": str(character.get("faction_id", "")),
		"base_at": base_at,
		"base_hp": base_hp_value,
		"duplicate_level": card.duplicate_level,
		"training_points": card.training_points,
		"at": at_value,
		"hp": hp_value
	}


func build_faction_squads() -> Dictionary:
	var squads := {}
	for faction_id in get_faction_ids():
		squads[faction_id] = FactionSquadStateScript.new(faction_id, get_faction_definition(faction_id))

	for character_id in get_owned_character_ids():
		var power := get_character_power(character_id)
		if power.is_empty():
			continue

		var faction_id: String = power["faction_id"]
		if not squads.has(faction_id):
			squads[faction_id] = FactionSquadStateScript.new(faction_id, get_faction_definition(faction_id))
		squads[faction_id].add_member(character_id, power["at"], power["hp"])

	return squads


func get_faction_squad(faction_id: String):
	return build_faction_squads().get(faction_id)


func _definition(table_key: String, content_id: String) -> Dictionary:
	var table := _table(table_key)
	if not table.has(content_id):
		return {}
	return table[content_id]


func _table(table_key: String) -> Dictionary:
	var table = content_indexes.get(table_key, {})
	if typeof(table) != TYPE_DICTIONARY:
		return {}
	return table


func _int_value(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0
