class_name StrategicAction
extends RefCounted

const SCRIPT_PATH := "res://src/strategy_map/strategic_action.gd"

const ACTION_QUEST := "quest"
const OUTCOME_VICTORY := "victory"
const OUTCOME_SUCCESS := "success"

var id := ""
var name := ""
var action_type := ACTION_QUEST
var quest_id := ""
var front_id := ""
var success_pressure_delta := -12
var failure_pressure_delta := 10
var success_enemy_strength_delta := 0
var failure_enemy_strength_delta := 1
var locked_pressure_threshold := 95
var reward_downgrade_pressure := 65
var enemy_strength_bonus := 0
var required_completed_quest_ids := []


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


static func from_dictionary(definition: Dictionary):
	return load(SCRIPT_PATH).new(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	action_type = str(definition.get("action_type", action_type))
	quest_id = str(definition.get("quest_id", quest_id))
	front_id = str(definition.get("front_id", front_id))
	success_pressure_delta = int(definition.get("success_pressure_delta", success_pressure_delta))
	failure_pressure_delta = int(definition.get("failure_pressure_delta", failure_pressure_delta))
	success_enemy_strength_delta = int(definition.get("success_enemy_strength_delta", success_enemy_strength_delta))
	failure_enemy_strength_delta = int(definition.get("failure_enemy_strength_delta", failure_enemy_strength_delta))
	locked_pressure_threshold = int(definition.get("locked_pressure_threshold", locked_pressure_threshold))
	reward_downgrade_pressure = int(definition.get("reward_downgrade_pressure", reward_downgrade_pressure))
	enemy_strength_bonus = int(definition.get("enemy_strength_bonus", enemy_strength_bonus))

	var required = definition.get("required_completed_quest_ids", definition.get("requires", []))
	if typeof(required) == TYPE_ARRAY:
		required_completed_quest_ids = required.duplicate(true)
	else:
		required_completed_quest_ids = []


func is_valid() -> bool:
	return not id.is_empty() and not quest_id.is_empty() and not front_id.is_empty()


func requirements_met(completed_quest_ids: Array) -> bool:
	for required_id in required_completed_quest_ids:
		if not completed_quest_ids.has(str(required_id)):
			return false
	return true


func is_pressure_locked(front) -> bool:
	if front == null:
		return true
	return int(front.get("pressure")) >= locked_pressure_threshold


func is_success_outcome(outcome: String) -> bool:
	return [OUTCOME_VICTORY, OUTCOME_SUCCESS].has(outcome)


func pressure_delta_for_outcome(outcome: String) -> int:
	if is_success_outcome(outcome):
		return success_pressure_delta
	return failure_pressure_delta


func enemy_strength_delta_for_outcome(outcome: String) -> int:
	if is_success_outcome(outcome):
		return success_enemy_strength_delta
	return failure_enemy_strength_delta


func reward_tier_for_front(front) -> String:
	if front == null:
		return "unavailable"
	if int(front.get("pressure")) >= reward_downgrade_pressure:
		return "reduced"
	return str(front.call("get_reward_tier"))


func to_offer(front, completed_quest_ids: Array) -> Dictionary:
	var available := (
		front != null
		and is_valid()
		and requirements_met(completed_quest_ids)
		and not is_pressure_locked(front)
	)

	var reason := ""
	if front == null:
		reason = "front_missing"
	elif not requirements_met(completed_quest_ids):
		reason = "requirements_missing"
	elif is_pressure_locked(front):
		reason = "front_pressure_locked"
	elif available:
		reason = "available"

	var pressure := 0
	var pressure_band := ""
	var enemy_strength := 0
	if front != null:
		pressure = int(front.get("pressure"))
		pressure_band = str(front.call("get_pressure_band"))
		enemy_strength = int(front.call("get_effective_enemy_strength", enemy_strength_bonus))

	return {
		"action_id": id,
		"action_type": action_type,
		"name": name,
		"quest_id": quest_id,
		"front_id": front_id,
		"available": available,
		"reason": reason,
		"pressure": pressure,
		"pressure_band": pressure_band,
		"enemy_strength": enemy_strength,
		"reward_tier": reward_tier_for_front(front)
	}


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"action_type": action_type,
		"quest_id": quest_id,
		"front_id": front_id,
		"success_pressure_delta": success_pressure_delta,
		"failure_pressure_delta": failure_pressure_delta,
		"success_enemy_strength_delta": success_enemy_strength_delta,
		"failure_enemy_strength_delta": failure_enemy_strength_delta,
		"locked_pressure_threshold": locked_pressure_threshold,
		"reward_downgrade_pressure": reward_downgrade_pressure,
		"enemy_strength_bonus": enemy_strength_bonus,
		"required_completed_quest_ids": required_completed_quest_ids.duplicate(true)
	}
