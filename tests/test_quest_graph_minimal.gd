extends SceneTree

const CombatResultScript := preload("res://src/combat/combat_result.gd")
const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestNodeScript := preload("res://src/quests_events_endings/quest_node.gd")
const QuestRunStateScript := preload("res://src/quests_events_endings/quest_run_state.gd")

var _failures := []


func _init() -> void:
	var loader = ContentDataLoaderScript.new()
	var loaded: Dictionary = loader.load_and_validate()
	_expect(loaded["ok"], "content data validates before quest graph checks")
	if not loaded["ok"]:
		for error in loaded["errors"]:
			_failures.append(error)
		_finish()
		return

	_test_legacy_quest_can_reach_result(loaded)
	_test_minimal_sample_supports_node_types(loaded)
	_finish()


func _test_legacy_quest_can_reach_result(loaded: Dictionary) -> void:
	var quest = QuestDefinitionScript.from_content_id(loaded, "quest.secure_crossroad")
	_expect(quest != null, "quest definition can be built from content data")
	if quest == null:
		return
	_expect(quest.call("is_valid"), "legacy quest row synthesizes a valid graph")
	_expect(quest.call("get_node", "battle_0").get("type") == QuestNodeScript.TYPE_BATTLE, "legacy encounter becomes a battle node")
	_expect(quest.call("get_node", "chest").get("type") == QuestNodeScript.TYPE_CHEST, "legacy reward pool becomes a chest node")
	_expect(quest.call("get_node", "result").get("type") == QuestNodeScript.TYPE_RESULT, "legacy quest has a result node")

	var run = QuestRunStateScript.new(
		quest,
		loaded,
		{
			"player_max_hp": 24,
			"player_hp": 24,
			"reward_seed": 11
		}
	)
	_expect(run.get("current_node_id") == "start", "quest run starts at the synthesized start node")

	var start_result: Dictionary = run.call("advance")
	_expect(start_result["ok"], "start event advances")
	_expect(run.get("current_node_id") == "battle_0", "start event routes to battle")

	var hp_before_battle: int = run.get("player_hp")
	var battle_result: Dictionary = run.call("advance")
	_expect(battle_result["ok"], "battle node advances")
	_expect(battle_result.has("combat_result"), "battle node returns a CombatResult")
	if battle_result.has("combat_result"):
		var combat_result = battle_result["combat_result"]
		var combat_summary: Dictionary = combat_result.call("to_dictionary")
		_expect(combat_summary["outcome"] == CombatResultScript.OUTCOME_VICTORY, "battle simulation reaches victory")
	_expect(run.get("player_hp") < hp_before_battle, "battle node consumes shared player HP")
	_expect(run.get("current_node_id") == "chest", "battle routes to chest")

	var chest_result: Dictionary = run.call("advance")
	_expect(chest_result["ok"], "chest node can generate reward candidates")
	_expect(bool(chest_result.get("awaiting_choice", false)), "chest waits for player reward choice")
	_expect(chest_result.get("candidates", []).size() == 3, "chest generates exactly three candidates")

	var choice_result: Dictionary = run.call("choose_chest_reward", 1)
	_expect(choice_result["ok"], "chest records selected reward")
	_expect(choice_result.has("selected_reward"), "selected chest reward is exposed")
	_expect(run.get("current_node_id") == "result", "chest routes to result after selection")

	var result: Dictionary = run.call("advance")
	_expect(result["ok"], "result node resolves")
	_expect(run.call("is_finished"), "quest run finishes at result")
	var summary: Dictionary = result.get("summary", {})
	_expect(summary.get("outcome", "") == QuestRunStateScript.OUTCOME_VICTORY, "settlement summary records quest victory")
	_expect(int(summary.get("exp", 0)) > 0, "settlement summary includes EXP")
	_expect(summary.get("card_ids", []).size() + summary.get("skill_ids", []).size() >= 1, "settlement summary includes chosen card or skill reward")
	_expect(summary.get("chest_choices", []).size() == 1, "settlement summary records chest choice")
	_expect(summary.get("combat_results", []).size() == 1, "settlement summary records combat result")
	_expect(summary.get("warzone_impact", {}).has("warzone.sample"), "settlement summary includes warzone impact")
	_expect(summary.get("progression_reward_ids", []).has("progression.first_victory"), "settlement summary includes progression reward")


func _test_minimal_sample_supports_node_types(loaded: Dictionary) -> void:
	var indexes: Dictionary = loaded["indexes"]
	var quest = QuestDefinitionScript.minimal_sample(indexes)
	_expect(quest.call("is_valid"), "minimal sample quest graph is valid")

	var supported_types := {
		QuestNodeScript.TYPE_BATTLE: false,
		QuestNodeScript.TYPE_ELITE: false,
		QuestNodeScript.TYPE_BOSS: false,
		QuestNodeScript.TYPE_EVENT: false,
		QuestNodeScript.TYPE_CHEST: false,
		QuestNodeScript.TYPE_REST: false,
		QuestNodeScript.TYPE_BRANCH: false,
		QuestNodeScript.TYPE_RESULT: false
	}
	for node_id in quest.call("get_node_ids"):
		var node = quest.call("get_node", node_id)
		supported_types[node.get("type")] = true
	for node_type in supported_types.keys():
		_expect(supported_types[node_type], "minimal sample includes %s node support" % node_type)

	var run = QuestRunStateScript.new(
		quest,
		loaded,
		{
			"player_max_hp": 36,
			"player_hp": 30,
			"reward_seed": 17
		}
	)
	var simulation: Dictionary = run.call(
		"simulate_to_result",
		{
			"branch_choice_id": "standard_route",
			"reward_index": 0
		}
	)
	_expect(simulation["ok"], "minimal sample can simulate from start to result")
	var summary: Dictionary = simulation.get("summary", {})
	_expect(summary.get("combat_results", []).size() == 2, "minimal sample resolves battle and boss combat nodes")
	_expect(summary.get("rest_results", []).size() == 1, "minimal sample resolves rest node")
	_expect(summary.get("medal_ids", []).has("medal.sample_clear"), "minimal sample settlement can include medals")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Quest graph minimal test passed.")
		quit(0)
		return

	printerr("Quest graph minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
