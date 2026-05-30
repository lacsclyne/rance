extends SceneTree

const CombatStateScript := preload("res://src/combat/combat_state.gd")
const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const FormationStateScript := preload("res://src/cards_characters/formation_state.gd")
const ProgressionStateScript := preload("res://src/progression/progression_state.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestRunStateScript := preload("res://src/quests_events_endings/quest_run_state.gd")
const RewardPoolDefinitionScript := preload("res://src/quests_events_endings/reward_pool_definition.gd")
const SaveManagerScript := preload("res://src/save/save_manager.gd")

var _failures := []


func _init() -> void:
	var loader = ContentDataLoaderScript.new()
	var loaded: Dictionary = loader.load_and_validate()
	_expect(loaded["ok"], "content data validates before progression checks")
	if not loaded["ok"]:
		for error in loaded["errors"]:
			_failures.append(error)
		_finish()
		return

	_test_quest_medals_rank_rewards_and_model_reads(loaded)
	_test_discovery_save_round_trip_and_carryover(loaded)
	_finish()


func _test_quest_medals_rank_rewards_and_model_reads(loaded: Dictionary) -> void:
	var indexes: Dictionary = loaded["indexes"]
	var quest = QuestDefinitionScript.minimal_sample(indexes)
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
	_expect(simulation["ok"], "sample quest reaches settlement")
	var summary: Dictionary = simulation.get("summary", {})
	_expect(summary.get("medal_ids", []).has("medal.sample_clear"), "sample quest settlement includes a medal")

	var progression = ProgressionStateScript.new()
	var consume_result: Dictionary = progression.call("consume_quest_settlement", summary, indexes)
	_expect(consume_result["ok"], "progression consumes quest settlement")
	_expect_equal(1, progression.call("get_medal_total"), "sample medal increments total medals")
	_expect_equal(2, progression.call("get_rank"), "one medal raises troop Rank to 2")
	_expect_equal(1, progression.call("get_pending_rank_reward_choices"), "rank up grants a reward choice")

	var frontline_choice: Dictionary = progression.call("choose_rank_reward", "rank_reward.frontline_slot_1")
	_expect(frontline_choice["ok"], "frontline rank reward can be selected")
	var formation = FormationStateScript.new()
	formation.call("apply_system_unlocks", progression.call("get_system_unlocks"))
	_expect_equal(4, formation.call("get_frontline_slot_count"), "formation reads frontline slot unlock")

	progression.call("add_medal", "medal.training_one", "test")
	progression.call("add_medal", "medal.training_two", "test")
	_expect_equal(3, progression.call("get_rank"), "three total medals raises troop Rank to 3")
	var ap_choice: Dictionary = progression.call("choose_rank_reward", "rank_reward.ap_training_1")
	_expect(ap_choice["ok"], "AP rank reward can be selected")
	var combat_state = CombatStateScript.new()
	var start_result = combat_state.call(
		"start_battle",
		{
			"max_ap": 3,
			"ap_recovery": 3,
			"initial_ap": 0,
			"player_max_hp": 10,
			"player_hp": 10,
			"enemy_max_hp": 5,
			"enemy_hp": 5,
			"leaders": [{"id": "leader.progression_probe", "name": "Progression Probe"}],
			"system_unlocks": progression.call("get_system_unlocks")
		}
	)
	_expect(start_result.get("ok"), "combat starts with progression unlocks")
	_expect_equal(4, combat_state.get("max_ap"), "combat model reads max AP unlock")
	_expect_equal(4, combat_state.get("player_ap"), "combat model reads AP recovery unlock")

	progression.call("add_medal", "medal.weight_one", "test")
	progression.call("add_medal", "medal.weight_two", "test")
	progression.call("add_medal", "medal.weight_three", "test")
	_expect_equal(4, progression.call("get_rank"), "six total medals raises troop Rank to 4")
	var reward_choice: Dictionary = progression.call("choose_rank_reward", "rank_reward.reward_weight_1")
	_expect(reward_choice["ok"], "reward weight rank reward can be selected")
	var pool = RewardPoolDefinitionScript.new(
		{
			"id": "reward_pool.test",
			"name": "Test Rewards",
			"entries": [
				{"kind": "card", "content_id": "card.spark_bolt", "weight": 1}
			]
		}
	)
	var candidates: Array = pool.call("generate_candidates", 1, 1, progression.call("get_reward_weight_modifiers"))
	_expect_equal(2, candidates[0]["weight"], "reward pool reads reward weight unlock")

	var discovery: Dictionary = progression.call("get_discovery_snapshot")
	var quest_record: Dictionary = discovery.get("quest_records", {}).get("quest.minimal_graph_sample", {})
	_expect(quest_record.has("first_completed"), "discovery records first quest completion")
	var boss_record: Dictionary = discovery.get("boss_intel", {}).get("encounter.foundry_gate", {})
	_expect(not boss_record.get("known_previews", {}).is_empty(), "discovery records boss previews from settlement")


func _test_discovery_save_round_trip_and_carryover(loaded: Dictionary) -> void:
	var indexes: Dictionary = loaded["indexes"]
	var progression = ProgressionStateScript.new()
	var unlock_result: Dictionary = progression.call(
		"unlock_progression_node",
		"progression.prologue_start",
		indexes,
		"campaign_start"
	)
	_expect(unlock_result["ok"], "progression content unlock can be applied")
	progression.call("record_boss_preview", "boss.sample", "intent.sample_warning", "scout_report")
	progression.call("record_boss_weakness", "boss.sample", "status.vulnerable", "battle_note")
	progression.call(
		"consume_quest_settlement",
		{
			"quest_id": "quest.failed_probe",
			"outcome": QuestRunStateScript.OUTCOME_DEFEAT,
			"medal_ids": [],
			"progression_reward_ids": []
		},
		indexes
	)
	progression.call("add_medal", "medal.sample_clear", "test")
	progression.call("choose_rank_reward", "rank_reward.frontline_slot_1")

	var save_manager = SaveManagerScript.new()
	var save: Dictionary = save_manager.create_save(
		"slot_progression",
		{"slot_label": "Progression"},
		{"progression": progression.call("to_dictionary")}
	)
	var decoded: Dictionary = save_manager.deserialize_snapshot(save)
	_expect(decoded["ok"], "save snapshot with progression section deserializes")
	var restored = ProgressionStateScript.new(decoded["snapshot"]["progression"])
	_expect_equal(progression.call("get_rank"), restored.call("get_rank"), "progression rank round-trips through save")
	_expect_equal(
		progression.call("get_system_unlocks"),
		restored.call("get_system_unlocks"),
		"progression unlocks round-trip through save"
	)

	var restored_discovery: Dictionary = restored.call("get_discovery_snapshot")
	var character_source: Dictionary = restored_discovery.get("character_sources", {}).get("character.iris", {})
	_expect_equal("campaign_start", character_source.get("source", ""), "character first source is recorded")
	var failed_record: Dictionary = restored_discovery.get("quest_records", {}).get("quest.failed_probe", {})
	_expect(failed_record.has("first_failed"), "discovery records first quest failure")
	var boss_record: Dictionary = restored_discovery.get("boss_intel", {}).get("boss.sample", {})
	_expect(
		boss_record.get("known_previews", {}).has("intent.sample_warning"),
		"boss preview source is recorded"
	)
	_expect(
		boss_record.get("known_weaknesses", {}).has("status.vulnerable"),
		"boss weakness source is recorded"
	)

	var carryover = restored.call("create_carryover_state")
	var next_run = ProgressionStateScript.from_carryover(carryover)
	_expect_equal(0, next_run.call("get_medal_total"), "new run does not inherit medals")
	_expect_equal(1, next_run.call("get_rank"), "new run resets troop Rank")
	_expect_equal(
		restored.call("get_system_unlocks"),
		next_run.call("get_system_unlocks"),
		"new run keeps allowed system unlocks"
	)
	var next_discovery: Dictionary = next_run.call("get_discovery_snapshot")
	_expect(
		next_discovery.get("character_sources", {}).has("character.iris"),
		"new run keeps discovery log"
	)
	var next_history: Dictionary = next_run.call("get_run_history_snapshot")
	_expect_equal(1, next_history.get("quest_results", []).size(), "new run does not inherit full quest history")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("Progression state minimal test passed.")
		quit(0)
		return

	printerr("Progression state minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
