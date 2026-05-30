class_name CombatState
extends RefCounted

const CombatResultScript := preload("res://src/combat/combat_result.gd")
const EncounterDefinitionScript := preload("res://src/combat/encounter_definition.gd")
const EnemyIntentScript := preload("res://src/combat/enemy_intent.gd")

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

const TARGET_PLAYER_TEAM := "player_team"
const TARGET_ENEMY_TEAM := "enemy_team"

const PHASE_NOT_STARTED := "not_started"
const PHASE_PLAYER_TURN := "player_turn"
const PHASE_ENEMY_TURN := "enemy_turn"
const PHASE_FINISHED := "finished"

const OUTCOME_ONGOING := "ongoing"
const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

var phase := PHASE_NOT_STARTED
var outcome: String = OUTCOME_ONGOING
var turn_number := 0

var max_ap := 5
var ap_recovery := 3
var player_ap := 0

var player_max_hp := 1
var player_hp := 1
var enemy_max_hp := 1
var enemy_hp := 1

var player_block := 0
var enemy_block := 0

var leaders := {}
var leader_ids := []
var acted_leader_ids := {}

var player_statuses := []
var enemy_statuses := []
var enemy_actions := []
var enemy_action_index := 0
var encounter_definition = null
var current_enemy_intents := []
var action_log := []


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		start_battle(config)


func start_battle(config: Dictionary):
	_reset()

	max_ap = max(1, int(config.get("max_ap", max_ap)))
	ap_recovery = max(0, int(config.get("ap_recovery", ap_recovery)))
	player_ap = _clamp_int(int(config.get("initial_ap", 0)), 0, max_ap)

	player_max_hp = max(1, int(config.get("player_max_hp", config.get("shared_player_hp", 1))))
	player_hp = _clamp_int(int(config.get("player_hp", player_max_hp)), 0, player_max_hp)
	enemy_max_hp = max(1, int(config.get("enemy_max_hp", 1)))
	enemy_hp = _clamp_int(int(config.get("enemy_hp", enemy_max_hp)), 0, enemy_max_hp)

	var configured_leaders = config.get("leaders", [])
	if typeof(configured_leaders) != TYPE_ARRAY or configured_leaders.is_empty():
		return _failure("Combat requires at least one player leader.", 0)
	for leader in configured_leaders:
		if typeof(leader) != TYPE_DICTIONARY:
			return _failure("Combat leader entries must be dictionaries.", 0)
		var leader_id := str(leader.get("id", ""))
		if leader_id.is_empty():
			return _failure("Combat leader entries require an id.", 0)
		if leaders.has(leader_id):
			return _failure("Duplicate combat leader id '%s'." % leader_id, 0)
		leaders[leader_id] = leader.duplicate(true)
		leader_ids.append(leader_id)

	var configured_enemy_actions = config.get("enemy_actions", [])
	if typeof(configured_enemy_actions) == TYPE_ARRAY:
		enemy_actions = configured_enemy_actions.duplicate(true)
	encounter_definition = _build_encounter_definition(config)

	action_log.append(
		"Battle started: player team HP %s/%s, enemy team HP %s/%s, AP max %s."
		% [player_hp, player_max_hp, enemy_hp, enemy_max_hp, max_ap]
	)
	_begin_player_turn()
	_check_battle_end()

	return _success("Battle started.", 0)


func execute_command(command):
	var start_log_index := action_log.size()
	if command == null:
		return _failure("Combat command is required.", start_log_index)

	match str(command.get("type")):
		"use_skill":
			return _use_skill(command, start_log_index)
		"end_player_turn":
			return _end_player_turn(start_log_index)
		_:
			return _failure("Unknown combat command '%s'." % command.get("type"), start_log_index)


func get_action_log() -> Array:
	return action_log.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"outcome": outcome,
		"turn_number": turn_number,
		"player_ap": player_ap,
		"max_ap": max_ap,
		"ap_recovery": ap_recovery,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"player_block": player_block,
		"enemy_block": enemy_block,
		"enemy_intents": _enemy_intent_snapshot(),
		"acted_leader_ids": acted_leader_ids.keys(),
		"player_statuses": player_statuses.duplicate(true),
		"enemy_statuses": enemy_statuses.duplicate(true)
	}


