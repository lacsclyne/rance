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
			"enemy_max_hp": 10,
			"enemy_hp": 10,
			"leaders": [
				{"id": "leader.guardian", "name": "Guardian"},
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
			{"type": "block", "amount": 5},
			{"type": "apply_status", "status_id": "status.focus", "amount": 1, "duration": 2},
			{"type": "interrupt"}
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
	_expect(state.get("player_block") == 5, "defense block is applied")
	_expect(state.get("player_statuses").size() == 1, "status placeholder records applied statuses")

	var first_strike_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(first_strike_result.get("ok"), "first strike resolves")
	_expect(state.get("player_ap") == 2, "AP cost is paid")
	_expect(state.get("enemy_hp") == 5, "damage uses shared enemy HP")

	var duplicate_action_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(not duplicate_action_result.get("ok"), "same leader cannot actively act twice in one turn")
	_expect(state.get("player_ap") == 2, "failed duplicate action does not spend AP")
	_expect(state.get("enemy_hp") == 5, "failed duplicate action does not deal damage")

	var end_turn_result: Object = state.call("execute_command", CombatCommandScript.end_player_turn())
	_expect(end_turn_result.get("ok"), "turn advances through enemy action")
	_expect(state.get("turn_number") == 2, "new player turn starts after enemy phase")
	_expect(state.get("player_hp") == 20, "enemy damage is reduced by player block")
	_expect(state.get("player_block") == 0, "player defense expires at next player turn")
	_expect(state.get("player_ap") == 3, "retained AP is recovered and capped")

	var finishing_strike_result: Object = state.call(
		"execute_command",
		CombatCommandScript.use_skill("leader.striker", strike_skill, "enemy_team")
	)
	_expect(finishing_strike_result.get("ok"), "leader may act again on the next turn")
	_expect(finishing_strike_result.get("outcome") == CombatResultScript.OUTCOME_VICTORY, "minimal battle reaches victory")
	_expect(state.call("is_finished"), "state is finished after victory")

	var log_text := "\n".join(state.call("get_action_log"))
	_expect(log_text.contains("AP:"), "log records AP changes")
	_expect(log_text.contains("Damage:"), "log records damage")
	_expect(log_text.contains("Heal:"), "log records healing")
	_expect(log_text.contains("Defense:"), "log records defense")
	_expect(log_text.contains("Status placeholder:"), "log records status placeholders")
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
