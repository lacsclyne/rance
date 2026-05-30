class_name QuestVerticalSliceScreen
extends Control

const CollectionStateScript := preload("res://src/cards_characters/collection_state.gd")
const CombatCommandScript := preload("res://src/combat/combat_command.gd")
const CombatStateScript := preload("res://src/combat/combat_state.gd")
const ContentDataLoaderScript := preload("res://src/data/content_data_loader.gd")
const FormationStateScript := preload("res://src/cards_characters/formation_state.gd")
const QuestDefinitionScript := preload("res://src/quests_events_endings/quest_definition.gd")
const QuestNodeScript := preload("res://src/quests_events_endings/quest_node.gd")
const RewardPoolDefinitionScript := preload("res://src/quests_events_endings/reward_pool_definition.gd")

const PHASE_STRATEGY := "strategy"
const PHASE_QUEST := "quest"
const PHASE_FORMATION := "formation"
const PHASE_COMBAT := "combat"
const PHASE_REWARD := "reward"
const PHASE_RESULT := "result"

const DEFAULT_CAMPAIGN_ID := "campaign.prologue"
const DEFAULT_QUEST_ID := "quest.secure_crossroad"
const DEFAULT_LEADER_IDS := ["character.iris", "character.maelle", "character.ren"]
const ASH_ROAD_FRONT_ID := "warzone.ash_road"

var phase := PHASE_STRATEGY
var round_number := 1
var content := {}
var indexes := {}
var collection_state = null
var formation_state = null
var selected_quest = null
var selected_quest_id := DEFAULT_QUEST_ID
var current_node_id := ""
var pending_battle_node_id := ""
var combat_state = null
var battle_resolved := false
var battle_outcome := ""
var reward_candidates := []
var selected_reward := {}
var earned_card_ids := []
var earned_skill_ids := []
var completed_quest_ids := []
var rank_value := 1
var latest_settlement := {}
var warzones := []

var _main_column: VBoxContainer = null
var _header_label: Label = null
var _subheader_label: Label = null
var _content_root: VBoxContainer = null
var _log_lines := []


func _ready() -> void:
	_build_static_layout()
	initialize_vertical_slice()


func initialize_vertical_slice() -> Dictionary:
	_build_static_layout()
	phase = PHASE_STRATEGY
	round_number = 1
	selected_quest_id = DEFAULT_QUEST_ID
	current_node_id = ""
	pending_battle_node_id = ""
	combat_state = null
	battle_resolved = false
	battle_outcome = ""
	reward_candidates.clear()
	selected_reward.clear()
	earned_card_ids.clear()
	earned_skill_ids.clear()
	completed_quest_ids.clear()
	latest_settlement.clear()
	_log_lines.clear()
	rank_value = 1
	warzones = [
		{"id": "warzone.north_gate", "name": "North Gate", "pressure": 4},
		{"id": "warzone.river_ward", "name": "River Ward", "pressure": 5},
		{"id": ASH_ROAD_FRONT_ID, "name": "Ash Road", "pressure": 6}
	]

	var loader = ContentDataLoaderScript.new()
	var loaded: Dictionary = loader.load_and_validate()
	if not bool(loaded.get("ok", false)):
		_render_error("Content data failed validation.", loaded.get("errors", []))
		return {
			"ok": false,
			"errors": loaded.get("errors", [])
		}

	content = loaded
	indexes = loaded.get("indexes", {})
	_build_collection_and_formation()
	_render_strategy_screen()
	return {"ok": true}


func start_quest_from_strategy(quest_id: String = DEFAULT_QUEST_ID) -> Dictionary:
	if phase != PHASE_STRATEGY:
		return _error("quests can only start from the strategy screen")
	if completed_quest_ids.has(quest_id):
		return _error("quest '%s' is already completed in this slice" % quest_id)

	var quest = QuestDefinitionScript.from_content_id(content, quest_id)
	if quest == null or not quest.call("is_valid"):
		return _error("quest '%s' is not available" % quest_id)

	selected_quest = quest
	selected_quest_id = quest_id
	current_node_id = str(quest.get("start_node_id"))
	pending_battle_node_id = ""
	reward_candidates.clear()
	selected_reward.clear()
	latest_settlement.clear()
	battle_resolved = false
	battle_outcome = ""
	_log_lines = ["Quest accepted: %s." % quest.get("name")]
	phase = PHASE_QUEST
	_render_quest_screen()
	return _ok()


