class_name EncounterDefinition
extends RefCounted

const IntentPatternScript := preload("res://src/combat/intent_pattern.gd")
const IntentTokenScript := preload("res://src/combat/intent_token.gd")

var id := ""
var name := ""
var intent_pattern = null


func _init(definition: Dictionary = {}) -> void:
	intent_pattern = IntentPatternScript.new()
	if not definition.is_empty():
		configure(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))

	var pattern_definition = definition.get("intent_pattern", {})
	if typeof(pattern_definition) == TYPE_DICTIONARY:
		intent_pattern = IntentPatternScript.new(pattern_definition)
	else:
		intent_pattern = IntentPatternScript.new()


static func from_enemy_actions(actions: Array):
	var definition = load("res://src/combat/encounter_definition.gd").new()
	definition.id = "encounter.inline"
	definition.name = "Inline Encounter"
	definition.intent_pattern = IntentPatternScript.from_enemy_actions(actions)
	return definition


static func default_encounter():
	return from_enemy_actions(
		[
			{
				"id": "enemy.basic_attack",
				"name": "Basic Attack",
				"target": "player_team",
				"effects": [{"type": "damage", "amount": 1}]
			}
		]
	)


func intents_for_turn(turn_number: int, context: Dictionary = {}) -> Array:
	if intent_pattern == null or intent_pattern.is_empty():
		return [IntentTokenScript.from_action(
			{
				"id": "enemy.basic_attack",
				"name": "Basic Attack",
				"target": "player_team",
				"effects": [{"type": "damage", "amount": 1}]
			}
		)]
	return intent_pattern.intents_for_turn(turn_number, context)
