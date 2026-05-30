class_name FrontState
extends RefCounted

const SCRIPT_PATH := "res://src/strategy_map/front_state.gd"

const PRESSURE_STABLE := "stable"
const PRESSURE_STRAINED := "strained"
const PRESSURE_HIGH := "high"
const PRESSURE_CRITICAL := "critical"

var id := ""
var name := ""
var pressure := 0
var pressure_min := 0
var pressure_max := 100
var high_pressure_threshold := 65
var critical_pressure_threshold := 85
var enemy_strength := 1
var natural_pressure_delta := 3
var available_quest_ids := []
var long_term_modifiers := {}
var pressure_history := []


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


static func from_dictionary(definition: Dictionary):
	return load(SCRIPT_PATH).new(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	pressure_min = int(definition.get("pressure_min", pressure_min))
	pressure_max = int(definition.get("pressure_max", pressure_max))
	pressure = _clamped_pressure(int(definition.get("pressure", pressure)))
	high_pressure_threshold = int(definition.get("high_pressure_threshold", high_pressure_threshold))
	critical_pressure_threshold = int(definition.get("critical_pressure_threshold", critical_pressure_threshold))
	enemy_strength = max(1, int(definition.get("enemy_strength", enemy_strength)))
	natural_pressure_delta = int(definition.get("natural_pressure_delta", natural_pressure_delta))

	var configured_quests = definition.get("available_quest_ids", definition.get("quest_ids", []))
	if typeof(configured_quests) == TYPE_ARRAY:
		available_quest_ids = configured_quests.duplicate(true)
	else:
		available_quest_ids = []

	var configured_modifiers = definition.get("long_term_modifiers", {})
	if typeof(configured_modifiers) == TYPE_DICTIONARY:
		long_term_modifiers = configured_modifiers.duplicate(true)
	else:
		long_term_modifiers = {}

	pressure_history.clear()


func is_valid() -> bool:
	return not id.is_empty() and not name.is_empty()


func has_quest(quest_id: String) -> bool:
	return available_quest_ids.has(quest_id)


func apply_natural_pressure(turn_number: int) -> Dictionary:
	return apply_pressure_delta(get_natural_pressure_delta(), "turn_%s_natural" % turn_number)


func apply_pressure_delta(delta: int, reason: String = "") -> Dictionary:
	var before := pressure
	pressure = _clamped_pressure(pressure + delta)
	var entry := {
		"front_id": id,
		"reason": reason,
		"pressure_before": before,
		"pressure_after": pressure,
		"pressure_delta": pressure - before,
		"pressure_band": get_pressure_band()
	}
	pressure_history.append(entry)
	return entry


func apply_enemy_strength_delta(delta: int, reason: String = "") -> Dictionary:
	var before := enemy_strength
	enemy_strength = max(1, enemy_strength + delta)
	return {
		"front_id": id,
		"reason": reason,
		"enemy_strength_before": before,
		"enemy_strength_after": enemy_strength,
		"enemy_strength_delta": enemy_strength - before
	}


func apply_outcome_momentum(success: bool) -> Dictionary:
	var before := int(long_term_modifiers.get("momentum", 0))
	var next_value := before - 1 if success else before + 1
	long_term_modifiers["momentum"] = clamp(next_value, -2, 3)
	return {
		"front_id": id,
		"momentum_before": before,
		"momentum_after": int(long_term_modifiers["momentum"])
	}


func get_natural_pressure_delta() -> int:
	return (
		natural_pressure_delta
		+ int(long_term_modifiers.get("pressure_drift_bonus", 0))
		+ int(long_term_modifiers.get("momentum", 0))
	)


func get_pressure_band() -> String:
	if pressure >= critical_pressure_threshold:
		return PRESSURE_CRITICAL
	if pressure >= high_pressure_threshold:
		return PRESSURE_HIGH
	if pressure >= int(floor(float(high_pressure_threshold) * 0.7)):
		return PRESSURE_STRAINED
	return PRESSURE_STABLE


func is_high_pressure() -> bool:
	return pressure >= high_pressure_threshold


func get_pressure_enemy_bonus() -> int:
	if pressure >= critical_pressure_threshold:
		return 2
	if pressure >= high_pressure_threshold:
		return 1
	return 0


func get_effective_enemy_strength(extra_bonus: int = 0) -> int:
	return max(
		1,
		enemy_strength
		+ get_pressure_enemy_bonus()
		+ int(long_term_modifiers.get("enemy_strength_bonus", 0))
		+ extra_bonus
	)


func get_reward_tier() -> String:
	if pressure >= critical_pressure_threshold:
		return "reduced"
	if pressure >= high_pressure_threshold:
		return "reduced"
	return "standard"


func get_quest_modifiers(extra_enemy_bonus: int = 0) -> Dictionary:
	return {
		"pressure": pressure,
		"pressure_band": get_pressure_band(),
		"enemy_strength": get_effective_enemy_strength(extra_enemy_bonus),
		"reward_tier": get_reward_tier(),
		"long_term_modifiers": long_term_modifiers.duplicate(true)
	}


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"pressure": pressure,
		"pressure_min": pressure_min,
		"pressure_max": pressure_max,
		"high_pressure_threshold": high_pressure_threshold,
		"critical_pressure_threshold": critical_pressure_threshold,
		"enemy_strength": enemy_strength,
		"natural_pressure_delta": natural_pressure_delta,
		"available_quest_ids": available_quest_ids.duplicate(true),
		"long_term_modifiers": long_term_modifiers.duplicate(true),
		"pressure_band": get_pressure_band(),
		"effective_enemy_strength": get_effective_enemy_strength(),
		"reward_tier": get_reward_tier()
	}


func _clamped_pressure(value: int) -> int:
	return clamp(value, pressure_min, pressure_max)