func _enemy_intent_snapshot() -> Array:
	var snapshot := []
	for intent in current_enemy_intents:
		if intent != null and intent.has_method("to_dictionary"):
			snapshot.append(intent.call("to_dictionary"))
	return snapshot


func is_finished() -> bool:
	return phase == PHASE_FINISHED


func _use_skill(command, start_log_index: int):
	var actor_id := str(command.get("actor_id"))
	var target_id := str(command.get("target_id"))
	if phase != PHASE_PLAYER_TURN:
		return _failure("Player skills can only be used during the player turn.", start_log_index)
	if outcome != OUTCOME_ONGOING:
		return _failure("Battle is already finished.", start_log_index)
	if not leaders.has(actor_id):
		return _failure("Unknown leader '%s'." % actor_id, start_log_index)
	if acted_leader_ids.has(actor_id):
		return _failure("Leader '%s' has already acted this turn." % actor_id, start_log_index)

	var command_skill = command.get("skill")
	var skill: Dictionary = {}
	if typeof(command_skill) == TYPE_DICTIONARY:
		skill = command_skill
	if skill.is_empty():
		return _failure("Use-skill command requires a skill dictionary.", start_log_index)

	var cost := int(skill.get("cost", 0))
	if cost < 0:
		return _failure("Skill cost must be non-negative.", start_log_index)
	if player_ap < cost:
		return _failure(
			"Not enough AP for '%s': requires %s, has %s."
			% [_skill_name(skill), cost, player_ap],
			start_log_index
		)

	var old_ap := player_ap
	player_ap -= cost
	acted_leader_ids[actor_id] = true
	action_log.append(
		"AP: %s -> %s (-%s) for %s using %s."
		% [old_ap, player_ap, cost, _leader_name(actor_id), _skill_name(skill)]
	)
	action_log.append("%s uses %s." % [_leader_name(actor_id), _skill_name(skill)])
	_resolve_skill_effects(skill, TEAM_PLAYER, target_id)
	_check_battle_end()

	if outcome == OUTCOME_VICTORY:
		return _success("Player team won.", start_log_index)
	if outcome == OUTCOME_DEFEAT:
		return _success("Player team was defeated.", start_log_index)
	return _success("Skill resolved.", start_log_index)


func _end_player_turn(start_log_index: int):
	if phase != PHASE_PLAYER_TURN:
		return _failure("Player turn can only end during the player turn.", start_log_index)
	if outcome != OUTCOME_ONGOING:
		return _failure("Battle is already finished.", start_log_index)

	action_log.append("Player ends turn %s with %s AP retained." % [turn_number, player_ap])
	_begin_enemy_turn()
	_run_enemy_turn()
	_check_battle_end()
	if outcome == OUTCOME_ONGOING:
		_begin_player_turn()
		_check_battle_end()

	if outcome == OUTCOME_VICTORY:
		return _success("Player team won.", start_log_index)
	if outcome == OUTCOME_DEFEAT:
		return _success("Player team was defeated.", start_log_index)
	return _success("Turn advanced.", start_log_index)


func _begin_player_turn() -> void:
	phase = PHASE_PLAYER_TURN
	turn_number += 1
	acted_leader_ids.clear()
	if player_block > 0:
		action_log.append("Defense: player team block %s -> 0 at turn start." % player_block)
	player_block = 0

	var old_ap := player_ap
	player_ap = _clamp_int(player_ap + ap_recovery, 0, max_ap)
	action_log.append(
		"Turn %s player phase begins. AP: %s -> %s (+%s, max %s)."
		% [turn_number, old_ap, player_ap, ap_recovery, max_ap]
	)
	_prepare_enemy_intents()


func _begin_enemy_turn() -> void:
	phase = PHASE_ENEMY_TURN
	if enemy_block > 0:
		action_log.append("Defense: enemy team block %s -> 0 at enemy turn start." % enemy_block)
	enemy_block = 0
	action_log.append("Turn %s enemy phase begins." % turn_number)


func _run_enemy_turn() -> void:
	if current_enemy_intents.is_empty():
		action_log.append("Enemy team has no previewed intent.")
		return

	for intent in current_enemy_intents:
		if outcome != OUTCOME_ONGOING:
			return
		if intent.get("canceled"):
			action_log.append(
				"Enemy intent %s was canceled, no action resolves."
				% _intent_name(intent)
			)
			continue

		var action: Dictionary = intent.call("to_skill")
		action_log.append(
			"Enemy team resolves intent %s (%s, strength %s)."
			% [_skill_name(action), intent.get("action_type"), intent.call("effective_strength")]
		)
		_resolve_skill_effects(action, TEAM_ENEMY, TARGET_PLAYER_TEAM)