func advance_quest_node() -> Dictionary:
	if phase != PHASE_QUEST:
		return _error("quest nodes can only advance from the quest screen")
	var node = _current_quest_node()
	if node == null:
		return _error("current quest node '%s' is missing" % current_node_id)

	match str(node.get("type")):
		QuestNodeScript.TYPE_EVENT:
			_log_lines.append("Node resolved: route opened toward %s." % node.get("next_node_id"))
			current_node_id = str(node.get("next_node_id"))
			_render_quest_screen()
		QuestNodeScript.TYPE_BATTLE, QuestNodeScript.TYPE_ELITE, QuestNodeScript.TYPE_BOSS:
			pending_battle_node_id = current_node_id
			phase = PHASE_FORMATION
			_render_formation_screen()
		QuestNodeScript.TYPE_CHEST:
			_prepare_reward_candidates()
			phase = PHASE_REWARD
			_render_reward_screen()
		QuestNodeScript.TYPE_RESULT:
			_apply_settlement()
			phase = PHASE_RESULT
			_render_result_screen()
		_:
			return _error("unsupported quest node type '%s'" % node.get("type"))
	return _ok()


func start_combat_from_formation() -> Dictionary:
	if phase != PHASE_FORMATION:
		return _error("combat can only start from formation")

	var node = _current_quest_node()
	if node == null:
		return _error("battle node is missing")

	var encounter := _definition("encounters", str(node.get("encounter_id")))
	if encounter.is_empty():
		return _error("encounter '%s' is missing" % node.get("encounter_id"))

	var shared_hp := int(formation_state.call("get_party_hp"))
	var enemy_hp := _enemy_hp_for_encounter(encounter)
	var status_rows: Array = _table_values("statuses")
	combat_state = CombatStateScript.new()
	var result = combat_state.call(
		"start_battle",
		{
			"max_ap": 3,
			"ap_recovery": 3,
			"initial_ap": 0,
			"player_max_hp": shared_hp,
			"player_hp": shared_hp,
			"enemy_max_hp": enemy_hp,
			"enemy_hp": enemy_hp,
			"leaders": _combat_leaders_from_formation(),
			"encounter_definition": encounter,
			"status_definitions": status_rows
		}
	)
	var result_dictionary := _result_to_dictionary(result)
	if not bool(result_dictionary.get("ok", false)):
		return _error(str(result_dictionary.get("message", "combat failed to start")))

	battle_resolved = false
	battle_outcome = ""
	phase = PHASE_COMBAT
	_log_lines.append("Battle started: %s." % encounter.get("name"))
	_render_combat_screen()
	return _ok()


func execute_combat_action(action_id: String) -> Dictionary:
	if phase != PHASE_COMBAT or combat_state == null:
		return _error("combat is not active")
	if battle_resolved:
		return _error("battle is already resolved")

	var action := _combat_action(action_id)
	if action.is_empty():
		return _error("unknown combat action '%s'" % action_id)

	var result = combat_state.call(
		"execute_command",
		CombatCommandScript.use_skill(
			str(action.get("leader_id", "")),
			action.get("skill", {}),
			str(action.get("target_id", ""))
		)
	)
	_collect_combat_result(result)
	_render_combat_screen()
	return _result_to_dictionary(result)


func end_player_turn() -> Dictionary:
	if phase != PHASE_COMBAT or combat_state == null:
		return _error("combat is not active")
	if battle_resolved:
		return _error("battle is already resolved")

	var result = combat_state.call("execute_command", CombatCommandScript.end_player_turn())
	_collect_combat_result(result)
	_render_combat_screen()
	return _result_to_dictionary(result)


func continue_after_battle() -> Dictionary:
	if phase != PHASE_COMBAT or not battle_resolved:
		return _error("battle has not resolved")

	var node = _current_quest_node()
	if node == null:
		return _error("battle node is missing")

	if battle_outcome != CombatStateScript.OUTCOME_VICTORY:
		current_node_id = _result_node_id()
		_apply_settlement()
		phase = PHASE_RESULT
		_render_result_screen()
		return _ok()

	current_node_id = str(node.get("next_node_id"))
	if current_node_id.is_empty():
		return _error("battle node has no next node")
	_prepare_reward_candidates()
	phase = PHASE_REWARD
	_render_reward_screen()
	return _ok()


