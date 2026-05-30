class_name QuestNode
extends RefCounted

const TYPE_BATTLE := "battle"
const TYPE_ELITE := "elite"
const TYPE_BOSS := "boss"
const TYPE_EVENT := "event"
const TYPE_CHEST := "chest"
const TYPE_REST := "rest"
const TYPE_BRANCH := "branch"
const TYPE_RESULT := "result"

const VALID_TYPES := [
	TYPE_BATTLE,
	TYPE_ELITE,
	TYPE_BOSS,
	TYPE_EVENT,
	TYPE_CHEST,
	TYPE_REST,
	TYPE_BRANCH,
	TYPE_RESULT
]

var id := ""
var type := TYPE_EVENT
var next_node_id := ""
var encounter_id := ""
var reward_pool_id := ""
var branch_options := []
var rewards := {}
var payload := {}


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	type = str(definition.get("type", type))
	next_node_id = str(definition.get("next_node_id", definition.get("next", next_node_id)))
	encounter_id = str(definition.get("encounter_id", encounter_id))
	reward_pool_id = str(definition.get("reward_pool_id", reward_pool_id))

	var options = definition.get("branch_options", definition.get("options", []))
	if typeof(options) == TYPE_ARRAY:
		branch_options = options.duplicate(true)
	else:
		branch_options = []

	var reward_config = definition.get("rewards", {})
	if typeof(reward_config) == TYPE_DICTIONARY:
		rewards = reward_config.duplicate(true)
	else:
		rewards = {}

	payload = definition.duplicate(true)
	if payload.has("branch_options"):
		payload.erase("branch_options")
	if payload.has("options"):
		payload.erase("options")
	if payload.has("rewards"):
		payload.erase("rewards")


func is_valid() -> bool:
	return not id.is_empty() and VALID_TYPES.has(type)


func is_combat_node() -> bool:
	return [TYPE_BATTLE, TYPE_ELITE, TYPE_BOSS].has(type)


func is_terminal() -> bool:
	return type == TYPE_RESULT


func branch_next_node_id(choice_id: String = "") -> String:
	if branch_options.is_empty():
		return next_node_id

	for option in branch_options:
		if typeof(option) != TYPE_DICTIONARY:
			continue
		if choice_id.is_empty() or str(option.get("id", "")) == choice_id:
			return str(option.get("next_node_id", option.get("next", "")))
	return ""


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"next_node_id": next_node_id,
		"encounter_id": encounter_id,
		"reward_pool_id": reward_pool_id,
		"branch_options": branch_options.duplicate(true),
		"rewards": rewards.duplicate(true),
		"payload": payload.duplicate(true)
	}
