class_name StatusInstance
extends RefCounted

var definition = null
var stacks := 1
var duration := 1


func _init(status_definition = null, stack_count: int = 1, duration_value: int = -1) -> void:
	definition = status_definition
	stacks = max(1, stack_count)
	if definition != null and duration_value < 0:
		duration = max(0, int(definition.default_duration))
	else:
		duration = max(0, duration_value)


func display_name() -> String:
	if definition != null and definition.has_method("display_name"):
		return definition.display_name()
	return "Unknown Status"


func effect_type() -> String:
	if definition == null:
		return ""
	return str(definition.effect_type)


func numeric_value() -> int:
	if definition == null:
		return 0
	return int(definition.numeric_value)


func to_dictionary() -> Dictionary:
	if definition == null:
		return {
			"id": "",
			"name": display_name(),
			"effect_type": "",
			"amount": stacks,
			"duration": duration
		}

	return {
		"id": definition.id,
		"name": definition.display_name(),
		"polarity": definition.polarity,
		"stack_rule": definition.stack_rule,
		"effect_type": definition.effect_type,
		"numeric_value": definition.numeric_value,
		"tick_timing": definition.tick_timing,
		"expire_timing": definition.expire_timing,
		"amount": stacks,
		"duration": duration
	}
