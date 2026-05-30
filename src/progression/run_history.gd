class_name RunHistory
extends RefCounted

const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

var current_run_index := 1
var quest_results := []
var first_completed_quests := {}
var first_failed_quests := {}
var completed_runs := []


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		configure(snapshot)


func configure(snapshot: Dictionary) -> void:
	current_run_index = max(1, int(snapshot.get("current_run_index", current_run_index)))
	quest_results = _array_copy(snapshot.get("quest_results", []))
	first_completed_quests = _dictionary_copy(snapshot.get("first_completed_quests", {}))
	first_failed_quests = _dictionary_copy(snapshot.get("first_failed_quests", {}))
	completed_runs = _array_copy(snapshot.get("completed_runs", []))


func begin_run(run_index: int, carryover_summary: Dictionary = {}) -> void:
	current_run_index = max(1, run_index)
	quest_results.clear()
	if not carryover_summary.is_empty():
		quest_results.append(
			{
				"type": "run_started",
				"run_index": current_run_index,
				"carryover": _dictionary_copy(carryover_summary)
			}
		)


func record_quest_result(
	quest_id: String,
	outcome: String,
	source: String = "",
	summary: Dictionary = {}
) -> bool:
	if quest_id.is_empty():
		return false

	var record := {
		"quest_id": quest_id,
		"outcome": outcome,
		"source": source,
		"run_index": current_run_index
	}
	if summary.has("completed_node_ids"):
		record["completed_node_ids"] = _array_copy(summary.get("completed_node_ids", []))
	if summary.has("medal_ids"):
		record["medal_ids"] = _array_copy(summary.get("medal_ids", []))
	if summary.has("progression_reward_ids"):
		record["progression_reward_ids"] = _array_copy(summary.get("progression_reward_ids", []))
	quest_results.append(record)

	match outcome:
		OUTCOME_VICTORY, "completed", "complete", "success":
			if not first_completed_quests.has(quest_id):
				first_completed_quests[quest_id] = _first_record(source)
		OUTCOME_DEFEAT, "failed", "failure":
			if not first_failed_quests.has(quest_id):
				first_failed_quests[quest_id] = _first_record(source)

	return true


func complete_current_run(summary: Dictionary = {}) -> Dictionary:
	var run_record := {
		"run_index": current_run_index,
		"summary": _dictionary_copy(summary),
		"quest_result_count": quest_results.size()
	}
	completed_runs.append(run_record)
	return run_record.duplicate(true)


func get_completed_run_count() -> int:
	return completed_runs.size()


func to_dictionary() -> Dictionary:
	return {
		"current_run_index": current_run_index,
		"quest_results": _array_copy(quest_results),
		"first_completed_quests": _dictionary_copy(first_completed_quests),
		"first_failed_quests": _dictionary_copy(first_failed_quests),
		"completed_runs": _array_copy(completed_runs)
	}


func _first_record(source: String) -> Dictionary:
	return {
		"source": source,
		"run_index": current_run_index
	}


func _dictionary_copy(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return _json_friendly_copy(value)
	return {}


func _array_copy(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return _json_friendly_copy(value)
	return []


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