func choose_reward(candidate_index: int) -> Dictionary:
	if phase != PHASE_REWARD:
		return _error("reward choices are not active")
	if candidate_index < 0 or candidate_index >= reward_candidates.size():
		return _error("reward candidate index %s is outside the chest" % candidate_index)

	selected_reward = reward_candidates[candidate_index].duplicate(true)
	match str(selected_reward.get("kind", "")):
		"card":
			_add_unique(earned_card_ids, str(selected_reward.get("content_id", "")))
		"skill":
			_add_unique(earned_skill_ids, str(selected_reward.get("content_id", "")))

	var node = _current_quest_node()
	if node != null:
		current_node_id = str(node.get("next_node_id"))
	_apply_settlement()
	phase = PHASE_RESULT
	_render_result_screen()
	return _ok()


func return_to_strategy() -> Dictionary:
	if phase != PHASE_RESULT:
		return _error("return to strategy is only available after settlement")
	phase = PHASE_STRATEGY
	_render_strategy_screen()
	return _ok()


func get_slice_summary() -> Dictionary:
	return {
		"phase": phase,
		"round": round_number,
		"selected_quest_id": selected_quest_id,
		"current_node_id": current_node_id,
		"warzones": warzones.duplicate(true),
		"completed_quest_ids": completed_quest_ids.duplicate(),
		"rank": rank_value,
		"earned_card_ids": earned_card_ids.duplicate(),
		"earned_skill_ids": earned_skill_ids.duplicate(),
		"battle_resolved": battle_resolved,
		"battle_outcome": battle_outcome,
		"reward_candidate_count": reward_candidates.size(),
		"latest_settlement": latest_settlement.duplicate(true)
	}


func get_warzone_pressure(front_id: String) -> int:
	for front in warzones:
		if str(front.get("id", "")) == front_id:
			return int(front.get("pressure", 0))
	return 0


func _build_static_layout() -> void:
	if _main_column != null:
		return

	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	margin.name = "ScreenMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	_main_column = VBoxContainer.new()
	_main_column.name = "MainColumn"
	_main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_column.add_theme_constant_override("separation", 10)
	margin.add_child(_main_column)

	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.add_theme_font_size_override("font_size", 24)
	_header_label.text = "Strategy Quest Prototype"
	_main_column.add_child(_header_label)

	_subheader_label = Label.new()
	_subheader_label.name = "Subheader"
	_subheader_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_column.add_child(_subheader_label)

	_content_root = VBoxContainer.new()
	_content_root.name = "Content"
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 8)
	_main_column.add_child(_content_root)


func _render_strategy_screen() -> void:
	_clear_content()
	_header_label.text = "Strategy"
	_subheader_label.text = "Round %s. Pick a quest while watching pressure across three fronts." % round_number

	var fronts := _row(_content_root)
	for front in warzones:
		var card := _panel(fronts)
		card.custom_minimum_size = Vector2(220, 92)
		_add_label(card, str(front.get("name", "")), 18)
		_add_label(card, "Pressure: %s" % front.get("pressure", 0), 15)
		_add_pressure_bar(card, int(front.get("pressure", 0)))

	_add_label(_content_root, "Available Quests", 18)
	var quest_row := _row(_content_root)
	for quest_id in _quest_ids_from_campaign():
		var quest := _definition("quests", quest_id)
		if quest.is_empty():
			continue
		var quest_card := _panel(quest_row)
		quest_card.custom_minimum_size = Vector2(300, 130)
		_add_label(quest_card, str(quest.get("name", quest_id)), 16)
		_add_wrapped_label(quest_card, str(quest.get("objective", "")))
		var button_text := "Completed"
		var disabled := true
		if not completed_quest_ids.has(quest_id):
			button_text = "Start Quest"
			disabled = false
		quest_card.add_child(_button(button_text, Callable(self, "start_quest_from_strategy").bind(quest_id), disabled))

	_render_reward_state(_content_root)


