class_name QuestDefinition
extends RefCounted

const SCRIPT_PATH := "res://src/quests_events_endings/quest_definition.gd"
const QuestNodeScript := preload("res://src/quests_events_endings/quest_node.gd")

var id := ""
var name := ""
var objective := ""
var start_node_id := ""
var reward_pool_id := ""
var progression_reward_id := ""
var encounter_ids := []
var nodes := {}


func _init(definition: Dictionary = {}, content_indexes: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition, content_indexes)


static func from_dictionary(definition: Dictionary, content_indexes: Dictionary = {}):
	return load(SCRIPT_PATH).new(definition, content_indexes)


static func from_content_id(validated_content: Dictionary, quest_id: String):
	var indexes: Dictionary = validated_content.get("indexes", validated_content)
	var quest_rows: Dictionary = indexes.get("quests", {})
	if not quest_rows.has(quest_id):
		return null
	return load(SCRIPT_PATH).new(quest_rows[quest_id], indexes)


static func minimal_sample(content_indexes: Dictionary = {}):
	var encounters: Dictionary = content_indexes.get("encounters", {})
	var reward_pool_id_value := "reward_pool.prologue"
	var first_encounter_id := "encounter.road_ambush"
	var boss_encounter_id := first_encounter_id
	if encounters.has("encounter.foundry_gate"):
		boss_encounter_id = "encounter.foundry_gate"

	return load(SCRIPT_PATH).new(
		{
			"id": "quest.minimal_graph_sample",
			"name": "Minimal Quest Graph Sample",
			"objective": "Exercise quest node flow with placeholder content.",
			"reward_pool_id": reward_pool_id_value,
			"progression_reward_id": "progression.first_victory",
			"start_node_id": "start_event",
			"nodes": [
				{
					"id": "start_event",
					"type": QuestNodeScript.TYPE_EVENT,
					"next_node_id": "route_branch"
				},
				{
					"id": "route_branch",
					"type": QuestNodeScript.TYPE_BRANCH,
					"branch_options": [
						{"id": "standard_route", "next_node_id": "opening_battle"},
						{"id": "hard_route", "next_node_id": "elite_battle"}
					]
				},
				{
					"id": "opening_battle",
					"type": QuestNodeScript.TYPE_BATTLE,
					"encounter_id": first_encounter_id,
					"next_node_id": "reward_chest"
				},
				{
					"id": "elite_battle",
					"type": QuestNodeScript.TYPE_ELITE,
					"encounter_id": first_encounter_id,
					"next_node_id": "reward_chest",
					"rewards": {"exp": 18}
				},
				{
					"id": "reward_chest",
					"type": QuestNodeScript.TYPE_CHEST,
					"reward_pool_id": reward_pool_id_value,
					"next_node_id": "field_rest"
				},
				{
					"id": "field_rest",
					"type": QuestNodeScript.TYPE_REST,
					"heal_amount": 4,
					"next_node_id": "boss_battle"
				},
				{
					"id": "boss_battle",
					"type": QuestNodeScript.TYPE_BOSS,
					"encounter_id": boss_encounter_id,
					"next_node_id": "result",
					"combat_config": {"enemy_hp": 12, "enemy_max_hp": 12},
					"rewards": {
						"exp": 30,
						"medal_ids": ["medal.sample_clear"],
						"warzone_impact": {"warzone.sample": 2}
					}
				},
				{"id": "result", "type": QuestNodeScript.TYPE_RESULT}
			]
		},
		content_indexes
	)


func configure(definition: Dictionary, content_indexes: Dictionary = {}) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	objective = str(definition.get("objective", objective))
	reward_pool_id = str(definition.get("reward_pool_id", reward_pool_id))
	progression_reward_id = str(definition.get("progression_reward_id", progression_reward_id))

	var configured_encounters = definition.get("encounter_ids", [])
	if typeof(configured_encounters) == TYPE_ARRAY:
		encounter_ids = configured_encounters.duplicate(true)
	else:
		encounter_ids = []

	nodes.clear()
	start_node_id = str(definition.get("start_node_id", ""))
	var configured_nodes = definition.get("nodes", [])
	if typeof(configured_nodes) == TYPE_ARRAY and not configured_nodes.is_empty():
		_register_nodes(configured_nodes)
	else:
		_register_nodes(_legacy_nodes(content_indexes))

	if start_node_id.is_empty() and not nodes.is_empty():
		start_node_id = nodes.keys()[0]


func is_valid() -> bool:
	return not id.is_empty() and not start_node_id.is_empty() and nodes.has(start_node_id)


func get_start_node():
	return get_node(start_node_id)


func get_node(node_id: String):
	return nodes.get(node_id)


func get_node_ids() -> Array:
	return nodes.keys()


func to_dictionary() -> Dictionary:
	var node_rows := []
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node != null and node.has_method("to_dictionary"):
			node_rows.append(node.to_dictionary())

	return {
		"id": id,
		"name": name,
		"objective": objective,
		"start_node_id": start_node_id,
		"reward_pool_id": reward_pool_id,
		"progression_reward_id": progression_reward_id,
		"encounter_ids": encounter_ids.duplicate(true),
		"nodes": node_rows
	}


func _register_nodes(node_definitions: Array) -> void:
	for node_definition in node_definitions:
		if typeof(node_definition) != TYPE_DICTIONARY:
			continue
		var node = QuestNodeScript.new(node_definition)
		if node.is_valid():
			nodes[node.id] = node


func _legacy_nodes(content_indexes: Dictionary) -> Array:
	var graph := []
	graph.append(
		{
			"id": "start",
			"type": QuestNodeScript.TYPE_EVENT,
			"next_node_id": _first_legacy_step_id()
		}
	)

	for index in range(encounter_ids.size()):
		var node_id := "battle_%s" % index
		var next_id := "battle_%s" % (index + 1)
		if index == encounter_ids.size() - 1:
			next_id = "chest"
		var encounter_id := str(encounter_ids[index])
		graph.append(
			{
				"id": node_id,
				"type": _node_type_for_encounter(encounter_id, content_indexes, index),
				"encounter_id": encounter_id,
				"next_node_id": next_id
			}
		)

	graph.append(
		{
			"id": "chest",
			"type": QuestNodeScript.TYPE_CHEST,
			"reward_pool_id": reward_pool_id,
			"next_node_id": "result"
		}
	)
	graph.append({"id": "result", "type": QuestNodeScript.TYPE_RESULT})
	return graph


func _first_legacy_step_id() -> String:
	if encounter_ids.is_empty():
		return "chest"
	return "battle_0"


func _node_type_for_encounter(encounter_id: String, content_indexes: Dictionary, encounter_index: int) -> String:
	var encounters: Dictionary = content_indexes.get("encounters", {})
	var encounter: Dictionary = encounters.get(encounter_id, {})
	var tier := int(encounter.get("tier", 1))
	if tier >= 3:
		return QuestNodeScript.TYPE_BOSS
	if tier >= 2:
		return QuestNodeScript.TYPE_ELITE
	if encounter_index == encounter_ids.size() - 1 and tier >= 2:
		return QuestNodeScript.TYPE_BOSS
	return QuestNodeScript.TYPE_BATTLE
