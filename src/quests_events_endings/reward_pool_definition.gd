class_name RewardPoolDefinition
extends RefCounted

const SCRIPT_PATH := "res://src/quests_events_endings/reward_pool_definition.gd"

var id := ""
var name := ""
var entries := []


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	var configured_entries = definition.get("entries", [])
	if typeof(configured_entries) == TYPE_ARRAY:
		entries = configured_entries.duplicate(true)
	else:
		entries = []


static func from_dictionary(definition: Dictionary):
	return load(SCRIPT_PATH).new(definition)


func is_valid() -> bool:
	return not id.is_empty() and not entries.is_empty()


func generate_candidates(candidate_count: int = 3, seed_value = null, weight_modifiers: Dictionary = {}) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_value == null:
		rng.randomize()
	else:
		rng.seed = int(seed_value)

	var remaining := []
	for index in range(entries.size()):
		var entry = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var weight: int = max(1, int(entry.get("weight", 1)) + _weight_bonus_for_entry(entry, weight_modifiers))
		var normalized: Dictionary = entry.duplicate(true)
		normalized["weight"] = weight
		normalized["entry_index"] = index
		remaining.append(normalized)

	var candidates := []
	while candidates.size() < candidate_count and not remaining.is_empty():
		var selected_index := _weighted_index(remaining, rng)
		var selected: Dictionary = remaining[selected_index]
		remaining.remove_at(selected_index)
		selected["reward_pool_id"] = id
		selected["candidate_id"] = "%s.%s" % [id, candidates.size()]
		candidates.append(selected)

	return candidates


func _weight_bonus_for_entry(entry: Dictionary, weight_modifiers: Dictionary) -> int:
	var bonus := int(weight_modifiers.get("global_bonus", weight_modifiers.get("reward_weight_bonus", 0)))
	var kind_bonuses = weight_modifiers.get("kind_bonuses", {})
	if typeof(kind_bonuses) == TYPE_DICTIONARY:
		bonus += int(kind_bonuses.get(str(entry.get("kind", "")), 0))

	var content_bonuses = weight_modifiers.get("content_bonuses", {})
	if typeof(content_bonuses) == TYPE_DICTIONARY:
		bonus += int(content_bonuses.get(str(entry.get("content_id", "")), 0))
	return bonus


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"entries": entries.duplicate(true)
	}


func _weighted_index(rows: Array, rng: RandomNumberGenerator) -> int:
	var total_weight := 0
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			total_weight += max(1, int(row.get("weight", 1)))

	if total_weight <= 0:
		return 0

	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		cursor += max(1, int(row.get("weight", 1)))
		if roll <= cursor:
			return index
	return rows.size() - 1
