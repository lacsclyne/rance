class_name CampaignState
extends RefCounted

const SCRIPT_PATH := "res://src/strategy_map/campaign_state.gd"
const FrontStateScript := preload("res://src/strategy_map/front_state.gd")
const StrategicActionScript := preload("res://src/strategy_map/strategic_action.gd")

var id := ""
var name := ""
var turn_number := 1
var fronts := {}
var actions := {}
var completed_quest_ids := []
var failed_quest_counts := {}
var settlement_history := []
var turn_history := []


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


static func from_dictionary(definition: Dictionary):
	return load(SCRIPT_PATH).new(definition)


static func minimal_sample():
	return load(SCRIPT_PATH).new(
		{
			"id": "campaign.front_pressure_sample",
			"name": "Front Pressure Sample",
			"turn_number": 1,
			"fronts": [
				{
					"id": "front.ember_pass",
					"name": "Ember Pass",
					"pressure": 42,
					"enemy_strength": 2,
					"natural_pressure_delta": 3,
					"available_quest_ids": ["quest.secure_crossroad"],
					"long_term_modifiers": {"pressure_drift_bonus": 0, "enemy_strength_bonus": 0}
				},
				{
					"id": "front.glass_marsh",
					"name": "Glass Marsh",
					"pressure": 72,
					"enemy_strength": 3,
					"natural_pressure_delta": 4,
					"available_quest_ids": ["quest.recover_relic"],
					"long_term_modifiers": {"pressure_drift_bonus": 1, "enemy_strength_bonus": 0}
				},
				{
					"id": "front.salt_coast",
					"name": "Salt Coast",
					"pressure": 58,
					"enemy_strength": 1,
					"natural_pressure_delta": 5,
					"available_quest_ids": ["quest.close_foundry"],
					"long_term_modifiers": {"pressure_drift_bonus": 0, "enemy_strength_bonus": 1}
				}
			],
			"actions": [
				{
					"id": "action.relieve_ember_pass",
					"name": "Relieve Ember Pass",
					"quest_id": "quest.secure_crossroad",
					"front_id": "front.ember_pass",
					"success_pressure_delta": -14,
					"failure_pressure_delta": 9,
					"success_enemy_strength_delta": 0,
					"failure_enemy_strength_delta": 1
				},
				{
					"id": "action.scout_glass_marsh",
					"name": "Scout Glass Marsh",
					"quest_id": "quest.recover_relic",
					"front_id": "front.glass_marsh",
					"success_pressure_delta": -16,
					"failure_pressure_delta": 12,
					"success_enemy_strength_delta": -1,
					"failure_enemy_strength_delta": 1
				},
				{
					"id": "action.break_salt_coast_camp",
					"name": "Break Salt Coast Camp",
					"quest_id": "quest.close_foundry",
					"front_id": "front.salt_coast",
					"success_pressure_delta": -18,
					"failure_pressure_delta": 14,
					"success_enemy_strength_delta": -1,
					"failure_enemy_strength_delta": 2
				}
			]
		}
	)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	turn_number = max(1, int(definition.get("turn_number", turn_number)))

	fronts.clear()
	var front_definitions = definition.get("fronts", [])
	if typeof(front_definitions) == TYPE_ARRAY:
		for front_definition in front_definitions:
			if typeof(front_definition) != TYPE_DICTIONARY:
				continue
			var front = FrontStateScript.new(front_definition)
			if front.call("is_valid"):
				fronts[front.get("id")] = front

	actions.clear()
	var action_definitions = definition.get("actions", [])
	if typeof(action_definitions) == TYPE_ARRAY:
		for action_definition in action_definitions:
			if typeof(action_definition) != TYPE_DICTIONARY:
				continue
			var action = StrategicActionScript.new(action_definition)
			if action.call("is_valid") and fronts.has(action.get("front_id")):
				actions[action.get("id")] = action

	completed_quest_ids = _string_array(definition.get("completed_quest_ids", []))
	failed_quest_counts = _dictionary_copy(definition.get("failed_quest_counts", {}))
	settlement_history.clear()
	turn_history.clear()


func is_valid() -> bool:
	return not id.is_empty() and fronts.size() >= 3 and not actions.is_empty()


func get_front(front_id: String):
	return fronts.get(front_id)


func get_front_snapshots() -> Array:
	var rows := []
	for front_id in fronts.keys():
		rows.append(fronts[front_id].call("to_dictionary"))
	return rows


func get_available_quests() -> Array:
	var offers := []
	for action_id in actions.keys():
		var action = actions[action_id]
		if completed_quest_ids.has(action.get("quest_id")):
			continue
		var front = fronts.get(action.get("front_id"))
		if front == null or not front.call("has_quest", action.get("quest_id")):
			continue
		var offer: Dictionary = action.call("to_offer", front, completed_quest_ids)
		if bool(offer.get("available", false)):
			offers.append(offer)
	return offers


func get_next_available_quests() -> Array:
	return get_available_quests()


