class_name ProgressionState
extends RefCounted

const SCRIPT_PATH := "res://src/progression/progression_state.gd"
const CarryoverStateScript := preload("res://src/progression/carryover_state.gd")
const DiscoveryLogScript := preload("res://src/progression/discovery_log.gd")
const RunHistoryScript := preload("res://src/progression/run_history.gd")

const RANK_MEDAL_THRESHOLDS := {
	1: 0,
	2: 1,
	3: 3,
	4: 6,
	5: 10
}

const RANK_REWARD_DEFINITIONS := [
	{
		"id": "rank_reward.frontline_slot_1",
		"name": "Frontline Slot Placeholder",
		"required_rank": 2,
		"system_unlocks": {"frontline_slots_bonus": 1},
		"carryover": true
	},
	{
		"id": "rank_reward.ap_training_1",
		"name": "AP Training Placeholder",
		"required_rank": 3,
		"system_unlocks": {"max_ap_bonus": 1, "ap_recovery_bonus": 1},
		"carryover": true
	},
	{
		"id": "rank_reward.reward_weight_1",
		"name": "Reward Weight Placeholder",
		"required_rank": 4,
		"system_unlocks": {"reward_weight_bonus": 1},
		"carryover": true
	}
]

var medal_total := 0
var medal_counts := {}
var rank := 1
var rank_log := []
var selected_rank_reward_ids := []
var system_unlocks := {}
var unlocked_progression_node_ids := []
var unlocked_content_ids_by_kind := {}
var discovery_log = DiscoveryLogScript.new()
var run_history = RunHistoryScript.new()


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		configure(snapshot)
	else:
		_initialize_system_unlocks()


static func from_carryover(carryover_state):
	var state = load(SCRIPT_PATH).new()
	var seed := {}
	if carryover_state != null:
		if typeof(carryover_state) == TYPE_DICTIONARY:
			seed = carryover_state
		elif carryover_state.has_method("create_new_run_seed"):
			seed = carryover_state.call("create_new_run_seed")

	state.discovery_log = DiscoveryLogScript.new(seed.get("discovery_log", {}))
	state.selected_rank_reward_ids = state._string_array(seed.get("selected_rank_reward_ids", []))
	state._initialize_system_unlocks()
	state._merge_system_unlocks(seed.get("system_unlocks", {}))
	state.run_history.begin_run(max(1, int(seed.get("run_index", 1))), {"carryover_applied": true})
	return state


func configure(snapshot: Dictionary) -> void:
	medal_total = max(0, int(snapshot.get("medal_total", 0)))
	medal_counts = _dictionary_copy(snapshot.get("medal_counts", {}))
	rank = max(1, int(snapshot.get("rank", rank)))
	rank_log = _array_copy(snapshot.get("rank_log", []))
	selected_rank_reward_ids = _string_array(snapshot.get("selected_rank_reward_ids", []))
	system_unlocks = {}
	unlocked_progression_node_ids = _string_array(snapshot.get("unlocked_progression_node_ids", []))
	unlocked_content_ids_by_kind = _dictionary_copy(snapshot.get("unlocked_content_ids_by_kind", {}))
	discovery_log = DiscoveryLogScript.new(_dictionary_copy(snapshot.get("discovery_log", {})))
	run_history = RunHistoryScript.new(_dictionary_copy(snapshot.get("run_history", {})))

	_initialize_system_unlocks()
	for reward_id in selected_rank_reward_ids:
		_apply_rank_reward_definition(_rank_reward_definition(str(reward_id)))
	_refresh_rank(false)


func consume_quest_settlement(settlement_summary: Dictionary, content_indexes: Dictionary = {}) -> Dictionary:
	var quest_id := str(settlement_summary.get("quest_id", ""))
	if quest_id.is_empty():
		return _error("settlement summary is missing quest_id")

	var old_rank := rank
	var outcome := str(settlement_summary.get("outcome", ""))
	var source := "quest:%s" % quest_id
	run_history.record_quest_result(quest_id, outcome, source, settlement_summary)
	discovery_log.record_quest_outcome(quest_id, outcome, source, run_history.current_run_index)

	for medal_id in _string_array(settlement_summary.get("medal_ids", [])):
		add_medal(medal_id, source)

	for progression_id in _string_array(settlement_summary.get("progression_reward_ids", [])):
		unlock_progression_node(progression_id, content_indexes, source)

	_record_boss_intel_from_settlement(settlement_summary, source)

	return _ok(
		"Quest settlement consumed by progression.",
		{
			"quest_id": quest_id,
			"rank": rank,
			"previous_rank": old_rank,
			"rank_changed": rank != old_rank,
			"pending_rank_reward_choices": get_pending_rank_reward_choices()
		}
	)