func _render_quest_screen() -> void:
	_clear_content()
	var node = _current_quest_node()
	_header_label.text = "Quest"
	_subheader_label.text = "%s: %s" % [selected_quest.get("name"), selected_quest.get("objective")]

	if node == null:
		_render_error("Quest node is missing.", [current_node_id])
		return

	var card := _panel(_content_root)
	_add_label(card, "Current Node: %s" % current_node_id, 18)
	_add_label(card, "Type: %s" % node.get("type"), 14)
	_add_wrapped_label(card, _node_consequence_summary(node))

	var next_ids := _node_next_ids(node)
	if next_ids.is_empty():
		_add_label(card, "Next: none", 14)
	else:
		_add_label(card, "Next: %s" % ", ".join(next_ids), 14)

	var action_text := "Advance"
	match str(node.get("type")):
		QuestNodeScript.TYPE_EVENT:
			action_text = "Resolve Event"
		QuestNodeScript.TYPE_BATTLE, QuestNodeScript.TYPE_ELITE, QuestNodeScript.TYPE_BOSS:
			action_text = "Open Formation"
		QuestNodeScript.TYPE_CHEST:
			action_text = "Open Reward Chest"
		QuestNodeScript.TYPE_RESULT:
			action_text = "Settle Quest"
	card.add_child(_button(action_text, Callable(self, "advance_quest_node")))

	_render_log(_content_root)


func _render_formation_screen() -> void:
	_clear_content()
	_header_label.text = "Formation"
	_subheader_label.text = "Three leaders are assigned for this vertical slice. Review shared HP, faction AT/HP, and available skills."

	var summary: Dictionary = formation_state.call("get_summary")
	var slots: Array = summary.get("leader_slots", [])
	var slot_row := _row(_content_root)
	for slot in slots:
		var slot_card := _panel(slot_row)
		slot_card.custom_minimum_size = Vector2(260, 130)
		var character_id := str(slot.get("character_id", ""))
		var character := _definition("characters", character_id)
		_add_label(slot_card, "Leader Slot %s" % (int(slot.get("slot_index", 0)) + 1), 16)
		_add_label(slot_card, str(character.get("name", character_id)), 15)
		_add_label(slot_card, "Faction: %s" % _faction_name(str(slot.get("faction_id", ""))), 13)
		_add_label(slot_card, "Bonus AT %s / HP %s" % [slot.get("leader_at_bonus", 0), slot.get("leader_hp_bonus", 0)], 13)

	var stats_row := _row(_content_root)
	var hp_card := _panel(stats_row)
	_add_label(hp_card, "Shared HP", 18)
	_add_label(hp_card, "%s" % summary.get("party_hp", 0), 22)

	var squad_card := _panel(stats_row)
	_add_label(squad_card, "Faction AT / HP", 18)
	var squads: Dictionary = summary.get("frontline_faction_squads", {})
	for faction_id in squads.keys():
		var squad: Dictionary = squads[faction_id]
		_add_label(
			squad_card,
			"%s: AT %s / HP %s" % [_faction_name(faction_id), squad.get("at", 0), squad.get("hp", 0)],
			13
		)

	var skill_card := _panel(_content_root)
	_add_label(skill_card, "Available Leader Skills", 18)
	for skill_id in summary.get("available_skill_ids", []):
		var skill := _definition("skills", str(skill_id))
		_add_wrapped_label(skill_card, "%s: %s" % [skill.get("name", skill_id), skill.get("description", "")])

	_content_root.add_child(_button("Start Battle", Callable(self, "start_combat_from_formation")))