func select_quest(quest_id: String) -> Dictionary:
	var action = _action_for_quest(quest_id)
	if action == null:
		return _error("quest '%s' is not linked to a strategic action" % quest_id)
	if completed_quest_ids.has(quest_id):
		return _error("quest '%s' is already completed" % quest_id)

	var front = fronts.get(action.get("front_id"))
	if front == null:
		return _error("front '%s' does not exist" % action.get("front_id"))
	if not front.call("has_quest", quest_id):
		return _error("quest '%s' is not assigned to front '%s'" % [quest_id, front.get("id")])

	var offer: Dictionary = action.call("to_offer", front, completed_quest_ids)
	if not bool(offer.get("available", false)):
		return _error("quest '%s' is unavailable: %s" % [quest_id, offer.get("reason", "")])

	return _ok(
		"Quest selected.",
		{
			"quest": offer,
			"front": front.call("to_dictionary")
		}
	)


func consume_quest_settlement(settlement_summary: Dictionary) -> Dictionary:
	var quest_id := str(settlement_summary.get("quest_id", ""))
	if quest_id.is_empty():
		return _error("settlement summary is missing quest_id")

	var action = _action_for_quest(quest_id)
	if action == null:
		return _error("quest '%s' has no campaign action" % quest_id)

	var front = fronts.get(action.get("front_id"))
	if front == null:
		return _error("front '%s' does not exist" % action.get("front_id"))

	var outcome := str(settlement_summary.get("outcome", ""))
	var success: bool = action.call("is_success_outcome", outcome)
	var pressure_delta: int = action.call("pressure_delta_for_outcome", outcome)
	pressure_delta += _extra_pressure_delta_from_summary(settlement_summary, front.get("id"))

	var pressure_change: Dictionary = front.call(
		"apply_pressure_delta",
		pressure_delta,
		"quest_%s_%s" % [outcome, quest_id]
	)
	var enemy_change: Dictionary = front.call(
		"apply_enemy_strength_delta",
		action.call("enemy_strength_delta_for_outcome", outcome),
		"quest_%s_%s" % [outcome, quest_id]
	)
	var momentum_change: Dictionary = front.call("apply_outcome_momentum", success)

	if success:
		_add_unique(completed_quest_ids, quest_id)
	else:
		failed_quest_counts[quest_id] = int(failed_quest_counts.get(quest_id, 0)) + 1

	var result := {
		"ok": true,
		"message": "Quest settlement consumed.",
		"quest_id": quest_id,
		"front_id": front.get("id"),
		"outcome": outcome,
		"success": success,
		"pressure_change": pressure_change,
		"enemy_strength_change": enemy_change,
		"momentum_change": momentum_change,
		"completed_quest_ids": completed_quest_ids.duplicate(true),
		"failed_quest_counts": failed_quest_counts.duplicate(true),
		"next_available_quests": get_available_quests()
	}
	settlement_history.append(result.duplicate(true))
	return result


func advance_turn() -> Dictionary:
	turn_number += 1
	var front_changes := []
	for front_id in fronts.keys():
		front_changes.append(fronts[front_id].call("apply_natural_pressure", turn_number))

	var result := {
		"ok": true,
		"message": "Strategic turn advanced.",
		"turn_number": turn_number,
		"front_changes": front_changes,
		"available_quests": get_available_quests()
	}
	turn_history.append(result.duplicate(true))
	return result


func simulate_no_ui_step(quest_id: String, settlement_summary: Dictionary) -> Dictionary:
	var selection := select_quest(quest_id)
	if not bool(selection.get("ok", false)):
		return selection
	if str(settlement_summary.get("quest_id", "")) != quest_id:
		return _error("settlement summary quest_id does not match selected quest '%s'" % quest_id)

	var settlement := consume_quest_settlement(settlement_summary)
	if not bool(settlement.get("ok", false)):
		return settlement

	var next_turn := advance_turn()
	return _ok(
		"No-UI strategic step simulated.",
		{
			"selected_quest": selection.get("quest", {}),
			"settlement": settlement,
			"next_turn": next_turn,
			"fronts": get_front_snapshots()
		}
	)


func to_dictionary() -> Dictionary:
	var front_rows := []
	for front_id in fronts.keys():
		front_rows.append(fronts[front_id].call("to_dictionary"))

	var action_rows := []
	for action_id in actions.keys():
		action_rows.append(actions[action_id].call("to_dictionary"))

	return {
		"id": id,
		"name": name,
		"turn_number": turn_number,
		"fronts": front_rows,
		"actions": action_rows,
		"completed_quest_ids": completed_quest_ids.duplicate(true),
		"failed_quest_counts": failed_quest_counts.duplicate(true),
		"available_quests": get_available_quests()
	}


func _action_for_quest(quest_id: String):
	for action_id in actions.keys():
		var action = actions[action_id]
		if action.get("quest_id") == quest_id:
			return action
	return null


func _extra_pressure_delta_from_summary(settlement_summary: Dictionary, front_id: String) -> int:
	var configured_delta = settlement_summary.get("front_pressure_delta", {})
	if typeof(configured_delta) == TYPE_DICTIONARY and configured_delta.has(front_id):
		return int(configured_delta[front_id])
	return 0


func _string_array(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var rows := []
	for item in value:
		rows.append(str(item))
	return rows


func _dictionary_copy(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}


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
