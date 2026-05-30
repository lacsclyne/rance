extends SceneTree

const CombatCommandScript := preload("res://src/combat/combat_command.gd")
const CombatResultScript := preload("res://src/combat/combat_result.gd")
const CombatStateScript := preload("res://src/combat/combat_state.gd")

var _failures := []


func _init() -> void:
	var state: Object = CombatStateScript.new()
	var start_result: Object = state.call(
		"start_battle",
		{
			"max_ap": 3,
			"ap_recovery": 3,
			"initial_ap": 0,
			"player_max_hp": 20,
			"player_hp": 18,
			"enemy_max_hp": 15,
			"enemy_hp": 15,
			"leaders": [
				{"id": "leader.guardian", "name": "Guardian"},
				{"id": "leader.tactician", "name": "Tactician"},
				{"id": "leader.striker", "name": "Striker"}
			],
			"enemy_actions": [
				{
					"id": "enemy.pressure",
					"name": "Pressure",
					"target": "player_team",
					"effects": [{"type": "damage", "amount": 4}]
				}
			]
		}
	)
	_expect(start_result.get("ok"), "battle starts")
	_expect(state.get("player_ap") == 3, "initial AP recovery is applied and capped")

	var support_skill := {
		"id": "skill.test_support",
		"name": "Test Support",
		"cost": 0,
		"target": "self",
		"effects": [
			{"type": "heal", "amount": 3},
			{"type": "block", "amount": 1},
			{"type": "apply_status", "status_id": "status.guard", "amount": 1, "duration": 1},
			{"type": "interrupt"}
		]
	}
	var setup_skill := {
		"id": "skill.test_setup",
		"name": "Test Setup",
		"cost": 1,
		"target": "enemy",
		"effects": [
			{"type": "apply_status", "status_id": "status.vulnerable", "amount": 1, "duration": 2},
			{"type": "apply_status", "status_id": "status.weaken", "amount": 1, "duration": 1},
			{"type": "apply_status", "status_id": "status.bleed", "amount": 1, "duration": 1}
		]
	}
	var strike_skill := {
		"id": "skill.test_strike",
		"name": "Test Strike",
		"cost": 1,
		"target": "enemy",
		"effects": [{"type": "damage", "amount": 5}]
	}

	var support_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.guardian", support_skill, "player_team")
	)
	_expect(support_result.get("ok"), "support skill resolves")
	_expect(state.get("player_hp") == 20, "healing uses shared player HP and respects max HP")
	_expect(state.get("player_block") == 1, "defense block is applied")
	_expect(state.get("player_statuses").size() == 1, "status instance records applied statuses")
	_expect(_has_status_id(state.call("get_snapshot").get("player_statuses", []), "status.guard"), "guard status is visible in the snapshot")

	var setup_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.tactician", setup_skill, "enemy_team")
	)
	_expect(setup_result.get("ok"), "setup statuses resolve")
	_expect(state.get("player_ap") == 2, "setup AP cost is paid")
	_expect(_has_status_id(state.call("get_snapshot").get("enemy_statuses", []), "status.vulnerable"), "vulnerable status is visible")
	_expect(_has_status_id(state.call("get_snapshot").get("enemy_statuses", []), "status.weaken"), "weaken status is visible")
	_expect(_has_status_id(state.call("get_snapshot").get("enemy_statuses", []), "status.bleed"), "damage-over-time status is visible")

	var first_strike_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(first_strike_result.get("ok"), "first strike resolves")
	_expect(state.get("player_ap") == 1, "AP cost is paid")
	_expect(state.get("enemy_hp") == 7, "vulnerable increases incoming damage")

	var duplicate_action_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(not duplicate_action_result.get("ok"), "same leader cannot actively act twice in one turn")
	_expect(state.get("player_ap") == 1, "failed duplicate action does not spend AP")
	_expect(state.get("enemy_hp") == 7, "failed duplicate action does not deal damage")

	var end_turn_result: Object = state.call("execute_command", CombatCommandScript.end_player_turn())
	_expect(end_turn_result.get("ok"), "turn advances through enemy action")
	_expect(state.get("turn_number") == 2, "new player turn starts after enemy phase")
	_expect(state.get("enemy_hp") == 4, "damage-over-time ticks at enemy turn start")
	_expect(state.get("player_hp") == 20, "weaken and guard affect enemy damage resolution")
	_expect(state.get("player_block") == 0, "player defense expires at next player turn")
	_expect(state.get("player_ap") == 3, "retained AP is recovered and capped")
	_expect(not _has_status_id(state.call("get_snapshot").get("enemy_statuses", []), "status.bleed"), "damage-over-time expires")
	_expect(not _has_status_id(state.call("get_snapshot").get("enemy_statuses", []), "status.weaken"), "weaken expires")
	_expect(not _has_status_id(state.call("get_snapshot").get("player_statuses", []), "status.guard"), "guard expires")

	var finishing_strike_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(finishing_strike_result.get("ok"), "leader may act again on the next turn")
	_expect(finishing_strike_result.get("outcome") == CombatResultScript.OUTCOME_VICTORY, "minimal battle reaches victory")
	_expect(state.call("is_finished"), "state is finished after victory")

	var heal_block_state: Object = CombatStateScript.new()
	var heal_block_start: Object = heal_block_state.call(
		"start_battle",
		{
			"max_ap": 1,
			"ap_recovery": 1,
			"initial_ap": 0,
			"player_max_hp": 10,
			"player_hp": 5,
			"enemy_max_hp": 5,
			"enemy_hp": 5,
			"leaders": [{"id": "leader.medic", "name": "Medic"}]
		}
	)
	_expect(heal_block_start.get("ok"), "heal-block battle starts")
	var heal_block_skill := {
		"id": "skill.test_heal_block",
		"name": "Test Heal Block",
		"cost": 0,
		"target": "self",
		"effects": [
			{"type": "apply_status", "status_id": "status.heal_block", "amount": 1, "duration": 1},
			{"type": "heal", "amount": 4}
		]
	}
	var heal_block_result: Object = heal_block_state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.medic", heal_block_skill, "player_team")
	)
	_expect(heal_block_result.get("ok"), "heal-block skill resolves")
	_expect(heal_block_state.get("player_hp") == 5, "heal_block prevents healing")

	var log_text := "\n".join(state.call("get_action_log"))
	var heal_block_log_text := "\n".join(heal_block_state.call("get_action_log"))
	_expect(log_text.contains("AP:"), "log records AP changes")
	_expect(log_text.contains("Damage:"), "log records damage")
	_expect(log_text.contains("Heal:"), "log records healing")
	_expect(log_text.contains("Defense:"), "log records defense")
	_expect(log_text.contains("Status:"), "log records status changes")
	_expect(log_text.contains("Vulnerable"), "log uses status display names from data")
	_expect(log_text.contains("Weaken"), "log records weaken damage changes")
	_expect(log_text.contains("Guard"), "log records guard defense changes")
	_expect(log_text.contains("expired"), "log records status expiry")
	_expect(heal_block_log_text.contains("Heal blocked:"), "log records heal-block restrictions")
	_expect(log_text.contains("Interrupt placeholder:"), "log records interrupt placeholders")
	_expect(log_text.contains("player phase begins"), "log records turn switches")
	_expect(log_text.contains("Battle finished: victory."), "log records battle outcome")

	if _failures.is_empty():
		print("Combat minimal test passed.")
		quit(0)
		return

	printerr("Combat minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_status_id(status_rows: Array, status_id: String) -> bool:
	for row in status_rows:
		if typeof(row) == TYPE_DICTIONARY and row.get("id", "") == status_id:
			return true
	return false
