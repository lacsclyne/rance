extends SceneTree

const CampaignStateScript := preload("res://src/strategy_map/campaign_state.gd")
const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestRunStateScript := preload("res://src/quests_events_endings/quest_run_state.gd")

var _failures := []


func _init() -> void:
	var exit_code := _run()
	if exit_code == 0:
		print("Campaign fronts minimal simulation passed.")
	else:
		printerr("Campaign fronts minimal simulation failed:")
		for failure in _failures:
			printerr("- %s" % failure)
	quit(exit_code)


func _run() -> int:
	var loader = ContentDataLoaderScript.new()
	var loaded: Dictionary = loader.load_and_validate()
	_expect(loaded["ok"], "content data validates before campaign checks")
	if not loaded["ok"]:
		for error in loaded["errors"]:
			_failures.append(error)
		return 1

	var campaign = CampaignStateScript.minimal_sample()
	_expect(campaign.call("is_valid"), "minimal campaign sample has three fronts and actions")
	_expect_equal(3, campaign.get("fronts").size(), "campaign sample defines three original fronts")

	var initial_offers: Array = campaign.call("get_available_quests")
	_expect_equal(3, initial_offers.size(), "campaign lists one available quest per front")

	var glass_offer := _offer_for_quest(initial_offers, "quest.recover_relic")
	_expect(not glass_offer.is_empty(), "high-pressure front still lists its relief quest")
	_expect_equal("reduced", glass_offer.get("reward_tier", ""), "high pressure downgrades the reward tier")
	var glass_front = campaign.call("get_front", "front.glass_marsh")
	_expect(
		int(glass_offer.get("enemy_strength", 0)) > int(glass_front.get("enemy_strength")),
		"high pressure increases effective enemy strength"
	)

	var selection: Dictionary = campaign.call("select_quest", "quest.secure_crossroad")
	_expect(selection["ok"], "strategy layer can select an available quest")
	_expect_equal("front.ember_pass", selection.get("quest", {}).get("front_id", ""), "selected quest is tied to its front")

	var ember_front = campaign.call("get_front", "front.ember_pass")
	var ember_pressure_before: int = int(ember_front.get("pressure"))
	var quest = QuestDefinitionScript.from_content_id(loaded, "quest.secure_crossroad")
	_expect(quest != null, "selected quest definition exists in content data")
	if quest == null:
		return 1

	var quest_run = QuestRunStateScript.new(
		quest,
		loaded,
		{
			"player_max_hp": 24,
			"player_hp": 24,
			"reward_seed": 23
		}
	)
	var quest_simulation: Dictionary = quest_run.call("simulate_to_result", {"reward_index": 0})
	_expect(quest_simulation["ok"], "selected quest can complete without UI")
	var settlement_summary: Dictionary = quest_simulation.get("summary", {})
	_expect_equal("quest.secure_crossroad", settlement_summary.get("quest_id", ""), "quest settlement exposes quest_id")

	var consumed: Dictionary = campaign.call("consume_quest_settlement", settlement_summary)
	_expect(consumed["ok"], "campaign consumes quest settlement summary")
	_expect(consumed.get("success", false), "quest victory is interpreted as strategic success")
	_expect(
		int(consumed.get("pressure_change", {}).get("pressure_after", 0)) < ember_pressure_before,
		"quest success lowers the assigned front pressure"
	)
	_expect(
		campaign.get("completed_quest_ids").has("quest.secure_crossroad"),
		"successful quest is recorded as completed"
	)
	_expect(
		_offer_for_quest(campaign.call("get_available_quests"), "quest.secure_crossroad").is_empty(),
		"completed quest is removed from next available quests"
	)

	var ember_pressure_after_success: int = int(ember_front.get("pressure"))
	var turn_result: Dictionary = campaign.call("advance_turn")
	_expect(turn_result["ok"], "campaign can enter the next strategic turn")
	_expect_equal(2, turn_result.get("turn_number", 0), "strategic turn counter advances")
	_expect(
		int(ember_front.get("pressure")) > ember_pressure_after_success,
		"front pressure naturally changes on the next turn"
	)
	_expect(
		int(ember_front.get("pressure")) < ember_pressure_before,
		"success momentum keeps the front below its pre-quest pressure after one turn"
	)

	var glass_pressure_before: int = int(glass_front.get("pressure"))
	var failure_summary := {
		"quest_id": "quest.recover_relic",
		"quest_name": "Recover the Shrine Relic",
		"outcome": QuestRunStateScript.OUTCOME_DEFEAT
	}
	var failed_settlement: Dictionary = campaign.call("consume_quest_settlement", failure_summary)
	_expect(failed_settlement["ok"], "campaign consumes a defeat settlement summary")
	_expect(not failed_settlement.get("success", true), "quest defeat is interpreted as strategic failure")
	_expect(
		int(glass_front.get("pressure")) > glass_pressure_before,
		"quest failure raises the assigned front pressure"
	)
	_expect_equal(
		1,
		campaign.get("failed_quest_counts").get("quest.recover_relic", 0),
		"failed quest attempts are tracked"
	)
	_expect(
		not _offer_for_quest(campaign.call("get_available_quests"), "quest.recover_relic").is_empty(),
		"failed quest remains available for a later strategic choice"
	)

	var salt_front = campaign.call("get_front", "front.salt_coast")
	salt_front.call("apply_pressure_delta", 40, "test_critical_lock")
	_expect(
		_offer_for_quest(campaign.call("get_available_quests"), "quest.close_foundry").is_empty(),
		"critical pressure can remove a quest from availability"
	)

	var no_ui_campaign = CampaignStateScript.minimal_sample()
	var no_ui_result: Dictionary = no_ui_campaign.call(
		"simulate_no_ui_step",
		"quest.secure_crossroad",
		settlement_summary
	)
	_expect(no_ui_result["ok"], "campaign exposes a no-UI select-complete-next-turn simulation")
	_expect_equal(
		2,
		no_ui_result.get("next_turn", {}).get("turn_number", 0),
		"no-UI simulation enters the next strategic turn"
	)

	return 1 if not _failures.is_empty() else 0


func _offer_for_quest(offers: Array, quest_id: String) -> Dictionary:
	for offer in offers:
		if typeof(offer) == TYPE_DICTIONARY and offer.get("quest_id", "") == quest_id:
			return offer
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
