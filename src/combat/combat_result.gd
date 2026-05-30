class_name CombatResult
extends RefCounted

const SCRIPT_PATH := "res://src/combat/combat_result.gd"
const OUTCOME_ONGOING := "ongoing"
const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

var ok := false
var message := ""
var logs := []
var snapshot := {}
var outcome := OUTCOME_ONGOING


func _init(
	is_ok: bool = false,
	result_message: String = "",
	result_logs: Array = [],
	result_snapshot: Dictionary = {},
	result_outcome: String = OUTCOME_ONGOING
) -> void:
	ok = is_ok
	message = result_message
	logs = result_logs.duplicate(true)
	snapshot = result_snapshot.duplicate(true)
	outcome = result_outcome


static func success(
	result_message: String,
	result_logs: Array = [],
	result_snapshot: Dictionary = {},
	result_outcome: String = OUTCOME_ONGOING
):
	return load(SCRIPT_PATH).new(true, result_message, result_logs, result_snapshot, result_outcome)


static func failure(
	result_message: String,
	result_logs: Array = [],
	result_snapshot: Dictionary = {},
	result_outcome: String = OUTCOME_ONGOING
):
	return load(SCRIPT_PATH).new(false, result_message, result_logs, result_snapshot, result_outcome)


func is_finished() -> bool:
	return outcome == OUTCOME_VICTORY or outcome == OUTCOME_DEFEAT


func to_dictionary() -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"logs": logs.duplicate(true),
		"snapshot": snapshot.duplicate(true),
		"outcome": outcome
	}
