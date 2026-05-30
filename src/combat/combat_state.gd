class_name CombatState
extends RefCounted

const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const CombatResultScript := preload("res://src/combat/combat_result.gd")
const StatusDefinitionScript := preload("res://src/combat/status_definition.gd")
const StatusInstanceScript := preload("res://src/combat/status_instance.gd")
const SupportSlotScript := preload("res://src/combat/support_slot.gd")

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

const STATUS_TIMING_TURN_START := "turn_start"
const STATUS_TIMING_TURN_END := "turn_end"
const STATUS_TYPE_DAMAGE_OVER_TIME := "damage_over_time"
const STATUS_TYPE_VULNERABLE := "vulnerable"
const STATUS_TYPE_WEAKEN := "weaken"
const STATUS_TYPE_GUARD := "guard"
const STATUS_TYPE_SEAL := "seal"
const STATUS_TYPE_HEAL_BLOCK := "heal_block"

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
var player_support = null
var enemy_support = null
var status_definitions := {}
var enemy_actions := []
var enemy_action_index := 0
var action_log := []


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		start_battle(config)


func start_battle(config: Dictionary):
	_reset()
	_load_status_definitions(config)

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
		"acted_leader_ids": acted_leader_ids.keys(),
		"player_statuses": _status_snapshot(TEAM_PLAYER),
		"enemy_statuses": _status_snapshot(TEAM_ENEMY)
	}


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
	if _team_is_sealed(TEAM_PLAYER):
		return _failure(
			"Action blocked: %s is sealed by %s."
			% [_team_label(TEAM_PLAYER), _status_names_for_effect_type(TEAM_PLAYER, STATUS_TYPE_SEAL)],
			start_log_index
		)

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
	_process_status_timing(TEAM_PLAYER, STATUS_TIMING_TURN_END)
	_check_battle_end()
	if outcome != OUTCOME_ONGOING:
		if outcome == OUTCOME_VICTORY:
			return _success("Player team won.", start_log_index)
		return _success("Player team was defeated.", start_log_index)
	_begin_enemy_turn()
	if outcome == OUTCOME_ONGOING:
		_run_enemy_turn()
		_check_battle_end()
	if outcome == OUTCOME_ONGOING:
		_process_status_timing(TEAM_ENEMY, STATUS_TIMING_TURN_END)
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
	_process_status_timing(TEAM_PLAYER, STATUS_TIMING_TURN_START)
	if outcome != OUTCOME_ONGOING:
		return

	var old_ap := player_ap
	player_ap = _clamp_int(player_ap + ap_recovery, 0, max_ap)
	action_log.append(
		"Turn %s player phase begins. AP: %s -> %s (+%s, max %s)."
		% [turn_number, old_ap, player_ap, ap_recovery, max_ap]
	)


func _begin_enemy_turn() -> void:
	phase = PHASE_ENEMY_TURN
	if enemy_block > 0:
		action_log.append("Defense: enemy team block %s -> 0 at enemy turn start." % enemy_block)
	enemy_block = 0
	action_log.append("Turn %s enemy phase begins." % turn_number)
	_process_status_timing(TEAM_ENEMY, STATUS_TIMING_TURN_START)


func _run_enemy_turn() -> void:
	if _team_is_sealed(TEAM_ENEMY):
		action_log.append(
			"Action blocked: %s is sealed by %s."
			% [_team_label(TEAM_ENEMY), _status_names_for_effect_type(TEAM_ENEMY, STATUS_TYPE_SEAL)]
		)
		return

	var action := _next_enemy_action()
	if action.is_empty():
		action_log.append("Enemy team has no action.")
		return

	action_log.append("Enemy team uses %s." % _skill_name(action))
	_resolve_skill_effects(action, TEAM_ENEMY, TARGET_PLAYER_TEAM)


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
			_apply_damage(target_team, amount, source_team)
		"heal":
			_apply_heal(target_team, amount)
		"block", "defense", "damage_reduction":
			_apply_block(target_team, amount)
		"apply_status", "status":
			_apply_status(target_team, effect)
		"remove_status", "clear_status":
			_remove_status(target_team, effect)
		"interrupt":
			action_log.append(
				"Interrupt placeholder: %s attempts an interrupt effect."
				% _team_label(source_team)
			)
		"gain_ap", "gain_energy":
			_gain_ap(source_team, amount)
		"draw":
			action_log.append("Draw placeholder: %s would draw %s." % [_team_label(source_team), amount])
		_:
			action_log.append("Effect placeholder: unsupported effect '%s'." % effect_type)


