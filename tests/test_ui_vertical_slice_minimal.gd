extends SceneTree

const QuestVerticalSliceScene := preload("res://scenes/ui/quest_vertical_slice.tscn")

var _failures := []


func _init() -> void:
	_test_vertical_slice_flow()
	_finish()


func _test_vertical_slice_flow() -> void:
	var screen = QuestVerticalSliceScene.instantiate()
	get_root().add_child(screen)

	var init_result: Dictionary = screen.initialize_vertical_slice()
	_expect(init_result.get("ok"), "vertical slice initializes sample data")
	_expect_equal("strategy", screen.get_slice_summary().get("phase", ""), "slice starts at strategy")
	_expect_equal(6, screen.get_warzone_pressure("warzone.ash_road"), "ash road starts with visible pressure")

	_expect(screen.start_quest_from_strategy("quest.secure_crossroad").get("ok"), "strategy can start the sample quest")
	_expect_equal("quest", screen.get_slice_summary().get("phase", ""), "quest screen opens")
	_expect_equal("start", screen.get_slice_summary().get("current_node_id", ""), "legacy quest starts at the event node")

	_expect(screen.advance_quest_node().get("ok"), "event node advances")
	_expect_equal("battle_0", screen.get_slice_summary().get("current_node_id", ""), "quest advances to the battle node")
	_expect(screen.advance_quest_node().get("ok"), "battle node opens formation")
	_expect_equal("formation", screen.get_slice_summary().get("phase", ""), "formation screen opens before combat")

	_expect(screen.start_combat_from_formation().get("ok"), "formation starts combat")
	_expect_equal("combat", screen.get_slice_summary().get("phase", ""), "combat screen opens")
	_expect(screen.execute_combat_action("attack").get("ok"), "player can choose an attack")
	_expect(screen.execute_combat_action("interrupt").get("ok"), "player can choose an interrupt")
	_expect(screen.end_player_turn().get("ok"), "player can end the turn and resolve the enemy preview")
	_expect(screen.execute_combat_action("attack").get("ok"), "player can finish the battle with another attack")
	_expect(screen.get_slice_summary().get("battle_resolved"), "battle reaches a resolved state")
	_expect_equal("victory", screen.get_slice_summary().get("battle_outcome", ""), "battle resolves as victory")

	_expect(screen.continue_after_battle().get("ok"), "victory continues to rewards")
	_expect_equal("reward", screen.get_slice_summary().get("phase", ""), "reward screen opens")
	_expect_equal(3, screen.get_slice_summary().get("reward_candidate_count", 0), "reward chest exposes three choices")
	_expect(screen.choose_reward(0).get("ok"), "player can choose one chest reward")
	_expect_equal("result", screen.get_slice_summary().get("phase", ""), "reward selection opens settlement")
	_expect_equal(4, screen.get_warzone_pressure("warzone.ash_road"), "quest settlement visibly lowers ash road pressure")
	_expect(screen.get_slice_summary().get("completed_quest_ids", []).has("quest.secure_crossroad"), "quest completion is recorded")
	_expect_equal(2, screen.get_slice_summary().get("rank", 0), "unit rank changes after settlement")
	_expect(screen.return_to_strategy().get("ok"), "settlement can return to strategy")
	_expect_equal("strategy", screen.get_slice_summary().get("phase", ""), "strategy screen is restored")

	get_root().remove_child(screen)
	screen.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("UI vertical slice minimal test passed.")
		quit(0)
		return

	printerr("UI vertical slice minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