func _build_encounter_definition(config: Dictionary):
	var encounter_config = config.get("encounter_definition", config.get("encounter", {}))
	if typeof(encounter_config) == TYPE_DICTIONARY and not encounter_config.is_empty():
		return EncounterDefinitionScript.new(encounter_config)

	var pattern_config = config.get("intent_pattern", {})
	if typeof(pattern_config) == TYPE_DICTIONARY and not pattern_config.is_empty():
		return EncounterDefinitionScript.new(
			{
				"id": "encounter.inline",
				"name": "Inline Encounter",
				"intent_pattern": pattern_config
			}
		)

	if not enemy_actions.is_empty():
		return EncounterDefinitionScript.from_enemy_actions(enemy_actions)
	return EncounterDefinitionScript.default_encounter()


func _prepare_enemy_intents() -> void:
	current_enemy_intents.clear()
	if encounter_definition == null:
		encounter_definition = EncounterDefinitionScript.default_encounter()

	var tokens: Array = encounter_definition.call("intents_for_turn", turn_number, _intent_context())
	for token in tokens:
		current_enemy_intents.append(EnemyIntentScript.new(token))

	if current_enemy_intents.is_empty():
		action_log.append("Enemy intent preview: none.")
		return

	for intent in current_enemy_intents:
		action_log.append(
			"Enemy intent preview: %s (%s, strength %s, target %s, defendable %s, interruptible %s)."
			% [
				_intent_name(intent),
				intent.get("action_type"),
				intent.get("strength"),
				intent.get("target_scope"),
				_bool_label(bool(intent.get("defendable"))),
				_bool_label(bool(intent.get("interruptible")))
			]
		)


func _intent_context() -> Dictionary:
	return {
		"turn_number": turn_number,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp
	}


func _next_enemy_action() -> Dictionary:
	if enemy_actions.is_empty():
		return {
			"id": "enemy.basic_attack",
			"name": "Basic Attack",
			"target": TARGET_PLAYER_TEAM,
			"effects": [{"type": "damage", "amount": 1}]
		}

	var action = enemy_actions[enemy_action_index % enemy_actions.size()]
	enemy_action_index += 1
	if typeof(action) != TYPE_DICTIONARY:
		return {}
	return action.duplicate(true)


func _resolve_skill_effects(skill: Dictionary, source_team: String, command_target_id: String) -> void:
	var effects = skill.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		action_log.append("%s has no resolvable effects." % _skill_name(skill))
		return

	for effect in effects:
		if outcome != OUTCOME_ONGOING:
			return
		if typeof(effect) != TYPE_DICTIONARY:
			action_log.append("Effect skipped: expected a dictionary.")
			continue
		_resolve_effect(effect, skill, source_team, command_target_id)


func _resolve_effect(effect: Dictionary, skill: Dictionary, source_team: String, command_target_id: String) -> void:
	var effect_type := str(effect.get("type", ""))
	var amount: int = max(0, int(effect.get("amount", 0)))
	var target_team := _target_team_for_effect(effect, skill, source_team, command_target_id, effect_type)

	match effect_type:
		"damage":
			_apply_damage(target_team, amount)
		"heal":
			_apply_heal(target_team, amount)
		"block", "defense", "damage_reduction":
			_apply_block(target_team, amount)
			if source_team == TEAM_PLAYER:
				_apply_defense_to_pending_intent(effect)
		"apply_status", "status":
			_apply_status(target_team, effect)
		"interrupt":
			_apply_interrupt(source_team, effect)
		"gain_ap", "gain_energy":
			_gain_ap(source_team, amount)
		"draw":
			action_log.append("Draw placeholder: %s would draw %s." % [_team_label(source_team), amount])
		_:
			action_log.append("Effect placeholder: unsupported effect '%s'." % effect_type)