func _apply_damage(target_team: String, amount: int, source_team: String = "") -> void:
	if amount <= 0:
		action_log.append("Damage: %s takes 0." % _team_label(target_team))
		return

	var modified_amount := _modified_damage_amount(source_team, target_team, amount)
	if target_team == TEAM_PLAYER:
		var old_hp := player_hp
		var old_block := player_block
		var blocked: int = min(player_block, modified_amount)
		player_block -= blocked
		var guarded: int = min(_status_value_total(TEAM_PLAYER, STATUS_TYPE_GUARD), max(0, modified_amount - blocked))
		var final_damage: int = max(0, modified_amount - blocked - guarded)
		player_hp = max(0, player_hp - final_damage)
		action_log.append(
			"Damage: player team takes %s (%s blocked, %s guarded by %s, block %s -> %s), HP %s -> %s."
			% [
				final_damage,
				blocked,
				guarded,
				_status_names_for_effect_type(TEAM_PLAYER, STATUS_TYPE_GUARD),
				old_block,
				player_block,
				old_hp,
				player_hp
			]
		)
	else:
		var old_enemy_hp := enemy_hp
		var old_enemy_block := enemy_block
		var enemy_blocked: int = min(enemy_block, modified_amount)
		enemy_block -= enemy_blocked
		var enemy_guarded: int = min(_status_value_total(TEAM_ENEMY, STATUS_TYPE_GUARD), max(0, modified_amount - enemy_blocked))
		var enemy_final_damage: int = max(0, modified_amount - enemy_blocked - enemy_guarded)
		enemy_hp = max(0, enemy_hp - enemy_final_damage)
		action_log.append(
			"Damage: enemy team takes %s (%s blocked, %s guarded by %s, block %s -> %s), HP %s -> %s."
			% [
				enemy_final_damage,
				enemy_blocked,
				enemy_guarded,
				_status_names_for_effect_type(TEAM_ENEMY, STATUS_TYPE_GUARD),
				old_enemy_block,
				enemy_block,
				old_enemy_hp,
				enemy_hp
			]
		)
	_check_battle_end()


func _apply_heal(target_team: String, amount: int) -> void:
	if _team_has_status_type(target_team, STATUS_TYPE_HEAL_BLOCK):
		action_log.append(
			"Heal blocked: %s cannot recover because of %s."
			% [_team_label(target_team), _status_names_for_effect_type(target_team, STATUS_TYPE_HEAL_BLOCK)]
		)
		return

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


func _apply_status(target_team: String, effect: Dictionary) -> void:
	var status_id := str(effect.get("status_id", ""))
	if status_id.is_empty():
		action_log.append("Status skipped: effect has no status_id.")
		return
	if not status_definitions.has(status_id):
		action_log.append("Status skipped: unknown status '%s'." % status_id)
		return

	var definition = status_definitions[status_id]
	var amount: int = max(1, int(effect.get("amount", 1)))
	var duration: int = max(0, int(effect.get("duration", definition.default_duration)))
	var existing = _find_status(target_team, status_id)

	if existing == null:
		_statuses_for_team(target_team).append(StatusInstanceScript.new(definition, amount, duration))
		action_log.append(
			"Status: %s gains %s x%s for %s turn(s)."
			% [_team_label(target_team), definition.display_name(), amount, duration]
		)
		return

	var old_stacks: int = existing.stacks
	var old_duration: int = existing.duration
	match definition.stack_rule:
		"add":
			existing.stacks += amount
			existing.duration = max(existing.duration, duration)
		"intensity":
			existing.stacks = max(existing.stacks, amount)
			existing.duration = max(existing.duration, duration)
		_:
			existing.stacks = amount
			existing.duration = duration

	action_log.append(
		"Status: %s %s updates x%s/%s turn(s) -> x%s/%s turn(s)."
		% [
			_team_label(target_team),
			definition.display_name(),
			old_stacks,
			old_duration,
			existing.stacks,
			existing.duration
		]
	)


func _remove_status(target_team: String, effect: Dictionary) -> void:
	var status_id := str(effect.get("status_id", ""))
	var polarity := str(effect.get("polarity", ""))
	var statuses := _statuses_for_team(target_team)
	var removed := 0
	for index in range(statuses.size() - 1, -1, -1):
		var status = statuses[index]
		if status == null or status.definition == null:
			continue
		if not status_id.is_empty() and status.definition.id != status_id:
			continue
		if status_id.is_empty() and not polarity.is_empty() and status.definition.polarity != polarity:
			continue
		action_log.append(
			"Status: %s loses %s."
			% [_team_label(target_team), status.display_name()]
		)
		statuses.remove_at(index)
		removed += 1
	if removed == 0:
		action_log.append("Status: %s has no matching status to remove." % _team_label(target_team))


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


func _load_status_definitions(config: Dictionary) -> void:
	status_definitions.clear()
	var configured_statuses = config.get("status_definitions", null)
	if typeof(configured_statuses) == TYPE_ARRAY:
		for row in configured_statuses:
			if typeof(row) == TYPE_DICTIONARY:
				_register_status_definition(row)
		return

	var data_root := str(config.get("data_root", ContentDataLoaderScript.DEFAULT_DATA_ROOT))
	var loader = ContentDataLoaderScript.new()
	var result: Dictionary = loader.load_and_validate(data_root)
	if not bool(result.get("ok", false)):
		action_log.append("Status definitions unavailable: content data validation failed.")
		return

	var indexes: Dictionary = result.get("indexes", {})
	var status_index: Dictionary = indexes.get("statuses", {})
	for status_id in status_index.keys():
		_register_status_definition(status_index[status_id])


