class_name EnemyIntent
extends RefCounted

const IntentTokenScript := preload("res://src/combat/intent_token.gd")

var id := ""
var name := ""
var action_type := ""
var strength := 0
var target_scope := ""
var defendable := true
var interruptible := true
var source_id := ""
var effects := []

var canceled := false
var cancellation_reason := ""
var strength_multiplier := 1.0


func _init(token = {}) -> void:
	if typeof(token) == TYPE_DICTIONARY:
		configure(token)
	elif token != null and token.has_method("to_dictionary"):
		configure(token.call("to_dictionary"))


func configure(token: Dictionary) -> void:
	id = str(token.get("id", id))
	name = str(token.get("name", name))
	action_type = str(token.get("action_type", action_type))
	strength = max(0, int(token.get("strength", strength)))
	target_scope = str(token.get("target_scope", target_scope))
	defendable = bool(token.get("defendable", defendable))
	interruptible = bool(token.get("interruptible", interruptible))
	source_id = str(token.get("source_id", source_id))

	var token_effects = token.get("effects", [])
	if typeof(token_effects) == TYPE_ARRAY:
		effects = token_effects.duplicate(true)


func cancel(reason: String = "interrupted") -> void:
	canceled = true
	cancellation_reason = reason
	strength_multiplier = 0.0


func reduce_multiplier(multiplier: float, _reason: String = "") -> void:
	strength_multiplier = max(0.0, min(strength_multiplier, strength_multiplier * multiplier))
	if strength_multiplier <= 0.0:
		canceled = true


func effective_strength() -> int:
	return _scaled_amount(strength)


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"action_type": action_type,
		"strength": strength,
		"effective_strength": effective_strength(),
		"target_scope": target_scope,
		"defendable": defendable,
		"interruptible": interruptible,
		"source_id": source_id,
		"canceled": canceled,
		"cancellation_reason": cancellation_reason,
		"strength_multiplier": strength_multiplier,
		"effects": effects.duplicate(true)
	}


func to_skill() -> Dictionary:
	var token := IntentTokenScript.new(
		{
			"id": id,
			"name": name,
			"action_type": action_type,
			"strength": strength,
			"target_scope": target_scope,
			"defendable": defendable,
			"interruptible": interruptible,
			"source_id": source_id,
			"effects": effects.duplicate(true)
		}
	)
	return {
		"id": id,
		"name": name,
		"target": target_scope,
		"intent": to_dictionary(),
		"effects": _scaled_effects(token.base_effects())
	}


func _scaled_effects(base_effects: Array) -> Array:
	var scaled := []
	for effect in base_effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var scaled_effect: Dictionary = effect.duplicate(true)
		if scaled_effect.has("amount"):
			scaled_effect["amount"] = _scaled_amount(int(scaled_effect["amount"]))
		scaled.append(scaled_effect)
	return scaled


func _scaled_amount(amount: int) -> int:
	if amount <= 0:
		return 0
	if strength_multiplier >= 1.0:
		return max(0, int(round(amount * strength_multiplier)))
	return max(0, int(floor(amount * strength_multiplier)))
