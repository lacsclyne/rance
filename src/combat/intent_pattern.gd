class_name IntentPattern
extends RefCounted

const SCRIPT_PATH := "res://src/combat/intent_pattern.gd"
const IntentTokenScript := preload("res://src/combat/intent_token.gd")

var rotation := []
var conditional_intents := []
var key_turn_intents := {}


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


func configure(definition: Dictionary) -> void:
	rotation.clear()
	conditional_intents.clear()
	key_turn_intents.clear()

	var rotation_value = definition.get("rotation", definition.get("normal_rotation", []))
	if typeof(rotation_value) == TYPE_ARRAY:
		for entry in rotation_value:
			rotation.append(_intent_definitions_from_entry(entry))

	var conditional_value = definition.get("conditional", definition.get("conditional_intents", []))
	if typeof(conditional_value) == TYPE_ARRAY:
		for entry in conditional_value:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			conditional_intents.append(
				{
					"condition": _dictionary_or_empty(entry.get("condition", {})),
					"intents": _intent_definitions_from_entry(entry.get("intents", []))
				}
			)

	var key_turn_value = definition.get("key_turns", definition.get("boss_key_turns", []))
	if typeof(key_turn_value) == TYPE_ARRAY:
		for entry in key_turn_value:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var turn: int = max(1, int(entry.get("turn", 0)))
			key_turn_intents[str(turn)] = _intent_definitions_from_entry(entry.get("intents", []))
	elif typeof(key_turn_value) == TYPE_DICTIONARY:
		for turn_key in key_turn_value.keys():
			var turn: int = max(1, int(turn_key))
			key_turn_intents[str(turn)] = _intent_definitions_from_entry(key_turn_value[turn_key])


static func from_enemy_actions(actions: Array):
	var pattern = load(SCRIPT_PATH).new()
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY:
			pattern.rotation.append([IntentTokenScript.from_action(action).to_dictionary()])
	return pattern


func intents_for_turn(turn_number: int, context: Dictionary = {}) -> Array:
	var normalized_turn: int = max(1, turn_number)
	var key := str(normalized_turn)
	if key_turn_intents.has(key):
		return _tokens_from_definitions(key_turn_intents[key])

	for entry in conditional_intents:
		if _condition_matches(entry.get("condition", {}), context):
			return _tokens_from_definitions(entry.get("intents", []))

	if not rotation.is_empty():
		var index: int = (normalized_turn - 1) % rotation.size()
		return _tokens_from_definitions(rotation[index])

	return []


func is_empty() -> bool:
	return rotation.is_empty() and conditional_intents.is_empty() and key_turn_intents.is_empty()


func _tokens_from_definitions(definitions: Array) -> Array:
	var tokens := []
	for definition in definitions:
		if typeof(definition) == TYPE_DICTIONARY:
			tokens.append(IntentTokenScript.new(definition))
	return tokens


func _intent_definitions_from_entry(entry) -> Array:
	if typeof(entry) == TYPE_ARRAY:
		return _intent_definitions_from_array(entry)
	if typeof(entry) != TYPE_DICTIONARY:
		return []
	if entry.has("intents"):
		return _intent_definitions_from_entry(entry["intents"])
	return [entry.duplicate(true)]


func _intent_definitions_from_array(entries: Array) -> Array:
	var definitions := []
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			definitions.append(entry.duplicate(true))
	return definitions


func _condition_matches(condition, context: Dictionary) -> bool:
	if typeof(condition) != TYPE_DICTIONARY:
		return false

	match str(condition.get("type", "")):
		"enemy_hp_at_or_below":
			return _resource_at_or_below(
				int(context.get("enemy_hp", 0)),
				int(context.get("enemy_max_hp", 1)),
				condition
			)
		"player_hp_at_or_below":
			return _resource_at_or_below(
				int(context.get("player_hp", 0)),
				int(context.get("player_max_hp", 1)),
				condition
			)
		"turn_at_least":
			return int(context.get("turn_number", 0)) >= int(condition.get("turn", 1))
		_:
			return false


func _resource_at_or_below(current: int, maximum: int, condition: Dictionary) -> bool:
	if condition.has("value"):
		return current <= int(condition["value"])
	if condition.has("amount"):
		return current <= int(condition["amount"])
	if condition.has("percent"):
		var threshold := float(condition["percent"])
		if threshold > 1.0:
			threshold /= 100.0
		return maximum > 0 and (float(current) / float(maximum)) <= threshold
	return false


func _dictionary_or_empty(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}
