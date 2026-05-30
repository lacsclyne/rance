class_name FormationState
extends RefCounted

const LeaderSlotScript := preload("res://src/cards_characters/leader_slot.gd")

const DEFAULT_FRONTLINE_SLOT_COUNT := 3
const MIN_FRONTLINE_SLOT_COUNT := 3
const MAX_FRONTLINE_SLOT_COUNT := 7

var collection_state = null
var leader_slots := []


func _init(
	new_collection_state = null,
	frontline_slot_count: int = DEFAULT_FRONTLINE_SLOT_COUNT
) -> void:
	collection_state = new_collection_state
	set_frontline_slot_count(frontline_slot_count)


static func frontline_slot_count_from_progression(
	unlocked_progression_ids: Array,
	slot_unlocks: Dictionary = {}
) -> int:
	var slot_count := DEFAULT_FRONTLINE_SLOT_COUNT
	for progression_id in unlocked_progression_ids:
		if not slot_unlocks.has(progression_id):
			continue
		slot_count = max(slot_count, _clamp_slot_count(slot_unlocks[progression_id]))
	return slot_count


func apply_progression_slot_unlocks(unlocked_progression_ids: Array, slot_unlocks: Dictionary = {}) -> int:
	var slot_count := frontline_slot_count_from_progression(unlocked_progression_ids, slot_unlocks)
	set_frontline_slot_count(slot_count)
	return slot_count


func set_frontline_slot_count(slot_count: int) -> Dictionary:
	var clamped_count := _clamp_slot_count(slot_count)
	if clamped_count != slot_count:
		return _error("frontline slot count must be between %s and %s" % [
			MIN_FRONTLINE_SLOT_COUNT,
			MAX_FRONTLINE_SLOT_COUNT
		])

	while leader_slots.size() < slot_count:
		leader_slots.append(LeaderSlotScript.new(leader_slots.size()))
	while leader_slots.size() > slot_count:
		leader_slots.pop_back()
	for index in range(leader_slots.size()):
		leader_slots[index].slot_index = index

	return _ok()


func get_frontline_slot_count() -> int:
	return leader_slots.size()


func set_leader(slot_index: int, character_id: String) -> Dictionary:
	var validation := _validate_leader_assignment(slot_index, character_id)
	if not validation["ok"]:
		return validation

	var character_definition: Dictionary = collection_state.get_character_definition(character_id)
	var card_instance = collection_state.get_card_instance(character_id)
	leader_slots[slot_index].set_character(character_id, character_definition, card_instance)
	return _ok()


func clear_leader(slot_index: int) -> Dictionary:
	if not _is_slot_index_valid(slot_index):
		return _error("slot index %s is outside the current frontline" % slot_index)

	leader_slots[slot_index].clear()
	return _ok()


func get_leader_slots() -> Array:
	return leader_slots.duplicate()


func get_leader_character_ids() -> Array:
	var ids := []
	for slot in leader_slots:
		if not slot.is_empty():
			ids.append(slot.character_id)
	return ids


func build_frontline_faction_squads() -> Dictionary:
	var all_squads := _build_all_faction_squads_with_leader_bonuses()
	var frontline_squads := {}
	for faction_id in _frontline_faction_ids():
		if all_squads.has(faction_id):
			frontline_squads[faction_id] = all_squads[faction_id]
	return frontline_squads


func build_all_faction_squads() -> Dictionary:
	return _build_all_faction_squads_with_leader_bonuses()


func get_party_hp() -> int:
	var total := 0
	for squad in build_frontline_faction_squads().values():
		total += squad.get_hp()
	return total


func get_available_skill_ids() -> Array:
	var ids := []
	for slot in leader_slots:
		if slot.is_empty():
			continue
		for skill_id in slot.get_skill_ids():
			if not ids.has(skill_id):
				ids.append(skill_id)
	return ids


func get_available_skills() -> Array:
	var skills := []
	if collection_state == null:
		return skills

	for skill_id in get_available_skill_ids():
		var skill_definition: Dictionary = collection_state.get_skill_definition(skill_id)
		if not skill_definition.is_empty():
			skills.append(skill_definition)
	return skills


func get_summary() -> Dictionary:
	var slot_summaries := []
	for slot in leader_slots:
		slot_summaries.append(slot.get_summary())

	var squad_summaries := {}
	for faction_id in build_frontline_faction_squads().keys():
		squad_summaries[faction_id] = build_frontline_faction_squads()[faction_id].get_summary()

	return {
		"frontline_slot_count": get_frontline_slot_count(),
		"leader_slots": slot_summaries,
		"party_hp": get_party_hp(),
		"available_skill_ids": get_available_skill_ids(),
		"frontline_faction_squads": squad_summaries
	}


static func _clamp_slot_count(slot_count) -> int:
	if typeof(slot_count) != TYPE_INT and typeof(slot_count) != TYPE_FLOAT:
		return DEFAULT_FRONTLINE_SLOT_COUNT
	return clamp(int(slot_count), MIN_FRONTLINE_SLOT_COUNT, MAX_FRONTLINE_SLOT_COUNT)


func _build_all_faction_squads_with_leader_bonuses() -> Dictionary:
	if collection_state == null:
		return {}

	var squads: Dictionary = collection_state.build_faction_squads()
	for slot in leader_slots:
		if slot.is_empty():
			continue

		var faction_id: String = slot.get_faction_id()
		if faction_id.is_empty() or not squads.has(faction_id):
			continue
		squads[faction_id].add_leader_bonus(
			slot.character_id,
			slot.get_leader_at_bonus(),
			slot.get_leader_hp_bonus()
		)
	return squads


func _frontline_faction_ids() -> Array:
	var faction_ids := []
	for slot in leader_slots:
		if slot.is_empty():
			continue
		var faction_id: String = slot.get_faction_id()
		if not faction_id.is_empty() and not faction_ids.has(faction_id):
			faction_ids.append(faction_id)
	return faction_ids


func _validate_leader_assignment(slot_index: int, character_id: String) -> Dictionary:
	if collection_state == null:
		return _error("collection state is required before assigning leaders")
	if not _is_slot_index_valid(slot_index):
		return _error("slot index %s is outside the current frontline" % slot_index)
	if character_id.is_empty():
		return _error("character id must not be empty")
	if not collection_state.has_character_card(character_id):
		return _error("character '%s' is not owned" % character_id)

	for slot in leader_slots:
		if slot.slot_index != slot_index and slot.character_id == character_id:
			return _error("character '%s' is already assigned as a leader" % character_id)

	return _ok()


func _is_slot_index_valid(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < leader_slots.size()


func _ok() -> Dictionary:
	return {
		"ok": true,
		"errors": []
	}


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": [message]
	}
