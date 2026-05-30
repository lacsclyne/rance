class_name CarryoverState
extends RefCounted

var completed_run_count := 0
var max_rank_reached := 1
var discovery_log := {}
var selected_rank_reward_ids := []
var system_unlocks := {}


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		configure(snapshot)


func configure(snapshot: Dictionary) -> void:
	completed_run_count = max(0, int(snapshot.get("completed_run_count", completed_run_count)))
	max_rank_reached = max(1, int(snapshot.get("max_rank_reached", max_rank_reached)))
	discovery_log = _dictionary_copy(snapshot.get("discovery_log", {}))
	selected_rank_reward_ids = _string_array(snapshot.get("selected_rank_reward_ids", []))
	system_unlocks = _dictionary_copy(snapshot.get("system_unlocks", {}))


func to_dictionary() -> Dictionary:
	return {
		"completed_run_count": completed_run_count,
		"max_rank_reached": max_rank_reached,
		"discovery_log": _dictionary_copy(discovery_log),
		"selected_rank_reward_ids": selected_rank_reward_ids.duplicate(true),
		"system_unlocks": _dictionary_copy(system_unlocks)
	}


func create_new_run_seed() -> Dictionary:
	return {
		"run_index": completed_run_count + 1,
		"discovery_log": _dictionary_copy(discovery_log),
		"selected_rank_reward_ids": selected_rank_reward_ids.duplicate(true),
		"system_unlocks": _dictionary_copy(system_unlocks)
	}


static func from_progression_state(progression_state):
	var state = load("res://src/progression/carryover_state.gd").new()
	if progression_state == null or not progression_state.has_method("to_dictionary"):
		return state

	var snapshot: Dictionary = progression_state.call("to_dictionary")
	var run_history: Dictionary = snapshot.get("run_history", {})
	state.completed_run_count = max(1, int(run_history.get("completed_runs", []).size()))
	state.max_rank_reached = max(1, int(snapshot.get("rank", 1)))
	state.discovery_log = _dictionary_copy_static(snapshot.get("discovery_log", {}))
	state.selected_rank_reward_ids = _string_array_static(snapshot.get("selected_rank_reward_ids", []))
	state.system_unlocks = _dictionary_copy_static(snapshot.get("system_unlocks", {}))
	return state


static func _dictionary_copy_static(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return _json_friendly_copy_static(value)
	return {}


static func _string_array_static(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var rows := []
	for item in value:
		rows.append(str(item))
	return rows


static func _json_friendly_copy_static(value):
	if typeof(value) == TYPE_DICTIONARY:
		var copied := {}
		for key in value.keys():
			copied[str(key)] = _json_friendly_copy_static(value[key])
		return copied

	if typeof(value) == TYPE_ARRAY:
		var copied_array := []
		for item in value:
			copied_array.append(_json_friendly_copy_static(item))
		return copied_array

	return value


func _dictionary_copy(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return _json_friendly_copy(value)
	return {}


func _string_array(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var rows := []
	for item in value:
		rows.append(str(item))
	return rows


func _json_friendly_copy(value):
	if typeof(value) == TYPE_DICTIONARY:
		var copied := {}
		for key in value.keys():
			copied[str(key)] = _json_friendly_copy(value[key])
		return copied

	if typeof(value) == TYPE_ARRAY:
		var copied_array := []
		for item in value:
			copied_array.append(_json_friendly_copy(item))
		return copied_array

	return value
