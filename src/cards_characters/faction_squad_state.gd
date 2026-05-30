class_name FactionSquadState
extends RefCounted

var faction_id := ""
var faction_definition := {}
var member_character_ids := []
var leader_character_ids := []
var base_at := 0
var base_hp := 0
var leader_at_bonus := 0
var leader_hp_bonus := 0


func _init(new_faction_id: String = "", new_faction_definition: Dictionary = {}) -> void:
	faction_id = new_faction_id
	faction_definition = new_faction_definition.duplicate(true)


func add_member(character_id: String, at_value: int, hp_value: int) -> void:
	if not member_character_ids.has(character_id):
		member_character_ids.append(character_id)
	member_character_ids.sort()
	base_at += max(0, at_value)
	base_hp += max(0, hp_value)


func add_leader_bonus(character_id: String, at_bonus: int, hp_bonus: int) -> void:
	if not leader_character_ids.has(character_id):
		leader_character_ids.append(character_id)
	leader_character_ids.sort()
	leader_at_bonus += max(0, at_bonus)
	leader_hp_bonus += max(0, hp_bonus)


func get_at() -> int:
	return base_at + leader_at_bonus


func get_attack() -> int:
	return get_at()


func get_hp() -> int:
	return base_hp + leader_hp_bonus


func duplicate_state():
	var copy = get_script().new(faction_id, faction_definition)
	copy.member_character_ids = member_character_ids.duplicate()
	copy.leader_character_ids = leader_character_ids.duplicate()
	copy.base_at = base_at
	copy.base_hp = base_hp
	copy.leader_at_bonus = leader_at_bonus
	copy.leader_hp_bonus = leader_hp_bonus
	return copy


func get_summary() -> Dictionary:
	return {
		"faction_id": faction_id,
		"member_character_ids": member_character_ids.duplicate(),
		"leader_character_ids": leader_character_ids.duplicate(),
		"base_at": base_at,
		"base_hp": base_hp,
		"leader_at_bonus": leader_at_bonus,
		"leader_hp_bonus": leader_hp_bonus,
		"at": get_at(),
		"hp": get_hp()
	}
