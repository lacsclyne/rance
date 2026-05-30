class_name CombatCommand
extends RefCounted

const SCRIPT_PATH := "res://src/combat/combat_command.gd"
const TYPE_USE_SKILL := "use_skill"
const TYPE_END_PLAYER_TURN := "end_player_turn"

var type := ""
var actor_id := ""
var target_id := ""
var skill := {}


func _init(command_type: String = "", payload: Dictionary = {}) -> void:
	type = command_type
	actor_id = str(payload.get("actor_id", ""))
	target_id = str(payload.get("target_id", ""))
	var payload_skill = payload.get("skill", {})
	if typeof(payload_skill) == TYPE_DICTIONARY:
		skill = payload_skill.duplicate(true)


static func use_skill(actor_id_value: String, skill_value: Dictionary, target_id_value: String = ""):
	return load(SCRIPT_PATH).new(
		TYPE_USE_SKILL,
		{
			"actor_id": actor_id_value,
			"target_id": target_id_value,
			"skill": skill_value
		}
	)


static func end_player_turn():
	return load(SCRIPT_PATH).new(TYPE_END_PLAYER_TURN)


func to_dictionary() -> Dictionary:
	return {
		"type": type,
		"actor_id": actor_id,
		"target_id": target_id,
		"skill": skill.duplicate(true)
	}
