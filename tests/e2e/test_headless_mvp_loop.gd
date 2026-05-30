extends SceneTree

const CollectionStateScript := preload("res://src/cards_characters/collection_state.gd")
const CombatResultScript := preload("res://src/combat/combat_result.gd")
const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const FormationStateScript := preload("res://src/cards_characters/formation_state.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestRunStateScript := preload("res://src/quests_events_endings/quest_run_state.gd")

const CAMPAIGN_ID := "campaign.prologue"
const QUEST_ID := "quest.secure_crossroad"
const COMBAT_CARD_ID := "card.frost_lance"
const FRONTLINE_IDS := ["character.iris", "character.maelle", "character.ren"]

var _failures := []


func _init() -> void:
	var exit_code := _run()
	if exit_code == 0:
		print("Headless MVP loop E2E smoke test passed.")
	else:
		printerr("Headless MVP loop E2E smoke test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
	quit(exit_code)


func _run() -> int:
	var loader = ContentDataLoaderScript.new()
	var loaded: Dictionary = loader.load_and_validate()
	_expect(loaded["ok"], "sample content data validates before the E2E flow")
	if not loaded["ok"]:
		for error in loaded["errors"]:
			_failures.append(error)
		return 1

	var indexes: Dictionary = loaded["indexes"]
	var collection = _build_minimal_collection(loaded)
	_expect(collection != null, "minimal collection can be built from loaded content")
	if collection == null:
		return 1

	var formation = FormationStateScript.new(collection)
	for index in range(FRONTLINE_IDS.size()):
		var assign_result: Dictionary = formation.set_leader(index, FRONTLINE_IDS[index])
		_expect(assign_result["ok"], "frontline slot %s accepts %s" % [index, FRONTLINE_IDS[index]])

	var formation_summary: Dictionary = formation.get_summary()
	var party_hp := int(formation_summary.get("party_hp", 0))
	var skill_ids: Array = formation_summary.get("available_skill_ids", [])
	_expect(party_hp > 0, "formation exposes a positive shared party HP pool")
	_expect(skill_ids.size() >= 3, "formation exposes non-empty leader skill options")
	_expect(skill_ids.has("skill.shield_wall"), "formation includes Iris leader skills")
	_expect(skill_ids.has("skill.field_medicine"), "formation includes Maelle leader skills")
	_expect(skill_ids.has("skill.surge_control"), "formation includes Ren leader skills")

	var combat_card: Dictionary = _definition(indexes, "cards", COMBAT_CARD_ID)
	_expect(not combat_card.is_empty(), "combat card is loaded from card content")
	_expect(_character_starts_with_card(indexes, "character.ren", COMBAT_CARD_ID), "frontline deck data includes the combat card")
	if combat_card.is_empty():
		return 1

	var quest = QuestDefinitionScript.from_content_id(loaded, QUEST_ID)
	_expect(quest != null, "quest definition is built from loaded content")
	if quest == null:
		return 1

	var run = QuestRunStateScript.new(
		quest,
		loaded,
		{
			"player_max_hp": party_hp,
			"player_hp": party_hp,
			"reward_seed": 11,
			"battle_turn_limit": 4,
			"leaders": _combat_leaders_from_formation(formation, indexes),
			"player_skill": combat_card
		}
	)
	_expect_equal(party_hp, run.get("player_max_hp"), "quest uses formation shared HP as player max HP")
	_expect_equal(party_hp, run.get("player_hp"), "quest starts from the formation shared HP pool")
	_expect_equal("start", run.get("current_node_id"), "legacy quest starts at the synthesized start node")

	var start_result: Dictionary = run.advance()
	_expect(start_result["ok"], "start event advances without UI input")
	_expect_equal("battle_0", run.get("current_node_id"), "start event routes to the first combat node")

	var battle_result: Dictionary = run.advance()
	_expect(battle_result["ok"], "quest combat node resolves headlessly")
	_expect(battle_result.has("combat_result"), "battle result exposes combat resolution")
	if battle_result.has("combat_result"):
		var combat_summary: Dictionary = battle_result["combat_result"].to_dictionary()
		var combat_snapshot: Dictionary = combat_summary.get("snapshot", {})
		_expect_equal(CombatResultScript.OUTCOME_VICTORY, combat_summary.get("outcome", ""), "combat reaches deterministic victory")
		_expect_equal(0, int(combat_snapshot.get("enemy_hp", -1)), "combat leaves the enemy defeated")
		_expect_equal(2, int(combat_snapshot.get("turn_number", -1)), "combat resolves on the expected player turn")
		_expect_equal(party_hp - 3, int(combat_snapshot.get("player_hp", -1)), "combat applies the expected shared HP damage")
		_expect(_logs_contain(combat_summary.get("logs", []), "Frost Lance"), "combat log records the loaded card action")
	_expect_equal(party_hp - 3, run.get("player_hp"), "quest carries combat HP back to the run state")
	_expect_equal("chest", run.get("current_node_id"), "combat victory routes to the reward chest")

	var chest_result: Dictionary = run.advance()
	_expect(chest_result["ok"], "reward chest generates candidates")
	_expect(bool(chest_result.get("awaiting_choice", false)), "reward chest waits for a deterministic selection")
	var candidates: Array = chest_result.get("candidates", [])
	_expect_equal(3, candidates.size(), "reward chest exposes three candidates")
	if candidates.is_empty():
		return 1

	var first_candidate: Dictionary = candidates[0]
	var choice_result: Dictionary = run.choose_chest_reward(0)
	_expect(choice_result["ok"], "reward selection can be applied without UI input")
	var selected_reward: Dictionary = choice_result.get("selected_reward", {})
	_expect_equal(first_candidate.get("candidate_id", ""), selected_reward.get("candidate_id", ""), "selected reward is the deterministic first candidate")
	_expect_equal("result", run.get("current_node_id"), "selected reward routes to quest result")

	var result: Dictionary = run.advance()
	_expect(result["ok"], "quest result resolves")
	_expect(run.is_finished(), "quest run finishes")
	var summary: Dictionary = result.get("summary", {})
	_expect_equal(QuestRunStateScript.OUTCOME_VICTORY, summary.get("outcome", ""), "quest settlement records victory")
	_expect_equal(1, summary.get("combat_results", []).size(), "settlement records one combat result")
	_expect_equal(1, summary.get("chest_choices", []).size(), "settlement records the reward choice")
	_expect(int(summary.get("exp", 0)) > 0, "settlement applies combat EXP")
	_expect(summary.get("progression_reward_ids", []).has("progression.first_victory"), "settlement includes the quest progression reward")
	_expect(_summary_contains_reward(summary, selected_reward), "settlement applies the selected reward")

	return 1 if not _failures.is_empty() else 0


func _build_minimal_collection(loaded: Dictionary):
	var indexes: Dictionary = loaded["indexes"]
	var campaign: Dictionary = _definition(indexes, "campaigns", CAMPAIGN_ID)
	_expect(not campaign.is_empty(), "campaign fixture is available")
	if campaign.is_empty():
		return null

	var character_ids := []
	for character_id in campaign.get("entry_character_ids", []):
		_add_unique(character_ids, str(character_id))
	for character_id in FRONTLINE_IDS:
		_add_unique(character_ids, str(character_id))

	var collection = CollectionStateScript.new(loaded)
	var added_cards: Array = collection.add_character_cards(character_ids)
	_expect_equal(character_ids.size(), added_cards.size(), "all minimal collection cards are accepted")
	for character_id in character_ids:
		_expect(collection.has_character_card(character_id), "collection owns %s" % character_id)
	return collection


func _combat_leaders_from_formation(formation, indexes: Dictionary) -> Array:
	var leaders := []
	for character_id in formation.get_leader_character_ids():
		var character: Dictionary = _definition(indexes, "characters", str(character_id))
		leaders.append(
			{
				"id": str(character_id),
				"name": str(character.get("name", character_id))
			}
		)
	return leaders


func _definition(indexes: Dictionary, table_key: String, content_id: String) -> Dictionary:
	var table: Dictionary = indexes.get(table_key, {})
	return table.get(content_id, {})


func _character_starts_with_card(indexes: Dictionary, character_id: String, card_id: String) -> bool:
	var character: Dictionary = _definition(indexes, "characters", character_id)
	var starting_deck: Array = character.get("starting_deck", [])
	return starting_deck.has(card_id)


func _summary_contains_reward(summary: Dictionary, selected_reward: Dictionary) -> bool:
	var content_id := str(selected_reward.get("content_id", ""))
	match str(selected_reward.get("kind", "")):
		"card":
			return summary.get("card_ids", []).has(content_id)
		"skill":
			return summary.get("skill_ids", []).has(content_id)
		_:
			return false


func _logs_contain(logs: Array, needle: String) -> bool:
	for row in logs:
		if str(row).contains(needle):
			return true
	return false


func _add_unique(target: Array, value: String) -> void:
	if not target.has(value):
		target.append(value)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