func _apply_damage(target_team: String, amount: int) -> void:
	if amount <= 0:
		action_log.append("Damage: %s takes 0." % _team_label(target_team))
		return

	if target_team == TEAM_PLAYER:
		var old_hp := player_hp
		var old_block := player_block
		var blocked: int = min(player_block, amount)
		player_block -= blocked
		player_hp = max(0, player_hp - max(0, amount - blocked))
		action_log.append(
			"Damage: player team takes %s (%s blocked, block %s -> %s), HP %s -> %s."
			% [amount - blocked, blocked, old_block, player_block, old_hp, player_hp]
		)
	else:
		var old_enemy_hp := enemy_hp
		var old_enemy_block := enemy_block
		var enemy_blocked: int = min(enemy_block, amount)
		enemy_block -= enemy_blocked
		enemy_hp = max(0, enemy_hp - max(0, amount - enemy_blocked))
		action_log.append(
			"Damage: enemy team takes %s (%s blocked, block %s -> %s), HP %s -> %s."
			% [amount - enemy_blocked, enemy_blocked, old_enemy_block, enemy_block, old_enemy_hp, enemy_hp]
		)
	_check_battle_end()


func _apply_heal(target_team: String, amount: int) -> void:
	if target_team == TEAM_PLAYER:
		var old_hp := player_hp
		player_hp = min(player_max_hp, player_hp + amount)
		action_log.append("Heal: player team HP %s -> %s (+%s)." % [old_hp, player_hp, player_hp - old_hp])
	else:
		var old_enemy_hp := enemy_hp
		enemy_hp = min(enemy_max_hp, enemy_hp + amount)
		action_log.append("Heal: enemy team HP %s -> %s (+%s)." % [old_enemy_hp, enemy_hp, enemy_hp - old_enemy_hp])


func _apply_block(target_team: String, amount: int) -> void:
	if target_team == TEAM_PLAYER:
		var old_block := player_block
		player_block += amount
		action_log.append("Defense: player team block %s -> %s (+%s)." % [old_block, player_block, amount])
	else:
		var old_enemy_block := enemy_block
		enemy_block += amount
		action_log.append("Defense: enemy team block %s -> %s (+%s)." % [old_enemy_block, enemy_block, amount])


func _apply_interrupt(source_team: String, effect: Dictionary) -> void:
	if source_team != TEAM_PLAYER:
		action_log.append("Interrupt: enemy interrupt effects are ignored by this player intent model.")
		return

	var intent = _first_pending_intent("interruptible")
	if intent == null:
		action_log.append("Interrupt: no interruptible enemy intent is pending.")
		return

	if effect.has("reduce_multiplier") or effect.has("multiplier"):
		var old_multiplier := float(intent.get("strength_multiplier"))
		var multiplier := float(effect.get("reduce_multiplier", effect.get("multiplier", 1.0)))
		intent.call("reduce_multiplier", multiplier, "interrupt")
		action_log.append(
			"Intent: %s strength multiplier %.2f -> %.2f after interrupt."
			% [_intent_name(intent), old_multiplier, float(intent.get("strength_multiplier"))]
		)
		if intent.get("canceled"):
			action_log.append("Intent: %s was canceled by interrupt." % _intent_name(intent))
		return

	intent.call("cancel", "interrupt")
	action_log.append("Intent: %s was canceled by interrupt." % _intent_name(intent))


func _apply_defense_to_pending_intent(effect: Dictionary) -> void:
	if not effect.has("intent_multiplier") and not effect.has("intent_reduce_multiplier"):
		return

	var intent = _first_pending_intent("defendable")
	if intent == null:
		action_log.append("Intent: no defendable enemy intent is pending.")
		return

	var old_multiplier := float(intent.get("strength_multiplier"))
	var multiplier := float(effect.get("intent_multiplier", effect.get("intent_reduce_multiplier", 1.0)))
	intent.call("reduce_multiplier", multiplier, "defense")
	action_log.append(
		"Intent: %s strength multiplier %.2f -> %.2f after defense."
		% [_intent_name(intent), old_multiplier, float(intent.get("strength_multiplier"))]
	)


func _apply_status(target_team: String, effect: Dictionary) -> void:
	var status_id := str(effect.get("status_id", "status.placeholder"))
	var amount: int = max(1, int(effect.get("amount", 1)))
	var duration: int = max(1, int(effect.get("duration", 1)))
	var entry := {
		"id": status_id,
		"amount": amount,
		"duration": duration
	}
	if target_team == TEAM_PLAYER:
		player_statuses.append(entry)
	else:
		enemy_statuses.append(entry)
	action_log.append(
		"Status placeholder: %s gains %s x%s for %s turn(s)."
		% [_team_label(target_team), status_id, amount, duration]
	)