func _render_combat_screen() -> void:
	_clear_content()
	_header_label.text = "Battle"
	_subheader_label.text = "Use AP to answer the previewed enemy intent with attack, defense, healing, or interrupt."

	if combat_state == null:
		_render_error("Combat state is missing.", [])
		return

	var snapshot: Dictionary = combat_state.call("get_snapshot")
	var top_row := _row(_content_root)
	var player_card := _panel(top_row)
	_add_label(player_card, "Shared HP", 18)
	_add_label(player_card, "%s / %s" % [snapshot.get("player_hp", 0), snapshot.get("player_max_hp", 0)], 17)
	_add_label(player_card, "Block: %s" % snapshot.get("player_block", 0), 13)
	_add_label(player_card, "AP: %s / %s" % [snapshot.get("player_ap", 0), snapshot.get("max_ap", 0)], 17)

	var enemy_card := _panel(top_row)
	_add_label(enemy_card, "Enemy Team", 18)
	_add_label(enemy_card, "HP: %s / %s" % [snapshot.get("enemy_hp", 0), snapshot.get("enemy_max_hp", 0)], 17)
	_add_label(enemy_card, "Block: %s" % snapshot.get("enemy_block", 0), 13)
	_add_label(enemy_card, "Turn: %s" % snapshot.get("turn_number", 0), 13)

	var intent_card := _panel(_content_root)
	_add_label(intent_card, "Enemy Preview", 18)
	var intents: Array = snapshot.get("enemy_intents", [])
	if intents.is_empty():
		_add_label(intent_card, "No intent previewed.", 13)
	for intent in intents:
		_add_wrapped_label(intent_card, _format_intent(intent))

	var leader_card := _panel(_content_root)
	_add_label(leader_card, "Leader Action Status", 18)
	var acted_ids: Array = snapshot.get("acted_leader_ids", [])
	for leader_id in formation_state.call("get_leader_character_ids"):
		var marker := "Ready"
		if acted_ids.has(leader_id):
			marker = "Acted"
		_add_label(leader_card, "%s: %s" % [_character_name(leader_id), marker], 13)

	var actions := _row(_content_root)
	for action_id in ["attack", "defend", "heal", "interrupt"]:
		var action := _combat_action(action_id)
		var disabled := battle_resolved or _is_action_disabled(action, snapshot)
		actions.add_child(_button(_action_button_label(action_id, action), Callable(self, "execute_combat_action").bind(action_id), disabled))
	actions.add_child(_button("End Turn", Callable(self, "end_player_turn"), battle_resolved))

	_render_status_summary(_content_root, snapshot)
	_render_log(_content_root, combat_state.call("get_action_log"))

	if battle_resolved:
		var outcome_text := "Battle resolved: %s" % battle_outcome
		_add_label(_content_root, outcome_text, 18)
		_content_root.add_child(_button("Continue", Callable(self, "continue_after_battle")))


func _render_reward_screen() -> void:
	_clear_content()
	_header_label.text = "Reward Chest"
	_subheader_label.text = "Choose one reward. Settlement will also show rank and catalog changes."

	var row := _row(_content_root)
	for index in range(reward_candidates.size()):
		var candidate: Dictionary = reward_candidates[index]
		var reward_card := _panel(row)
		reward_card.custom_minimum_size = Vector2(260, 120)
		_add_label(reward_card, "Choice %s" % (index + 1), 16)
		_add_label(reward_card, _reward_display_name(candidate), 15)
		_add_label(reward_card, "Type: %s" % candidate.get("kind", ""), 13)
		reward_card.add_child(_button("Choose", Callable(self, "choose_reward").bind(index)))


func _render_result_screen() -> void:
	_clear_content()
	_header_label.text = "Quest Settlement"
	_subheader_label.text = "Settlement applies visible reward and front pressure changes before returning to strategy."

	var result_card := _panel(_content_root)
	_add_label(result_card, "Quest Complete", 20)
	_add_label(result_card, "Outcome: %s" % latest_settlement.get("outcome", "victory"), 14)
	_add_label(result_card, "Rank: %s -> %s" % [latest_settlement.get("rank_before", 1), latest_settlement.get("rank_after", rank_value)], 14)
	_add_label(result_card, "Selected Reward: %s" % _reward_display_name(selected_reward), 14)
	_add_label(result_card, "Catalog Cards: %s" % _empty_label(earned_card_ids), 13)
	_add_label(result_card, "Catalog Skills: %s" % _empty_label(earned_skill_ids), 13)

	var pressure_card := _panel(_content_root)
	_add_label(pressure_card, "Front Pressure Change", 18)
	var changes: Array = latest_settlement.get("front_changes", [])
	for change in changes:
		_add_label(
			pressure_card,
			"%s: %s -> %s" % [change.get("name", ""), change.get("before", 0), change.get("after", 0)],
			14
		)

	_content_root.add_child(_button("Return to Strategy", Callable(self, "return_to_strategy")))