func _register_status_definition(row: Dictionary) -> void:
	var definition = StatusDefinitionScript.new(row)
	if definition.is_valid():
		status_definitions[definition.id] = definition


func _process_status_timing(team: String, timing: String) -> void:
	if outcome != OUTCOME_ONGOING:
		return
	_tick_statuses(team, timing)
	if outcome != OUTCOME_ONGOING:
		return
	_expire_statuses(team, timing)


func _tick_statuses(team: String, timing: String) -> void:
	var statuses := _statuses_for_team(team).duplicate()
	for status in statuses:
		if status == null or status.definition == null:
			continue
		if status.definition.tick_timing != timing:
			continue
		match status.definition.effect_type:
			STATUS_TYPE_DAMAGE_OVER_TIME:
				var damage: int = status.stacks * status.definition.numeric_value
				action_log.append(
					"Status: %s suffers %s from %s."
					% [_team_label(team), damage, status.display_name()]
				)
				_apply_damage(team, damage)
				if outcome != OUTCOME_ONGOING:
					return


func _expire_statuses(team: String, timing: String) -> void:
	var statuses := _statuses_for_team(team)
	for index in range(statuses.size() - 1, -1, -1):
		var status = statuses[index]
		if status == null or status.definition == null:
			continue
		if status.definition.expire_timing != timing:
			continue
		if status.duration <= 0:
			continue
		status.duration -= 1
		if status.duration <= 0:
			action_log.append(
				"Status: %s %s expired."
				% [_team_label(team), status.display_name()]
			)
			statuses.remove_at(index)


func _modified_damage_amount(source_team: String, target_team: String, base_amount: int) -> int:
	var amount := base_amount
	if not source_team.is_empty():
		var weaken_percent := _status_value_total(source_team, STATUS_TYPE_WEAKEN)
		if weaken_percent > 0:
			var weakened_amount: int = max(0, amount - _percent_delta(amount, weaken_percent))
			action_log.append(
				"Status: %s reduces damage %s -> %s with %s."
				% [
					_team_label(source_team),
					amount,
					weakened_amount,
					_status_names_for_effect_type(source_team, STATUS_TYPE_WEAKEN)
				]
			)
			amount = weakened_amount

	var vulnerable_percent := _status_value_total(target_team, STATUS_TYPE_VULNERABLE)
	if vulnerable_percent > 0:
		var vulnerable_amount := amount + _percent_delta(amount, vulnerable_percent)
		action_log.append(
			"Status: %s increases incoming damage %s -> %s with %s."
			% [
				_team_label(target_team),
				amount,
				vulnerable_amount,
				_status_names_for_effect_type(target_team, STATUS_TYPE_VULNERABLE)
			]
		)
		amount = vulnerable_amount
	return amount


func _percent_delta(amount: int, percent: int) -> int:
	if amount <= 0 or percent <= 0:
		return 0
	return int(ceil(float(amount * percent) / 100.0))


func _team_is_sealed(team: String) -> bool:
	return _team_has_status_type(team, STATUS_TYPE_SEAL)


func _team_has_status_type(team: String, effect_type: String) -> bool:
	for status in _statuses_for_team(team):
		if status != null and status.definition != null and status.definition.effect_type == effect_type:
			return true
	return false


func _status_value_total(team: String, effect_type: String) -> int:
	var total := 0
	for status in _statuses_for_team(team):
		if status == null or status.definition == null:
			continue
		if status.definition.effect_type == effect_type:
			total += status.stacks * status.definition.numeric_value
	return total


func _status_names_for_effect_type(team: String, effect_type: String) -> String:
	var names := []
	for status in _statuses_for_team(team):
		if status == null or status.definition == null:
			continue
		if status.definition.effect_type == effect_type:
			names.append(status.display_name())
	if names.is_empty():
		return "no status"
	return ", ".join(names)


func _find_status(team: String, status_id: String):
	for status in _statuses_for_team(team):
		if status != null and status.definition != null and status.definition.id == status_id:
			return status
	return null


func _statuses_for_team(team: String) -> Array:
	if team == TEAM_PLAYER:
		return player_statuses
	return enemy_statuses


func _status_snapshot(team: String) -> Array:
	var rows := []
	for status in _statuses_for_team(team):
		if status != null and status.has_method("to_dictionary"):
			rows.append(status.to_dictionary())
	return rows


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
	player_support = SupportSlotScript.new(TEAM_PLAYER)
	enemy_support = SupportSlotScript.new(TEAM_ENEMY)
	player_statuses = player_support.statuses
	enemy_statuses = enemy_support.statuses
	status_definitions.clear()
	enemy_actions.clear()
	enemy_action_index = 0
	action_log.clear()
