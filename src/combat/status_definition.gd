class_name StatusDefinition
extends RefCounted

const TYPE_DAMAGE_OVER_TIME := "damage_over_time"
const TYPE_VULNERABLE := "vulnerable"
const TYPE_WEAKEN := "weaken"
const TYPE_GUARD := "guard"
const TYPE_SEAL := "seal"
const TYPE_HEAL_BLOCK := "heal_block"

const TICK_NONE := "none"
const TICK_TURN_START := "turn_start"
const TICK_TURN_END := "turn_end"

const SUPPORTED_TYPES := [
	TYPE_DAMAGE_OVER_TIME,
	TYPE_VULNERABLE,
	TYPE_WEAKEN,
	TYPE_GUARD,
	TYPE_SEAL,
	TYPE_HEAL_BLOCK
]

const SUPPORTED_TIMINGS := [
	TICK_NONE,
	TICK_TURN_START,
	TICK_TURN_END
]

var id := ""
var name := ""
var polarity := ""
var stack_rule := ""
var default_duration := 1
var description := ""
var effect_type := ""
var numeric_value := 0
var tick_timing := TICK_NONE
var expire_timing := TICK_TURN_END


func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", ""))
	name = str(data.get("name", id))
	polarity = str(data.get("polarity", ""))
	stack_rule = str(data.get("stack_rule", "replace"))
	default_duration = max(0, int(data.get("default_duration", 1)))
	description = str(data.get("description", ""))
	effect_type = str(data.get("effect_type", ""))
	numeric_value = max(0, int(data.get("numeric_value", 0)))
	tick_timing = str(data.get("tick_timing", TICK_NONE))
	expire_timing = str(data.get("expire_timing", TICK_TURN_END))


func is_valid() -> bool:
	return not id.is_empty() \
		and SUPPORTED_TYPES.has(effect_type) \
		and SUPPORTED_TIMINGS.has(tick_timing) \
		and SUPPORTED_TIMINGS.has(expire_timing)


func display_name() -> String:
	if name.is_empty():
		return id
	return name


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": display_name(),
		"polarity": polarity,
		"stack_rule": stack_rule,
		"default_duration": default_duration,
		"description": description,
		"effect_type": effect_type,
		"numeric_value": numeric_value,
		"tick_timing": tick_timing,
		"expire_timing": expire_timing
	}