func _render_error(message: String, errors: Array) -> void:
	_clear_content()
	_header_label.text = "UI Slice Error"
	_subheader_label.text = message
	for error in errors:
		_add_wrapped_label(_content_root, str(error))


func _render_reward_state(parent: VBoxContainer) -> void:
	var state_card := _panel(parent)
	_add_label(state_card, "Reward State", 18)
	_add_label(state_card, "Unit Rank: %s" % rank_value, 14)
	_add_label(state_card, "Completed Quests: %s" % _empty_label(completed_quest_ids), 13)
	_add_label(state_card, "Catalog Cards: %s" % _empty_label(earned_card_ids), 13)
	_add_label(state_card, "Catalog Skills: %s" % _empty_label(earned_skill_ids), 13)


func _render_status_summary(parent: VBoxContainer, snapshot: Dictionary) -> void:
	var status_card := _panel(parent)
	_add_label(status_card, "Status Summary", 18)
	_add_label(status_card, "Player: %s" % _status_list(snapshot.get("player_statuses", [])), 13)
	_add_label(status_card, "Enemy: %s" % _status_list(snapshot.get("enemy_statuses", [])), 13)


func _render_log(parent: VBoxContainer, logs: Array = []) -> void:
	var log_card := _panel(parent)
	_add_label(log_card, "Log", 18)
	var rows := logs
	if rows.is_empty():
		rows = _log_lines
	var start_index: int = max(0, rows.size() - 8)
	for index in range(start_index, rows.size()):
		_add_wrapped_label(log_card, str(rows[index]))


func _build_collection_and_formation() -> void:
	var character_ids := []
	var campaign := _definition("campaigns", DEFAULT_CAMPAIGN_ID)
	for character_id in campaign.get("entry_character_ids", []):
		_add_unique(character_ids, str(character_id))
	for character_id in DEFAULT_LEADER_IDS:
		_add_unique(character_ids, str(character_id))

	collection_state = CollectionStateScript.new(content)
	collection_state.call("add_character_cards", character_ids)

	formation_state = FormationStateScript.new(collection_state)
	for index in range(DEFAULT_LEADER_IDS.size()):
		formation_state.call("set_leader", index, DEFAULT_LEADER_IDS[index])


func _prepare_reward_candidates() -> void:
	if not reward_candidates.is_empty():
		return
	var pool_id := str(selected_quest.get("reward_pool_id"))
	var pool_row := _definition("reward_pools", pool_id)
	if pool_row.is_empty():
		reward_candidates = []
		return
	var pool = RewardPoolDefinitionScript.new(pool_row)
	reward_candidates = pool.call("generate_candidates", 3, 23)


func _apply_settlement() -> void:
	if not latest_settlement.is_empty():
		return

	var front_changes := []
	var rank_before := rank_value
	var ash_before := get_warzone_pressure(ASH_ROAD_FRONT_ID)
	_adjust_warzone_pressure(ASH_ROAD_FRONT_ID, -2)
	var ash_after := get_warzone_pressure(ASH_ROAD_FRONT_ID)
	front_changes.append({"name": "Ash Road", "before": ash_before, "after": ash_after})

	rank_value += 1
	round_number += 1
	_add_unique(completed_quest_ids, selected_quest_id)
	latest_settlement = {
		"outcome": battle_outcome if not battle_outcome.is_empty() else "victory",
		"rank_before": rank_before,
		"rank_after": rank_value,
		"front_changes": front_changes,
		"reward": selected_reward.duplicate(true)
	}


func _collect_combat_result(result) -> void:
	var result_dictionary := _result_to_dictionary(result)
	if not bool(result_dictionary.get("ok", false)):
		_log_lines.append(str(result_dictionary.get("message", "combat action failed")))
		return
	var snapshot: Dictionary = result_dictionary.get("snapshot", {})
	var outcome := str(snapshot.get("outcome", CombatStateScript.OUTCOME_ONGOING))
	if outcome != CombatStateScript.OUTCOME_ONGOING:
		battle_resolved = true
		battle_outcome = outcome


