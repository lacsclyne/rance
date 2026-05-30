class_name IntentToken
extends RefCounted

const SCRIPT_PATH := "res://src/combat/intent_token.gd"

const ACTION_ATTACK := "attack"
const ACTION_BIG_ATTACK := "big_attack"
const ACTION_CHARGE := "charge"
const ACTION_BUFF := "buff"
const ACTION_DEBUFF := "debuff"
const ACTION_HEAL := "heal"
const ACTION_DEFENSE := "defense"
const ACTION_CUSTOM := "custom"

const TARGET_PLAYER_TEAM := "player_team"
const TARGET_ENEMY_TEAM := "enemy_team"

var id := ""
var name := ""
var action_type := ACTION_ATTACK
var strength := 0
var target_scope := TARGET_PLAYER_TEAM
var defendable := true
var interruptible := true
var source_id := ""
var effects := []


func _init(definition: Dictionary = {}) -> void:
	if not definition.is_empty():
		configure(definition)


func configure(definition: Dictionary) -> void:
	id = str(definition.get("id", id))
	name = str(definition.get("name", definition.get("title", id)))
	action_type = str(definition.get("action_type", definition.get("type", action_type)))
	strength = max(0, int(definition.get("strength", _infer_strength(definition))))
	target_scope = str(definition.get("target_scope", definition.get("target", target_scope)))
	defendable = bool(definition.get("defendable", true))
	interruptible = bool(definition.get("interruptible", true))
	source_id = str(definition.get("source_id", definition.get("enemy_id", source_id)))

	var definition_effects = definition.get("effects", [])
	if typeof(definition_effects) == TYPE_ARRAY:
		effects = definition_effects.duplicate(true)

	if name.is_empty():
		name = id
	if id.is_empty():
		id = action_type


static func from_action(action: Dictionary):
	var definition := {}
	var declared_intent = action.get("intent", {})
	if typeof(declared_intent) == TYPE_DICTIONARY:
		definition = declared_intent.duplicate(true)

	_copy_missing(definition, action, "id")
	_copy_missing(definition, action, "name")
	_copy_missing(definition, action, "target")
	_copy_missing(definition, action, "effects")
	_copy_missing(definition, action, "action_type")
	_copy_missing(definition, action, "strength")
	_copy_missing(definition, action, "defendable")
	_copy_missing(definition, action, "interruptible")

	if not definition.has("action_type"):
		definition["action_type"] = _infer_action_type(definition)
	if not definition.has("strength"):
		definition["strength"] = _infer_strength(definition)

	return load(SCRIPT_PATH).new(definition)


func to_dictionary() -> Dictionary:
	return {
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


func base_effects() -> Array:
	if not effects.is_empty():
		return effects.duplicate(true)

	match action_type:
		ACTION_ATTACK, ACTION_BIG_ATTACK:
			return [{"type": "damage", "amount": strength, "target": target_scope}]
		ACTION_CHARGE:
			return [
				{
					"type": "apply_status",
					"status_id": "status.intent_charge",
					"amount": max(1, strength),
					"duration": 1,
					"target": TARGET_ENEMY_TEAM
				}
			]
		ACTION_BUFF, ACTION_DEFENSE:
			return [{"type": "block", "amount": strength, "target": TARGET_ENEMY_TEAM}]
		ACTION_HEAL:
			return [{"type": "heal", "amount": strength, "target": TARGET_ENEMY_TEAM}]
		ACTION_DEBUFF:
			return [
				{
					"type": "apply_status",
					"status_id": "status.intent_debuff",
					"amount": max(1, strength),
					"duration": 1,
					"target": TARGET_PLAYER_TEAM
				}
			]
		_:
			return []


static func _copy_missing(target: Dictionary, source: Dictionary, field: String) -> void:
	if not target.has(field) and source.has(field):
		target[field] = source[field]


static func _infer_action_type(definition: Dictionary) -> String:
	var effects_value = definition.get("effects", [])
	if typeof(effects_value) != TYPE_ARRAY:
		return ACTION_CUSTOM

	for effect in effects_value:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		match str(effect.get("type", "")):
			"damage":
				return ACTION_ATTACK
			"block", "defense", "damage_reduction":
				return ACTION_DEFENSE
			"heal":
				return ACTION_HEAL
			"apply_status", "status":
				return ACTION_BUFF

	return ACTION_CUSTOM


static func _infer_strength(definition: Dictionary) -> int:
	var effects_value = definition.get("effects", [])
	if typeof(effects_value) != TYPE_ARRAY:
		return 0

	var strongest := 0
	for effect in effects_value:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		if ["damage", "block", "defense", "damage_reduction", "heal", "apply_status", "status"].has(effect_type):
			strongest = max(strongest, int(effect.get("amount", 0)))
	return strongest
