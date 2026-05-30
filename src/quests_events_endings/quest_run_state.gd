class_name QuestRunState
extends RefCounted

const CombatCommandScript := preload("res://src/combat/combat_command.gd")
const CombatResultScript := preload("res://src/combat/combat_result.gd")
const CombatStateScript := preload("res://src/combat/combat_state.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestNodeScript := preload("res://src/quests_events_endings/quest_node.gd")
const RewardPoolDefinitionScript := preload("res://src/quests_events_endings/reward_pool_definition.gd")

const OUTCOME_RUNNING := "running"
const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

var quest_definition = null
var content_indexes := {}
var current_node_id := ""
var finished := false
var outcome := OUTCOME_RUNNING

var player_max_hp := 24
var player_hp := 24
var reward_seed := 1
var battle_turn_limit := 8
var default_leaders := [{"id": "leader.quest_vanguard", "name": "Quest Vanguard"}]
var default_player_skill := {
	"id": "skill.quest_strike",
	"name": "Quest Strike",
	"cost": 1,
	"target": "enemy",
	"effects": [{"type": "damage", "amount": 6}]
}

var completed_node_ids := []
var event_log := []
var branch_choices := []
var rest_results := []
var combat_results := []
var chest_candidates_by_node := {}
var chest_choices := []

var earned_exp := 0
var earned_card_ids := []
var earned_skill_ids := []
var earned_medal_ids := []
var warzone_impact := {}
var settlement_summary := {}


func _init(new_quest_definition = null, validated_content: Dictionary = {}, config: Dictionary = {}) -> void:
	if new_quest_definition != null:
		start(new_quest_definition, validated_content, config)


func start(new_quest_definition, validated_content: Dictionary = {}, config: Dictionary = {}) -> Dictionary:
	quest_definition = new_quest_definition
	content_indexes = _extract_indexes(validated_content)
	_apply_config(config)
	_reset_run_tracking()

	if quest_definition == null or not quest_definition.call("is_valid"):
		return _error("quest definition is invalid")

	current_node_id = quest_definition.get("start_node_id")
	return _ok("Quest started.")


func get_current_node():
	if quest_definition == null:
		return null
	return quest_definition.call("get_node", current_node_id)


func is_finished() -> bool:
	return finished


func advance(choice: Dictionary = {}) -> Dictionary:
	if finished:
		return _error("quest run is already finished")

	var node = get_current_node()
	if node == null:
		return _error("current quest node '%s' does not exist" % current_node_id)

	match str(node.get("type")):
		QuestNodeScript.TYPE_EVENT:
			return _advance_event(node)
		QuestNodeScript.TYPE_BRANCH:
			return _advance_branch(node, choice)
		QuestNodeScript.TYPE_REST:
			return _advance_rest(node)
		QuestNodeScript.TYPE_CHEST:
			return _advance_chest(node, choice)
		QuestNodeScript.TYPE_RESULT:
			return _advance_result(node)
		QuestNodeScript.TYPE_BATTLE, QuestNodeScript.TYPE_ELITE, QuestNodeScript.TYPE_BOSS:
			return _advance_combat(node)
		_:
			return _error("unsupported quest node type '%s'" % node.get("type"))


func choose_chest_reward(candidate_index: int = 0) -> Dictionary:
	return advance({"reward_index": candidate_index})


func simulate_to_result(options: Dictionary = {}) -> Dictionary:
	var guard := 0
	while not finished and guard < int(options.get("max_steps", 64)):
		guard += 1
		var node = get_current_node()
		if node == null:
			return _error("cannot simulate missing node '%s'" % current_node_id)

		var node_type := str(node.get("type"))
		var result := {}
		if node_type == QuestNodeScript.TYPE_BRANCH:
			result = advance({"choice_id": str(options.get("branch_choice_id", ""))})
		elif node_type == QuestNodeScript.TYPE_CHEST:
			result = advance()
			if not bool(result.get("ok", false)):
				return result
			if bool(result.get("awaiting_choice", false)):
				result = choose_chest_reward(int(options.get("reward_index", 0)))
		else:
			result = advance()

		if not bool(result.get("ok", false)):
			return result

	if not finished:
		return _error("quest simulation exceeded step limit")
	return _ok("Quest simulation finished.", {"summary": get_settlement_summary()})


func get_settlement_summary() -> Dictionary:
	if settlement_summary.is_empty():
		return _build_settlement_summary()
	return settlement_summary.duplicate(true)


func _advance_event(node) -> Dictionary:
	event_log.append({"node_id": node.get("id"), "type": node.get("type")})
	completed_node_ids.append(node.get("id"))
	return _move_to_next(node.get("next_node_id"), "Event resolved.")


func _advance_branch(node, choice: Dictionary) -> Dictionary:
	var choice_id := str(choice.get("choice_id", ""))
	var next_id: String = node.call("branch_next_node_id", choice_id)
	if next_id.is_empty():
		return _error("branch node '%s' has no matching route for '%s'" % [node.get("id"), choice_id])

	var selected_id := choice_id
	if selected_id.is_empty():
		var options: Array = node.get("branch_options")
		if not options.is_empty() and typeof(options[0]) == TYPE_DICTIONARY:
			selected_id = str(options[0].get("id", ""))

	branch_choices.append(
		{
			"node_id": node.get("id"),
			"choice_id": selected_id,
			"next_node_id": next_id
		}
	)
	completed_node_ids.append(node.get("id"))
	return _move_to_next(next_id, "Branch selected.")


func _advance_rest(node) -> Dictionary:
	var before_hp := player_hp
	var heal_amount := int(node.get("payload").get("heal_amount", node.get("payload").get("hp", 0)))
	if heal_amount <= 0:
		heal_amount = int(ceil(float(player_max_hp) * float(node.get("payload").get("heal_percent", 25)) / 100.0))
	player_hp = min(player_max_hp, player_hp + max(0, heal_amount))
	var rest_result := {
		"node_id": node.get("id"),
		"player_hp_before": before_hp,
		"player_hp_after": player_hp,
		"healed": player_hp - before_hp
	}
	rest_results.append(rest_result)
	completed_node_ids.append(node.get("id"))
	return _move_to_next(node.get("next_node_id"), "Rest resolved.", {"rest": rest_result})


func _advance_chest(node, choice: Dictionary) -> Dictionary:
	var candidates: Array = chest_candidates_by_node.get(node.get("id"), [])
	if candidates.is_empty():
		var pool = _reward_pool_for_node(node)
		if pool == null or not pool.call("is_valid"):
			return _error("chest node '%s' has no valid reward pool" % node.get("id"))
		candidates = pool.call("generate_candidates", 3, _seed_for_node(node.get("id")))
		chest_candidates_by_node[node.get("id")] = candidates

	if not choice.has("reward_index") and not choice.has("candidate_id") and not choice.has("content_id"):
		return _ok(
			"Chest reward candidates generated.",
			{
				"awaiting_choice": true,
				"node_id": node.get("id"),
				"candidates": candidates.duplicate(true)
			}
		)

	var selected := _select_reward_candidate(candidates, choice)
	if selected.is_empty():
		return _error("selected chest reward is not one of the generated candidates")

	_record_reward_choice(node, candidates, selected)
	completed_node_ids.append(node.get("id"))
	return _move_to_next(
		node.get("next_node_id"),
		"Chest reward selected.",
		{"selected_reward": selected.duplicate(true)}
	)


func _advance_result(node) -> Dictionary:
	completed_node_ids.append(node.get("id"))
	finished = true
	if outcome == OUTCOME_RUNNING:
		outcome = OUTCOME_VICTORY
	settlement_summary = _build_settlement_summary()
	return _ok("Quest result resolved.", {"summary": settlement_summary.duplicate(true)})


func _advance_combat(node) -> Dictionary:
	var combat_result = _run_combat_node(node)
	if combat_result == null:
		return _error("combat node '%s' did not produce a combat result" % node.get("id"))

	var result_dictionary: Dictionary = combat_result.call("to_dictionary")
	if not bool(result_dictionary.get("ok", false)):
		return _error("combat failed at node '%s': %s" % [node.get("id"), result_dictionary.get("message", "")])

	var snapshot: Dictionary = result_dictionary.get("snapshot", {})
	player_hp = int(snapshot.get("player_hp", player_hp))
	var result_outcome := str(result_dictionary.get("outcome", CombatResultScript.OUTCOME_ONGOING))
	if result_outcome == CombatResultScript.OUTCOME_DEFEAT:
		outcome = OUTCOME_DEFEAT

	_record_combat_result(node, result_dictionary)
	_apply_combat_rewards(node, result_outcome)
	completed_node_ids.append(node.get("id"))

	if outcome == OUTCOME_DEFEAT:
		current_node_id = _next_result_node_id()
		return _ok("Combat resolved with defeat.", {"combat_result": combat_result})

	return _move_to_next(node.get("next_node_id"), "Combat resolved.", {"combat_result": combat_result})


func _run_combat_node(node):
	var encounter: Dictionary = _encounter_for_node(node)
	var node_payload: Dictionary = node.get("payload")
	var combat_config: Dictionary = {}
	var configured_combat = node_payload.get("combat_config", {})
	if typeof(configured_combat) == TYPE_DICTIONARY:
		combat_config = configured_combat.duplicate(true)

	var enemy_hp_value := int(combat_config.get("enemy_hp", _enemy_hp_for_node(node, encounter)))
	var enemy_max_hp_value := int(combat_config.get("enemy_max_hp", enemy_hp_value))
	var config := {
		"max_ap": int(combat_config.get("max_ap", 3)),
		"ap_recovery": int(combat_config.get("ap_recovery", 3)),
		"initial_ap": int(combat_config.get("initial_ap", 0)),
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"enemy_max_hp": max(1, enemy_max_hp_value),
		"enemy_hp": max(1, enemy_hp_value),
		"leaders": combat_config.get("leaders", default_leaders),
		"encounter_definition": encounter
	}

	var state: Object = CombatStateScript.new()
	var combat_result: Object = state.call("start_battle", config)
	if not combat_result.get("ok"):
		return combat_result

	var player_skill: Dictionary = combat_config.get("player_skill", default_player_skill).duplicate(true)
	var leader_id := str(config["leaders"][0].get("id", "leader.quest_vanguard"))
	var turns := 0
	while not state.call("is_finished") and turns < battle_turn_limit:
		if state.get("phase") == CombatStateScript.PHASE_PLAYER_TURN:
			combat_result = state.call(
				"execute_command",
				CombatCommandScript.use_skill(leader_id, player_skill, "enemy_team")
			)
			if not combat_result.get("ok") or state.call("is_finished"):
				break
			combat_result = state.call("execute_command", CombatCommandScript.end_player_turn())
			turns += 1
		else:
			combat_result = state.call("execute_command", CombatCommandScript.end_player_turn())
			turns += 1

	if not state.call("is_finished") and combat_result.get("ok"):
		return CombatResultScript.failure(
			"combat node '%s' exceeded turn limit" % node.get("id"),
			state.call("get_action_log"),
			state.call("get_snapshot"),
			state.get("outcome")
		)
	return combat_result


func _record_combat_result(node, combat_result: Dictionary) -> void:
	var snapshot: Dictionary = combat_result.get("snapshot", {})
	combat_results.append(
		{
			"node_id": node.get("id"),
			"node_type": node.get("type"),
			"encounter_id": node.get("encounter_id"),
			"outcome": combat_result.get("outcome", ""),
			"message": combat_result.get("message", ""),
			"logs": combat_result.get("logs", []),
			"player_hp_after": int(snapshot.get("player_hp", player_hp)),
			"enemy_hp_after": int(snapshot.get("enemy_hp", 0)),
			"snapshot": snapshot
		}
	)


func _apply_combat_rewards(node, result_outcome: String) -> void:
	if result_outcome != CombatResultScript.OUTCOME_VICTORY:
		return

	var rewards: Dictionary = node.get("rewards")
	var encounter: Dictionary = _encounter_for_node(node)
	var tier: int = max(1, int(encounter.get("tier", 1)))
	earned_exp += int(rewards.get("exp", _default_exp_for_node(node, tier)))

	for card_id in _array_from_reward(rewards, "card_ids"):
		_add_unique(earned_card_ids, str(card_id))
	for skill_id in _array_from_reward(rewards, "skill_ids"):
		_add_unique(earned_skill_ids, str(skill_id))
	for medal_id in _array_from_reward(rewards, "medal_ids"):
		_add_unique(earned_medal_ids, str(medal_id))

	var impact: Dictionary = rewards.get("warzone_impact", {})
	if impact.is_empty():
		impact = {"warzone.sample": 1}
	_merge_warzone_impact(impact)


func _record_reward_choice(node, candidates: Array, selected: Dictionary) -> void:
	var choice := {
		"node_id": node.get("id"),
		"reward_pool_id": selected.get("reward_pool_id", node.get("reward_pool_id")),
		"candidates": candidates.duplicate(true),
		"selected": selected.duplicate(true)
	}
	chest_choices.append(choice)

	match str(selected.get("kind", "")):
		"card":
			_add_unique(earned_card_ids, str(selected.get("content_id", "")))
		"skill":
			_add_unique(earned_skill_ids, str(selected.get("content_id", "")))


func _build_settlement_summary() -> Dictionary:
	var progression_reward_ids := []
	if quest_definition != null and not str(quest_definition.get("progression_reward_id")).is_empty():
		progression_reward_ids.append(str(quest_definition.get("progression_reward_id")))

	return {
		"quest_id": "" if quest_definition == null else quest_definition.get("id"),
		"quest_name": "" if quest_definition == null else quest_definition.get("name"),
		"outcome": outcome,
		"completed_node_ids": completed_node_ids.duplicate(true),
		"exp": earned_exp,
		"card_ids": earned_card_ids.duplicate(true),
		"skill_ids": earned_skill_ids.duplicate(true),
		"medal_ids": earned_medal_ids.duplicate(true),
		"warzone_impact": warzone_impact.duplicate(true),
		"progression_reward_ids": progression_reward_ids,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"combat_results": combat_results.duplicate(true),
		"chest_choices": chest_choices.duplicate(true),
		"branch_choices": branch_choices.duplicate(true),
		"rest_results": rest_results.duplicate(true)
	}


func _reward_pool_for_node(node):
	var pool_id := str(node.get("reward_pool_id"))
	if pool_id.is_empty() and quest_definition != null:
		pool_id = str(quest_definition.get("reward_pool_id"))
	var pools: Dictionary = content_indexes.get("reward_pools", {})
	if not pools.has(pool_id):
		return null
	return RewardPoolDefinitionScript.new(pools[pool_id])


func _encounter_for_node(node) -> Dictionary:
	var encounter_id := str(node.get("encounter_id"))
	var encounters: Dictionary = content_indexes.get("encounters", {})
	if encounters.has(encounter_id):
		return encounters[encounter_id]
	return {
		"id": "encounter.quest_inline",
		"name": "Quest Inline Encounter",
		"tier": 1,
		"intent_pattern": {
			"rotation": [
				{
					"id": "intent.quest_pressure",
					"name": "Quest Pressure",
					"action_type": "attack",
					"strength": 4,
					"target_scope": "player_team",
					"defendable": true,
					"interruptible": true
				}
			]
		}
	}


func _enemy_hp_for_node(node, encounter: Dictionary) -> int:
	var tier: int = max(1, int(encounter.get("tier", 1)))
	var wave_count := 0
	var waves = encounter.get("waves", [])
	if typeof(waves) == TYPE_ARRAY:
		for wave in waves:
			if typeof(wave) == TYPE_DICTIONARY:
				wave_count += max(1, int(wave.get("count", 1)))

	var base_hp: int = 8 + tier * 2 + wave_count * 2
	match str(node.get("type")):
		QuestNodeScript.TYPE_ELITE:
			return base_hp + 4
		QuestNodeScript.TYPE_BOSS:
			return base_hp + 8
		_:
			return base_hp


func _default_exp_for_node(node, tier: int) -> int:
	match str(node.get("type")):
		QuestNodeScript.TYPE_ELITE:
			return 18 * tier
		QuestNodeScript.TYPE_BOSS:
			return 30 * tier
		_:
			return 12 * tier


func _move_to_next(next_node_id: String, message: String, extra: Dictionary = {}) -> Dictionary:
	if next_node_id.is_empty():
		return _error("node has no next node")
	current_node_id = next_node_id
	return _ok(message, extra)


func _next_result_node_id() -> String:
	if quest_definition != null and quest_definition.call("get_node", "result") != null:
		return "result"
	for node_id in quest_definition.call("get_node_ids"):
		var node = quest_definition.call("get_node", node_id)
		if node != null and node.get("type") == QuestNodeScript.TYPE_RESULT:
			return node_id
	return current_node_id


func _select_reward_candidate(candidates: Array, choice: Dictionary) -> Dictionary:
	if choice.has("reward_index"):
		var index := int(choice.get("reward_index", 0))
		if index >= 0 and index < candidates.size() and typeof(candidates[index]) == TYPE_DICTIONARY:
			return candidates[index]

	for candidate in candidates:
		if typeof(candidate) != TYPE_DICTIONARY:
			continue
		if choice.has("candidate_id") and str(candidate.get("candidate_id", "")) == str(choice.get("candidate_id", "")):
			return candidate
		if choice.has("content_id") and str(candidate.get("content_id", "")) == str(choice.get("content_id", "")):
			return candidate
	return {}


func _seed_for_node(node_id: String) -> int:
	var hash_value: int = abs(node_id.hash())
	return int(reward_seed + hash_value)


func _array_from_reward(rewards: Dictionary, key: String) -> Array:
	var value = rewards.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


func _merge_warzone_impact(impact: Dictionary) -> void:
	for key in impact.keys():
		warzone_impact[key] = int(warzone_impact.get(key, 0)) + int(impact[key])


func _add_unique(target: Array, value: String) -> void:
	if value.is_empty():
		return
	if not target.has(value):
		target.append(value)


func _extract_indexes(validated_content: Dictionary) -> Dictionary:
	if validated_content.has("indexes"):
		return validated_content.get("indexes", {}).duplicate(true)
	return validated_content.duplicate(true)


func _apply_config(config: Dictionary) -> void:
	player_max_hp = max(1, int(config.get("player_max_hp", player_max_hp)))
	player_hp = clamp(int(config.get("player_hp", player_max_hp)), 0, player_max_hp)
	reward_seed = int(config.get("reward_seed", reward_seed))
	battle_turn_limit = max(1, int(config.get("battle_turn_limit", battle_turn_limit)))

	var configured_leaders = config.get("leaders", [])
	if typeof(configured_leaders) == TYPE_ARRAY and not configured_leaders.is_empty():
		default_leaders = configured_leaders.duplicate(true)

	var configured_skill = config.get("player_skill", {})
	if typeof(configured_skill) == TYPE_DICTIONARY and not configured_skill.is_empty():
		default_player_skill = configured_skill.duplicate(true)


func _reset_run_tracking() -> void:
	finished = false
	outcome = OUTCOME_RUNNING
	current_node_id = ""
	completed_node_ids.clear()
	event_log.clear()
	branch_choices.clear()
	rest_results.clear()
	combat_results.clear()
	chest_candidates_by_node.clear()
	chest_choices.clear()
	earned_exp = 0
	earned_card_ids.clear()
	earned_skill_ids.clear()
	earned_medal_ids.clear()
	warzone_impact.clear()
	settlement_summary.clear()


func _ok(message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": true,
		"message": message,
		"errors": [],
		"current_node_id": current_node_id,
		"finished": finished
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"errors": [message],
		"current_node_id": current_node_id,
		"finished": finished
	}