func _combat_action(action_id: String) -> Dictionary:
	match action_id:
		"attack":
			return {
				"leader_id": "character.iris",
				"target_id": CombatStateScript.TARGET_ENEMY_TEAM,
				"skill": _card_skill("card.strike")
			}
		"defend":
			var guard := _card_skill("card.guard")
			var effects: Array = guard.get("effects", []).duplicate(true)
			for index in range(effects.size()):
				if typeof(effects[index]) == TYPE_DICTIONARY and str(effects[index].get("type", "")) == "block":
					effects[index]["intent_multiplier"] = 0.5
			guard["effects"] = effects
			return {
				"leader_id": "character.iris",
				"target_id": CombatStateScript.TARGET_PLAYER_TEAM,
				"skill": guard
			}
		"heal":
			return {
				"leader_id": "character.maelle",
				"target_id": CombatStateScript.TARGET_PLAYER_TEAM,
				"skill": _card_skill("card.first_aid")
			}
		"interrupt":
			var surge := _definition("skills", "skill.surge_control")
			return {
				"leader_id": "character.ren",
				"target_id": CombatStateScript.TARGET_ENEMY_TEAM,
				"skill": {
					"id": "skill.surge_control",
					"name": str(surge.get("name", "Surge Control")),
					"cost": 1,
					"target": "enemy",
					"effects": [
						{"type": "interrupt"},
						{"type": "damage", "amount": 3}
					]
				}
			}
	return {}


func _card_skill(card_id: String) -> Dictionary:
	var card := _definition("cards", card_id)
	if card.is_empty():
		return {}
	return {
		"id": card.get("id", card_id),
		"name": card.get("name", card_id),
		"cost": card.get("cost", 0),
		"target": card.get("target", ""),
		"effects": card.get("effects", []).duplicate(true)
	}


func _is_action_disabled(action: Dictionary, snapshot: Dictionary) -> bool:
	if action.is_empty():
		return true
	if str(snapshot.get("phase", "")) != CombatStateScript.PHASE_PLAYER_TURN:
		return true
	var acted_ids: Array = snapshot.get("acted_leader_ids", [])
	if acted_ids.has(str(action.get("leader_id", ""))):
		return true
	var skill: Dictionary = action.get("skill", {})
	return int(skill.get("cost", 0)) > int(snapshot.get("player_ap", 0))


func _action_button_label(action_id: String, action: Dictionary) -> String:
	var skill: Dictionary = action.get("skill", {})
	var leader_name := _character_name(str(action.get("leader_id", "")))
	return "%s: %s (%s AP)" % [leader_name, _capitalized(action_id), skill.get("cost", 0)]


func _current_quest_node():
	if selected_quest == null:
		return null
	return selected_quest.call("get_node", current_node_id)


func _node_next_ids(node) -> Array:
	var node_type := str(node.get("type"))
	if node_type == QuestNodeScript.TYPE_BRANCH:
		var ids := []
		for option in node.get("branch_options"):
			if typeof(option) == TYPE_DICTIONARY:
				ids.append(str(option.get("next_node_id", "")))
		return ids
	var next_id := str(node.get("next_node_id"))
	if next_id.is_empty():
		return []
	return [next_id]


func _node_consequence_summary(node) -> String:
	match str(node.get("type")):
		QuestNodeScript.TYPE_EVENT:
			return "Route event resolves and exposes the next quest node."
		QuestNodeScript.TYPE_BATTLE, QuestNodeScript.TYPE_ELITE, QuestNodeScript.TYPE_BOSS:
			var encounter := _definition("encounters", str(node.get("encounter_id")))
			return "Battle against %s. Victory opens the reward chest." % encounter.get("name", node.get("encounter_id"))
		QuestNodeScript.TYPE_CHEST:
			return "Choose one of three generated rewards before settlement."
		QuestNodeScript.TYPE_RESULT:
			return "Apply quest settlement, rank change, catalog changes, and front pressure impact."
	return "No special consequence in this slice."


func _result_node_id() -> String:
	if selected_quest != null and selected_quest.call("get_node", "result") != null:
		return "result"
	return current_node_id


func _quest_ids_from_campaign() -> Array:
	var campaign := _definition("campaigns", DEFAULT_CAMPAIGN_ID)
	for act in campaign.get("acts", []):
		if typeof(act) == TYPE_DICTIONARY and act.has("quest_ids"):
			return act.get("quest_ids", [])
	return [DEFAULT_QUEST_ID]


