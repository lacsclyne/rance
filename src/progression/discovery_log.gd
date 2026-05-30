class_name DiscoveryLog
extends RefCounted

const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

var character_sources := {}
var quest_records := {}
var boss_intel := {}


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		configure(snapshot)


func configure(snapshot: Dictionary) -> void:
	character_sources = _dictionary_copy(snapshot.get("character_sources", {}))
	quest_records = _dictionary_copy(snapshot.get("quest_records", {}))
	boss_intel = _dictionary_copy(snapshot.get("boss_intel", {}))


func record_character_obtained(character_id: String, source: String = "", run_index: int = 1) -> bool:
	if character_id.is_empty() or character_sources.has(character_id):
		return false

	character_sources[character_id] = _source_record(source, run_index)
	return true


func get_character_source(character_id: String) -> Dictionary:
	return _dictionary_copy(character_sources.get(character_id, {}))


func record_quest_outcome(
	quest_id: String,
	outcome: String,
	source: String = "",
	run_index: int = 1
) -> bool:
	if quest_id.is_empty():
		return false

	var record: Dictionary = quest_records.get(quest_id, {})
	var outcome_key := ""
	match outcome:
		OUTCOME_VICTORY, "completed", "complete", "success":
			outcome_key = "first_completed"
		OUTCOME_DEFEAT, "failed", "failure":
			outcome_key = "first_failed"
		_:
			return false

	if record.has(outcome_key):
		return false

	record[outcome_key] = _source_record(source, run_index)
	quest_records[quest_id] = record
	return true


func get_quest_record(quest_id: String) -> Dictionary:
	return _dictionary_copy(quest_records.get(quest_id, {}))


func record_boss_preview(
	boss_id: String,
	preview_id: String,
	source: String = "",
	run_index: int = 1,
	details: Dictionary = {}
) -> bool:
	return _record_boss_fact(boss_id, "known_previews", preview_id, source, run_index, details)


func record_boss_weakness(
	boss_id: String,
	weakness_id: String,
	source: String = "",
	run_index: int = 1,
	details: Dictionary = {}
) -> bool:
	return _record_boss_fact(boss_id, "known_weaknesses", weakness_id, source, run_index, details)


func get_boss_record(boss_id: String) -> Dictionary:
	return _dictionary_copy(boss_intel.get(boss_id, {}))


func to_dictionary() -> Dictionary:
	return {
		"character_sources": _dictionary_copy(character_sources),
		"quest_records": _dictionary_copy(quest_records),
		"boss_intel": _dictionary_copy(boss_intel)
	}


func _record_boss_fact(
	boss_id: String,
	bucket: String,
	fact_id: String,
	source: String,
	run_index: int,
	details: Dictionary
) -> bool:
	if boss_id.is_empty() or fact_id.is_empty():
		return false

	var record: Dictionary = boss_intel.get(boss_id, {})
	var bucket_records: Dictionary = record.get(bucket, {})
	if bucket_records.has(fact_id):
		return false

	var fact_record := _source_record(source, run_index)
	for key in details.keys():
		fact_record[str(key)] = _json_friendly_copy(details[key])
	bucket_records[fact_id] = fact_record
	record[bucket] = bucket_records
	boss_intel[boss_id] = record
	return true


func _source_record(source: String, run_index: int) -> Dictionary:
	return {
		"source": source,
		"run_index": max(1, run_index)
	}


func _dictionary_copy(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return _json_friendly_copy(value)
	return {}


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