func _gain_ap(source_team: String, amount: int) -> void:
	if source_team != TEAM_PLAYER:
		action_log.append("AP placeholder: enemy AP gain ignored by the player AP model.")
		return
	var old_ap := player_ap
	player_ap = _clamp_int(player_ap + amount, 0, max_ap)
	action_log.append("AP: %s -> %s (+%s, max %s)." % [old_ap, player_ap, amount, max_ap])


func _target_team_for_effect(
	effect: Dictionary,
	skill: Dictionary,
	source_team: String,
	command_target_id: String,
	effect_type: String
) -> String:
	if effect.has("target"):
		return _team_from_target_label(str(effect["target"]), source_team)

	match effect_type:
		"heal", "block", "defense", "damage_reduction", "gain_ap", "gain_energy":
			return source_team

	var target_label := command_target_id
	if target_label.is_empty() and skill.has("target"):
		target_label = str(skill["target"])

	return _team_from_target_label(target_label, source_team)


func _team_from_target_label(target_label: String, source_team: String) -> String:
	match target_label:
		TARGET_PLAYER_TEAM, TEAM_PLAYER:
			return TEAM_PLAYER
		TARGET_ENEMY_TEAM, TEAM_ENEMY:
			return TEAM_ENEMY
		"self", "ally", "all_allies":
			return source_team
		"enemy", "all_enemies":
			return _opposing_team(source_team)
		_:
			if leaders.has(target_label):
				return TEAM_PLAYER
			if target_label.is_empty():
				return _opposing_team(source_team)
			return _opposing_team(source_team)


func _opposing_team(team: String) -> String:
	if team == TEAM_PLAYER:
		return TEAM_ENEMY
	return TEAM_PLAYER


func _check_battle_end() -> void:
	if outcome != OUTCOME_ONGOING:
		return
	if enemy_hp <= 0:
		enemy_hp = 0
		outcome = OUTCOME_VICTORY
		phase = PHASE_FINISHED
		action_log.append("Battle finished: victory.")
	elif player_hp <= 0:
		player_hp = 0
		outcome = OUTCOME_DEFEAT
		phase = PHASE_FINISHED
		action_log.append("Battle finished: defeat.")


func _success(message: String, start_log_index: int):
	return CombatResultScript.new(true, message, action_log.slice(start_log_index), get_snapshot(), outcome)


func _failure(message: String, start_log_index: int):
	return CombatResultScript.new(false, message, action_log.slice(start_log_index), get_snapshot(), outcome)


func _leader_name(leader_id: String) -> String:
	var leader = leaders.get(leader_id, {})
	if typeof(leader) == TYPE_DICTIONARY:
		return str(leader.get("name", leader_id))
	return leader_id


func _skill_name(skill: Dictionary) -> String:
	return str(skill.get("name", skill.get("id", "Unnamed Skill")))


func _team_label(team: String) -> String:
	if team == TEAM_PLAYER:
		return "player team"
	return "enemy team"


func _first_pending_intent(flag: String):
	for intent in current_enemy_intents:
		if intent == null:
			continue
		if bool(intent.get("canceled")):
			continue
		if bool(intent.get(flag)):
			return intent
	return null


func _intent_name(intent) -> String:
	if intent == null:
		return "unknown intent"
	var intent_name := str(intent.get("name"))
	if not intent_name.is_empty():
		return intent_name
	return str(intent.get("id"))


func _bool_label(value: bool) -> String:
	if value:
		return "yes"
	return "no"


func _clamp_int(value: int, minimum: int, maximum: int) -> int:
	return min(max(value, minimum), maximum)


func _reset() -> void:
	phase = PHASE_NOT_STARTED
	outcome = OUTCOME_ONGOING
	turn_number = 0
	max_ap = 5
	ap_recovery = 3
	player_ap = 0
	player_max_hp = 1
	player_hp = 1
	enemy_max_hp = 1
	enemy_hp = 1
	player_block = 0
	enemy_block = 0
	leaders.clear()
	leader_ids.clear()
	acted_leader_ids.clear()
	player_statuses.clear()
	enemy_statuses.clear()
	enemy_actions.clear()
	enemy_action_index = 0
	encounter_definition = null
	current_enemy_intents.clear()
	action_log.clear()