func _enemy_hp_for_encounter(encounter: Dictionary) -> int:
	var tier: int = max(1, int(encounter.get("tier", 1)))
	var wave_count := 0
	for wave in encounter.get("waves", []):
		if typeof(wave) == TYPE_DICTIONARY:
			wave_count += max(1, int(wave.get("count", 1)))
	return 8 + tier * 2 + wave_count * 2


func _combat_leaders_from_formation() -> Array:
	var leaders := []
	for character_id in formation_state.call("get_leader_character_ids"):
		leaders.append(
			{
				"id": str(character_id),
				"name": _character_name(str(character_id))
			}
		)
	return leaders


func _format_intent(intent: Dictionary) -> String:
	var canceled := ""
	if bool(intent.get("canceled", false)):
		canceled = " canceled"
	return "%s: %s strength %s%s, defendable %s, interruptible %s" % [
		intent.get("name", intent.get("id", "Intent")),
		intent.get("action_type", ""),
		intent.get("effective_strength", intent.get("strength", 0)),
		canceled,
		"yes" if bool(intent.get("defendable", false)) else "no",
		"yes" if bool(intent.get("interruptible", false)) else "no"
	]


func _status_list(statuses: Array) -> String:
	if statuses.is_empty():
		return "none"
	var names := []
	for status in statuses:
		if typeof(status) == TYPE_DICTIONARY:
			names.append("%s x%s" % [status.get("name", status.get("id", "status")), status.get("stacks", 1)])
	return ", ".join(names)


func _reward_display_name(reward: Dictionary) -> String:
	if reward.is_empty():
		return "None"
	var table_key := "cards"
	if str(reward.get("kind", "")) == "skill":
		table_key = "skills"
	var definition := _definition(table_key, str(reward.get("content_id", "")))
	return str(definition.get("name", reward.get("content_id", "Unknown Reward")))


func _definition(table_key: String, content_id: String) -> Dictionary:
	var table: Dictionary = indexes.get(table_key, {})
	if not table.has(content_id):
		return {}
	return table[content_id]


func _table_values(table_key: String) -> Array:
	var table: Dictionary = indexes.get(table_key, {})
	return table.values()


func _character_name(character_id: String) -> String:
	var character := _definition("characters", character_id)
	return str(character.get("name", character_id))


func _faction_name(faction_id: String) -> String:
	var faction := _definition("factions", faction_id)
	return str(faction.get("name", faction_id))


func _adjust_warzone_pressure(front_id: String, delta: int) -> void:
	for front in warzones:
		if str(front.get("id", "")) == front_id:
			front["pressure"] = clamp(int(front.get("pressure", 0)) + delta, 0, 10)
			return


func _clear_content() -> void:
	if _content_root == null:
		return
	for child in _content_root.get_children():
		_content_root.remove_child(child)
		child.free()


func _panel(parent: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	return column


func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _add_label(parent: Container, text: String, font_size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _add_wrapped_label(parent: Container, text: String) -> Label:
	var label := _add_label(parent, text, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_pressure_bar(parent: Container, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.value = value
	bar.custom_minimum_size = Vector2(180, 18)
	parent.add_child(bar)
	return bar


func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(128, 34)
	button.pressed.connect(callback)
	return button


func _empty_label(values: Array) -> String:
	if values.is_empty():
		return "none"
	var labels := []
	for value in values:
		labels.append(str(value))
	return ", ".join(labels)


func _capitalized(value: String) -> String:
	if value.is_empty():
		return value
	return value.substr(0, 1).to_upper() + value.substr(1)


func _add_unique(target: Array, value: String) -> void:
	if value.is_empty():
		return
	if not target.has(value):
		target.append(value)


func _result_to_dictionary(result) -> Dictionary:
	if result == null:
		return {"ok": false, "message": "missing result"}
	if result.has_method("to_dictionary"):
		return result.call("to_dictionary")
	if typeof(result) == TYPE_DICTIONARY:
		return result
	return {"ok": false, "message": "unsupported result"}


func _ok() -> Dictionary:
	return {"ok": true, "phase": phase}


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"phase": phase,
		"errors": [message],
		"message": message
	}