func add_medal(medal_id: String, source: String = "") -> Dictionary:
	if medal_id.is_empty():
		return _error("medal id is required")

	medal_counts[medal_id] = int(medal_counts.get(medal_id, 0)) + 1
	medal_total += 1
	var old_rank := rank
	_refresh_rank(true, source)
	return _ok(
		"Medal added.",
		{
			"medal_id": medal_id,
			"medal_total": medal_total,
			"rank": rank,
			"previous_rank": old_rank,
			"rank_changed": rank != old_rank
		}
	)


func unlock_progression_node(
	progression_id: String,
	content_indexes: Dictionary = {},
	source: String = ""
) -> Dictionary:
	if progression_id.is_empty():
		return _error("progression id is required")
	if unlocked_progression_node_ids.has(progression_id):
		return _ok("Progression node already unlocked.", {"progression_id": progression_id})

	var node_definition := _progression_node_definition(progression_id, content_indexes)
	if not node_definition.is_empty() and not _requirements_met(node_definition):
		return _error("progression node '%s' requirements are not met" % progression_id)

	_add_unique(unlocked_progression_node_ids, progression_id)
	if node_definition.is_empty():
		return _ok("Progression node unlocked.", {"progression_id": progression_id})

	for unlock in _array_or_empty(node_definition.get("unlocks", [])):
		if typeof(unlock) != TYPE_DICTIONARY:
			continue
		var kind := str(unlock.get("kind", ""))
		var content_id := str(unlock.get("content_id", ""))
		if kind.is_empty() or content_id.is_empty():
			continue
		_add_unlocked_content(kind, content_id)
		if kind == "character":
			discovery_log.record_character_obtained(content_id, source, run_history.current_run_index)

	return _ok("Progression node unlocked.", {"progression_id": progression_id})


func can_choose_rank_reward(reward_id: String) -> bool:
	if selected_rank_reward_ids.has(reward_id):
		return false
	if get_pending_rank_reward_choices() <= 0:
		return false
	var definition := _rank_reward_definition(reward_id)
	if definition.is_empty():
		return false
	return rank >= int(definition.get("required_rank", 1))


func choose_rank_reward(reward_id: String) -> Dictionary:
	if selected_rank_reward_ids.has(reward_id):
		return _error("rank reward '%s' is already selected" % reward_id)

	var definition := _rank_reward_definition(reward_id)
	if definition.is_empty():
		return _error("rank reward '%s' does not exist" % reward_id)
	if rank < int(definition.get("required_rank", 1)):
		return _error("rank reward '%s' requires rank %s" % [reward_id, definition.get("required_rank", 1)])
	if get_pending_rank_reward_choices() <= 0:
		return _error("no pending rank reward choices are available")

	selected_rank_reward_ids.append(reward_id)
	_apply_rank_reward_definition(definition)
	return _ok(
		"Rank reward selected.",
		{
			"reward_id": reward_id,
			"system_unlocks": get_system_unlocks(),
			"pending_rank_reward_choices": get_pending_rank_reward_choices()
		}
	)


func get_available_rank_rewards() -> Array:
	var rows := []
	for definition in RANK_REWARD_DEFINITIONS:
		var reward_id := str(definition.get("id", ""))
		if not selected_rank_reward_ids.has(reward_id) and rank >= int(definition.get("required_rank", 1)):
			rows.append(definition.duplicate(true))
	return rows


func get_pending_rank_reward_choices() -> int:
	return max(0, rank - 1 - selected_rank_reward_ids.size())


func get_system_unlocks() -> Dictionary:
	return _dictionary_copy(system_unlocks)


func get_combat_config_unlocks() -> Dictionary:
	return {
		"max_ap_bonus": int(system_unlocks.get("max_ap_bonus", 0)),
		"ap_recovery_bonus": int(system_unlocks.get("ap_recovery_bonus", 0))
	}


func get_reward_weight_modifiers() -> Dictionary:
	return {
		"global_bonus": int(system_unlocks.get("reward_weight_bonus", 0))
	}


func get_frontline_slot_bonus() -> int:
	return int(system_unlocks.get("frontline_slots_bonus", 0))


func get_medal_total() -> int:
	return medal_total


func get_rank() -> int:
	return rank


func record_character_obtained(character_id: String, source: String = "") -> bool:
	return discovery_log.record_character_obtained(character_id, source, run_history.current_run_index)


func record_boss_preview(
	boss_id: String,
	preview_id: String,
	source: String = "",
	details: Dictionary = {}
) -> bool:
	return discovery_log.record_boss_preview(
		boss_id,
		preview_id,
		source,
		run_history.current_run_index,
		details
	)


func record_boss_weakness(
	boss_id: String,
	weakness_id: String,
	source: String = "",
	details: Dictionary = {}
) -> bool:
	return discovery_log.record_boss_weakness(
		boss_id,
		weakness_id,
		source,
		run_history.current_run_index,
		details
	)


func get_discovery_snapshot() -> Dictionary:
	return discovery_log.to_dictionary()


func get_run_history_snapshot() -> Dictionary:
	return run_history.to_dictionary()


func create_carryover_state():
	return CarryoverStateScript.from_progression_state(self)


func to_dictionary() -> Dictionary:
	return {
		"medal_total": medal_total,
		"medal_counts": _dictionary_copy(medal_counts),
		"rank": rank,
		"rank_log": _array_copy(rank_log),
		"selected_rank_reward_ids": selected_rank_reward_ids.duplicate(true),
		"system_unlocks": get_system_unlocks(),
		"unlocked_progression_node_ids": unlocked_progression_node_ids.duplicate(true),
		"unlocked_content_ids_by_kind": _dictionary_copy(unlocked_content_ids_by_kind),
		"discovery_log": discovery_log.to_dictionary(),
		"run_history": run_history.to_dictionary()
	}


func _refresh_rank(record_change: bool, source: String = "") -> void:
	var previous_rank := rank
	var new_rank := 1
	for threshold_rank in RANK_MEDAL_THRESHOLDS.keys():
		if medal_total >= int(RANK_MEDAL_THRESHOLDS[threshold_rank]):
			new_rank = max(new_rank, int(threshold_rank))
	rank = new_rank

	if record_change and rank > previous_rank:
		rank_log.append(
			{
				"from_rank": previous_rank,
				"to_rank": rank,
				"medal_total": medal_total,
				"source": source,
				"run_index": run_history.current_run_index
			}
		)


func _rank_reward_definition(reward_id: String) -> Dictionary:
	for definition in RANK_REWARD_DEFINITIONS:
		if str(definition.get("id", "")) == reward_id:
			return definition.duplicate(true)
	return {}


func _apply_rank_reward_definition(definition: Dictionary) -> void:
	if definition.is_empty():
		return
	_merge_system_unlocks(definition.get("system_unlocks", {}))


func _initialize_system_unlocks() -> void:
	var existing := _dictionary_copy(system_unlocks)
	system_unlocks = {
		"frontline_slots_bonus": 0,
		"max_ap_bonus": 0,
		"ap_recovery_bonus": 0,
		"reward_weight_bonus": 0
	}
	_merge_system_unlocks(existing)


func _merge_system_unlocks(unlocks) -> void:
	if typeof(unlocks) != TYPE_DICTIONARY:
		return
	for key in unlocks.keys():
		var unlock_key := str(key)
		system_unlocks[unlock_key] = int(system_unlocks.get(unlock_key, 0)) + int(unlocks[key])


func _progression_node_definition(progression_id: String, content_indexes: Dictionary) -> Dictionary:
	var indexes := _extract_indexes(content_indexes)
	var nodes: Dictionary = indexes.get("progression_nodes", {})
	if nodes.has(progression_id) and typeof(nodes[progression_id]) == TYPE_DICTIONARY:
		return nodes[progression_id]
	return {}


func _requirements_met(node_definition: Dictionary) -> bool:
	for required_id in _string_array(node_definition.get("requires", [])):
		if not unlocked_progression_node_ids.has(required_id):
			return false
	return true


func _add_unlocked_content(kind: String, content_id: String) -> void:
	var ids: Array = unlocked_content_ids_by_kind.get(kind, [])
	_add_unique(ids, content_id)
	unlocked_content_ids_by_kind[kind] = ids


func _record_boss_intel_from_settlement(settlement_summary: Dictionary, source: String) -> void:
	for combat_result in _array_or_empty(settlement_summary.get("combat_results", [])):
		if typeof(combat_result) != TYPE_DICTIONARY:
			continue
		if str(combat_result.get("node_type", "")) != "boss":
			continue

		var boss_id := str(combat_result.get("encounter_id", ""))
		if boss_id.is_empty():
			continue
		var snapshot: Dictionary = combat_result.get("snapshot", {})
		for intent in _array_or_empty(snapshot.get("enemy_intents", [])):
			if typeof(intent) == TYPE_DICTIONARY:
				discovery_log.record_boss_preview(
					boss_id,
					str(intent.get("id", "")),
					source,
					run_history.current_run_index,
					intent
				)


func _extract_indexes(content_indexes: Dictionary) -> Dictionary:
	if content_indexes.has("indexes"):
		return content_indexes.get("indexes", {})
	return content_indexes


func _array_or_empty(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


func _string_array(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var rows := []
	for item in value:
		rows.append(str(item))
	return rows


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


func _add_unique(target: Array, value: String) -> void:
	if value.is_empty():
		return
	if not target.has(value):
		target.append(value)


func _ok(message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": true,
		"message": message,
		"errors": []
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"errors": [message]
	}
