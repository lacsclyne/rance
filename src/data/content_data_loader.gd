class_name ContentDataLoader
extends RefCounted

const DEFAULT_DATA_ROOT := "res://data"
const DEFAULT_ASSET_MANIFEST_PATH := "res://assets/asset_manifest.json"
const ID_PATTERN := "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$"
const COLOR_PATTERN := "^#[0-9A-Fa-f]{6}$"

const TABLES := [
	{
		"key": "factions",
		"file": "factions/factions.json",
		"array": "factions",
		"id_prefix": "faction."
	},
	{
		"key": "statuses",
		"file": "statuses/statuses.json",
		"array": "statuses",
		"id_prefix": "status."
	},
	{
		"key": "cards",
		"file": "cards/cards.json",
		"array": "cards",
		"id_prefix": "card."
	},
	{
		"key": "skills",
		"file": "skills/skills.json",
		"array": "skills",
		"id_prefix": "skill."
	},
	{
		"key": "characters",
		"file": "characters/characters.json",
		"array": "characters",
		"id_prefix": "character."
	},
	{
		"key": "enemies",
		"file": "enemies/enemies.json",
		"array": "enemies",
		"id_prefix": "enemy."
	},
	{
		"key": "reward_pools",
		"file": "reward_pools/reward_pools.json",
		"array": "reward_pools",
		"id_prefix": "reward_pool."
	},
	{
		"key": "encounters",
		"file": "encounters/encounters.json",
		"array": "encounters",
		"id_prefix": "encounter."
	},
	{
		"key": "progression_nodes",
		"file": "progression/progression.json",
		"array": "progression_nodes",
		"id_prefix": "progression."
	},
	{
		"key": "quests",
		"file": "quests/quests.json",
		"array": "quests",
		"id_prefix": "quest."
	},
	{
		"key": "campaigns",
		"file": "campaign/campaigns.json",
		"array": "campaigns",
		"id_prefix": "campaign."
	},
	{
		"key": "events",
		"file": "events/events.json",
		"array": "events",
		"id_prefix": "event."
	},
	{
		"key": "endings",
		"file": "endings/endings.json",
		"array": "endings",
		"id_prefix": "ending."
	}
]

const REQUIRED_FIELDS := {
	"factions": ["id", "name", "alignment", "color"],
	"statuses": [
		"id",
		"name",
		"polarity",
		"stack_rule",
		"default_duration",
		"description",
		"effect_type",
		"numeric_value",
		"tick_timing",
		"expire_timing"
	],
	"cards": ["id", "name", "type", "rarity", "cost", "target", "effects"],
	"skills": ["id", "name", "trigger", "description"],
	"characters": ["id", "name", "faction_id", "role", "base_stats", "starting_deck", "skill_ids"],
	"enemies": ["id", "name", "faction_id", "rank", "base_stats", "skill_ids"],
	"reward_pools": ["id", "name", "entries"],
	"encounters": ["id", "name", "tier", "waves", "reward_pool_id"],
	"progression_nodes": ["id", "name", "requires", "unlocks"],
	"quests": ["id", "name", "objective", "encounter_ids", "reward_pool_id"],
	"campaigns": ["id", "name", "entry_character_ids", "acts"],
	"events": ["id", "name", "campaign_id", "trigger", "presentation"],
	"endings": [
		"id",
		"name",
		"campaign_id",
		"priority",
		"requirements",
		"related_faction_ids",
		"related_character_ids",
		"discovery",
		"presentation"
	]
}

const ENUMS := {
	"alignment": ["ally", "neutral", "enemy"],
	"polarity": ["buff", "debuff"],
	"stack_rule": ["add", "replace", "intensity"],
	"status_effect_type": ["damage_over_time", "vulnerable", "weaken", "guard", "seal", "heal_block"],
	"status_timing": ["none", "turn_start", "turn_end"],
	"card_type": ["attack", "skill", "power"],
	"rarity": ["starter", "common", "uncommon", "rare"],
	"target": ["self", "ally", "enemy", "all_enemies"],
	"effect_type": ["damage", "block", "heal", "draw", "apply_status", "gain_energy"],
	"skill_trigger": ["battle_start", "turn_start", "card_played", "on_damage", "active"],
	"enemy_rank": ["minion", "elite", "boss"],
	"intent_action_type": ["attack", "big_attack", "charge", "buff", "debuff", "heal", "defense", "custom"],
	"intent_target_scope": ["player_team", "enemy_team", "self", "enemy", "all_enemies", "all_players"],
	"intent_condition_type": ["enemy_hp_at_or_below", "player_hp_at_or_below", "turn_at_least"],
	"reward_kind": ["card", "skill"],
	"unlock_kind": ["character", "card", "skill", "encounter", "quest"],
	"condition_mode": ["all", "any"],
	"faction_condition_state": ["allied", "neutral", "hostile", "destroyed"],
	"front_control": ["ally", "contested", "enemy"],
	"quest_condition_state": ["locked", "available", "active", "completed", "failed"],
	"character_condition_state": ["alive", "dead", "available", "unavailable"]
}

const KIND_TARGETS := {
	"character": "characters",
	"card": "cards",
	"skill": "skills",
	"encounter": "encounters",
	"quest": "quests"
}

const CONTENT_LABELS := {
	"factions": "faction",
	"statuses": "status",
	"cards": "card",
	"skills": "skill",
	"characters": "character",
	"enemies": "enemy",
	"reward_pools": "reward pool",
	"encounters": "encounter",
	"progression_nodes": "progression node",
	"quests": "quest",
	"campaigns": "campaign",
	"events": "event",
	"endings": "ending"
}

const ASSET_REFERENCE_FIELDS := {
	"factions": {"field": "icon_asset_id", "category": "faction_icon"},
	"cards": {"field": "card_art_asset_id", "category": "card_art"},
	"skills": {"field": "icon_asset_id", "category": "skill_icon"},
	"characters": {"field": "portrait_asset_id", "category": "portrait"},
	"encounters": {"field": "background_asset_id", "category": "encounter_background"}
}

func load_and_validate(data_root: String = DEFAULT_DATA_ROOT, asset_manifest_path: String = DEFAULT_ASSET_MANIFEST_PATH) -> Dictionary:
	var load_result := load_content(data_root)
	if not load_result["ok"]:
		return {
			"ok": false,
			"data": load_result["data"],
			"indexes": {},
			"errors": load_result["errors"]
		}

	return validate_content(load_result["data"], load_result["files"], asset_manifest_path)


func load_content(data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	var data := {}
	var files := {}
	var errors := []

	for table in TABLES:
		var table_key: String = table["key"]
		var file_path := _join_data_path(data_root, table["file"])
		files[table_key] = file_path

		if not FileAccess.file_exists(file_path):
			_add_error(errors, file_path, "<file>", "<file>", "missing data file")
			continue

		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			_add_error(
				errors,
				file_path,
				"<file>",
				"<file>",
				"could not open file, error %s" % FileAccess.get_open_error()
			)
			continue

		var text := file.get_as_text()
		var json := JSON.new()
		var parse_error := json.parse(text)
		if parse_error != OK:
			_add_error(
				errors,
				file_path,
				"<json>",
				"<json>",
				"parse error at line %s: %s" % [json.get_error_line(), json.get_error_message()]
			)
			continue

		if typeof(json.data) != TYPE_DICTIONARY:
			_add_error(errors, file_path, "<file>", "<root>", "expected JSON object")
			continue

		data[table_key] = json.data

	return {
		"ok": errors.is_empty(),
		"data": data,
		"files": files,
		"errors": errors
	}


func validate_content(content: Dictionary, files: Dictionary = {}, asset_manifest_path: String = DEFAULT_ASSET_MANIFEST_PATH) -> Dictionary:
	var errors := []
	var indexes := {}
	var all_ids := {}

	for table in TABLES:
		indexes[table["key"]] = {}
		_validate_collection_shape(table, content, files, indexes, all_ids, errors)

	var asset_manifest := {
		"ok": true,
		"asset_categories": {},
		"errors": []
	}
	if _has_asset_references(content):
		asset_manifest = _load_asset_manifest_categories(asset_manifest_path)
		if not asset_manifest["ok"]:
			errors.append_array(asset_manifest["errors"])

	_validate_references(
		content,
		files,
		indexes,
		asset_manifest["asset_categories"],
		asset_manifest["ok"],
		errors
	)

	return {
		"ok": errors.is_empty(),
		"data": content,
		"indexes": indexes,
		"errors": errors
	}


func count_records(validated_content: Dictionary) -> int:
	var total := 0
	var indexes: Dictionary = validated_content.get("indexes", {})
	for table_key in indexes.keys():
		total += indexes[table_key].size()
	return total


func _validate_collection_shape(
	table: Dictionary,
	content: Dictionary,
	files: Dictionary,
	indexes: Dictionary,
	all_ids: Dictionary,
	errors: Array
) -> void:
	var table_key: String = table["key"]
	var array_key: String = table["array"]
	var file_path: String = files.get(table_key, _join_data_path(DEFAULT_DATA_ROOT, table["file"]))

	if not content.has(table_key):
		return

	var document = content[table_key]
	if typeof(document) != TYPE_DICTIONARY:
		_add_error(errors, file_path, "<file>", "<root>", "expected JSON object")
		return

	_require_fields(document, ["version", array_key], file_path, "<file>", "", errors)
	if document.has("version"):
		_validate_integer_min_value(document["version"], file_path, "<file>", "version", 1, errors)

	if not document.has(array_key):
		return

	var rows = document[array_key]
	if typeof(rows) != TYPE_ARRAY:
		_add_error(errors, file_path, "<file>", array_key, "expected array")
		return

	for row_index in range(rows.size()):
		var row = rows[row_index]
		var row_id := _row_label(row, row_index)
		var row_path := "%s[%s]" % [array_key, row_index]

		if typeof(row) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, row_path, "expected object")
			continue

		_require_fields(row, REQUIRED_FIELDS[table_key], file_path, row_id, "", errors)
		_validate_row_id(row, table, file_path, row_id, row_index, indexes, all_ids, errors)
		_validate_row_shape(table_key, row, file_path, _row_label(row, row_index), errors)


func _validate_row_id(
	row: Dictionary,
	table: Dictionary,
	file_path: String,
	row_id: String,
	row_index: int,
	indexes: Dictionary,
	all_ids: Dictionary,
	errors: Array
) -> void:
	if not row.has("id"):
		return

	var table_key: String = table["key"]
	var value = row["id"]
	if typeof(value) != TYPE_STRING:
		_add_error(errors, file_path, row_id, "id", "expected string")
		return

	var id := str(value)
	if id.is_empty():
		_add_error(errors, file_path, row_id, "id", "must not be empty")
		return

	if not _matches_regex(id, ID_PATTERN):
		_add_error(errors, file_path, id, "id", "must match <kind>.<name> lowercase ID format")

	var expected_prefix: String = table["id_prefix"]
	if not id.begins_with(expected_prefix):
		_add_error(errors, file_path, id, "id", "must start with '%s'" % expected_prefix)

	if indexes[table_key].has(id):
		_add_error(errors, file_path, id, "id", "duplicate ID in %s" % table["array"])
	else:
		indexes[table_key][id] = row

	if all_ids.has(id):
		_add_error(errors, file_path, id, "id", "duplicate ID also appears in %s" % all_ids[id])
	else:
		all_ids[id] = _display_path(file_path)


func _validate_row_shape(table_key: String, row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	match table_key:
		"factions":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_enum(row, file_path, row_id, "alignment", ENUMS["alignment"], errors)
			_validate_regex_field(row, file_path, row_id, "color", COLOR_PATTERN, "expected #RRGGBB hex color", errors)
			_validate_optional_string(row, file_path, row_id, "summary", errors)
		"statuses":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_enum(row, file_path, row_id, "polarity", ENUMS["polarity"], errors)
			_validate_enum(row, file_path, row_id, "stack_rule", ENUMS["stack_rule"], errors)
			_validate_integer_min_field(row, file_path, row_id, "default_duration", 0, errors)
			_validate_non_empty_string(row, file_path, row_id, "description", errors)
			_validate_enum(row, file_path, row_id, "effect_type", ENUMS["status_effect_type"], errors)
			_validate_integer_min_field(row, file_path, row_id, "numeric_value", 0, errors)
			_validate_enum(row, file_path, row_id, "tick_timing", ENUMS["status_timing"], errors)
			_validate_enum(row, file_path, row_id, "expire_timing", ENUMS["status_timing"], errors)
		"cards":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_enum(row, file_path, row_id, "type", ENUMS["card_type"], errors)
			_validate_enum(row, file_path, row_id, "rarity", ENUMS["rarity"], errors)
			_validate_integer_min_field(row, file_path, row_id, "cost", 0, errors)
			_validate_enum(row, file_path, row_id, "target", ENUMS["target"], errors)
			_validate_string_array(row, file_path, row_id, "tags", errors, true)
			_validate_card_effects(row, file_path, row_id, errors)
		"skills":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_enum(row, file_path, row_id, "trigger", ENUMS["skill_trigger"], errors)
			_validate_non_empty_string(row, file_path, row_id, "description", errors)
			_validate_string_array(row, file_path, row_id, "status_ids", errors, true)
			_validate_optional_integer(row, file_path, row_id, "numeric_value", errors)
		"characters":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_non_empty_string(row, file_path, row_id, "role", errors)
			_validate_stats(row, file_path, row_id, "base_stats", errors)
			_validate_string_array(row, file_path, row_id, "starting_deck", errors, false)
			_validate_string_array(row, file_path, row_id, "skill_ids", errors, false)
			_validate_optional_string(row, file_path, row_id, "bio", errors)
		"enemies":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_enum(row, file_path, row_id, "rank", ENUMS["enemy_rank"], errors)
			_validate_stats(row, file_path, row_id, "base_stats", errors)
			_validate_string_array(row, file_path, row_id, "skill_ids", errors, false)
			_validate_optional_string(row, file_path, row_id, "intent_notes", errors)
		"reward_pools":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_reward_entries(row, file_path, row_id, errors)
		"encounters":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_integer_min_field(row, file_path, row_id, "tier", 1, errors)
			_validate_waves(row, file_path, row_id, errors)
			_validate_optional_string(row, file_path, row_id, "environment", errors)
			_validate_intent_pattern(row, file_path, row_id, errors)
		"progression_nodes":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_string_array(row, file_path, row_id, "requires", errors, false)
			_validate_unlocks(row, file_path, row_id, errors)
		"quests":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_non_empty_string(row, file_path, row_id, "objective", errors)
			_validate_string_array(row, file_path, row_id, "encounter_ids", errors, false)
		"campaigns":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			_validate_optional_string(row, file_path, row_id, "summary", errors)
			_validate_string_array(row, file_path, row_id, "entry_character_ids", errors, false)
			_validate_acts(row, file_path, row_id, errors)
		"events":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			if row.has("campaign_id"):
				_validate_string_value(row["campaign_id"], file_path, row_id, "campaign_id", errors)
			_validate_optional_string(row, file_path, row_id, "summary", errors)
			_validate_event_trigger(row, file_path, row_id, errors)
			_validate_event_effects(row, file_path, row_id, errors)
			_validate_presentation(row, file_path, row_id, "presentation", ["title", "body"], [], errors)
		"endings":
			_validate_non_empty_string(row, file_path, row_id, "name", errors)
			if row.has("campaign_id"):
				_validate_string_value(row["campaign_id"], file_path, row_id, "campaign_id", errors)
			_validate_integer_min_field(row, file_path, row_id, "priority", 0, errors)
			_validate_optional_string(row, file_path, row_id, "exclusive_group", errors)
			_validate_string_array(row, file_path, row_id, "related_faction_ids", errors, false)
			_validate_string_array(row, file_path, row_id, "related_character_ids", errors, false)
			_validate_ending_requirements(row, file_path, row_id, errors)
			_validate_ending_discovery(row, file_path, row_id, errors)
			_validate_presentation(row, file_path, row_id, "presentation", ["title", "body"], ["subtitle"], errors)

	if ASSET_REFERENCE_FIELDS.has(table_key):
		_validate_optional_string(row, file_path, row_id, ASSET_REFERENCE_FIELDS[table_key]["field"], errors)


func _validate_card_effects(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	var effects := _get_array(row, file_path, row_id, "effects", errors)
	for index in range(effects.size()):
		var effect = effects[index]
		var field_path := "effects[%s]" % index
		if typeof(effect) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, field_path, "expected object")
			continue

		_require_fields(effect, ["type"], file_path, row_id, field_path, errors)
		_validate_enum_value(effect.get("type"), file_path, row_id, "%s.type" % field_path, ENUMS["effect_type"], errors)
		if effect.get("type") == "apply_status":
			_require_fields(effect, ["status_id"], file_path, row_id, field_path, errors)

		if effect.has("status_id"):
			_validate_string_value(effect["status_id"], file_path, row_id, "%s.status_id" % field_path, errors)
		if effect.has("amount"):
			_validate_integer_min_value(effect["amount"], file_path, row_id, "%s.amount" % field_path, 0, errors)
		if effect.has("duration"):
			_validate_integer_min_value(effect["duration"], file_path, row_id, "%s.duration" % field_path, 1, errors)


func _validate_stats(row: Dictionary, file_path: String, row_id: String, field: String, errors: Array) -> void:
	if not row.has(field):
		return

	var stats = row[field]
	if typeof(stats) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, field, "expected object")
		return

	_require_fields(stats, ["hp", "attack", "defense", "speed"], file_path, row_id, field, errors)
	_validate_integer_min_value(stats.get("hp"), file_path, row_id, "%s.hp" % field, 1, errors)
	_validate_integer_min_value(stats.get("attack"), file_path, row_id, "%s.attack" % field, 0, errors)
	_validate_integer_min_value(stats.get("defense"), file_path, row_id, "%s.defense" % field, 0, errors)
	_validate_integer_min_value(stats.get("speed"), file_path, row_id, "%s.speed" % field, 0, errors)


func _validate_reward_entries(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	var entries := _get_array(row, file_path, row_id, "entries", errors)
	for index in range(entries.size()):
		var entry = entries[index]
		var field_path := "entries[%s]" % index
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, field_path, "expected object")
			continue

		_require_fields(entry, ["kind", "content_id", "weight"], file_path, row_id, field_path, errors)
		_validate_enum_value(entry.get("kind"), file_path, row_id, "%s.kind" % field_path, ENUMS["reward_kind"], errors)
		_validate_string_value(entry.get("content_id"), file_path, row_id, "%s.content_id" % field_path, errors)
		_validate_integer_min_value(entry.get("weight"), file_path, row_id, "%s.weight" % field_path, 1, errors)


func _validate_waves(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	var waves := _get_array(row, file_path, row_id, "waves", errors)
	for index in range(waves.size()):
		var wave = waves[index]
		var field_path := "waves[%s]" % index
		if typeof(wave) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, field_path, "expected object")
			continue

		_require_fields(wave, ["enemy_id", "count"], file_path, row_id, field_path, errors)
		_validate_string_value(wave.get("enemy_id"), file_path, row_id, "%s.enemy_id" % field_path, errors)
		_validate_integer_min_value(wave.get("count"), file_path, row_id, "%s.count" % field_path, 1, errors)


func _validate_intent_pattern(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	if not row.has("intent_pattern"):
		return

	var pattern = row["intent_pattern"]
	if typeof(pattern) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, "intent_pattern", "expected object")
		return

	if pattern.has("rotation"):
		_validate_intent_entries(pattern["rotation"], file_path, row_id, "intent_pattern.rotation", errors)

	if pattern.has("conditional"):
		var conditional = pattern["conditional"]
		if typeof(conditional) != TYPE_ARRAY:
			_add_error(errors, file_path, row_id, "intent_pattern.conditional", "expected array")
		else:
			for index in range(conditional.size()):
				var entry = conditional[index]
				var field_path := "intent_pattern.conditional[%s]" % index
				if typeof(entry) != TYPE_DICTIONARY:
					_add_error(errors, file_path, row_id, field_path, "expected object")
					continue
				_require_fields(entry, ["condition", "intents"], file_path, row_id, field_path, errors)
				if entry.has("condition"):
					_validate_intent_condition(entry["condition"], file_path, row_id, "%s.condition" % field_path, errors)
				if entry.has("intents"):
					_validate_intent_entries(entry["intents"], file_path, row_id, "%s.intents" % field_path, errors)

	if pattern.has("key_turns"):
		var key_turns = pattern["key_turns"]
		if typeof(key_turns) != TYPE_ARRAY:
			_add_error(errors, file_path, row_id, "intent_pattern.key_turns", "expected array")
		else:
			for index in range(key_turns.size()):
				var entry = key_turns[index]
				var field_path := "intent_pattern.key_turns[%s]" % index
				if typeof(entry) != TYPE_DICTIONARY:
					_add_error(errors, file_path, row_id, field_path, "expected object")
					continue
				_require_fields(entry, ["turn", "intents"], file_path, row_id, field_path, errors)
				if entry.has("turn"):
					_validate_integer_min_value(entry["turn"], file_path, row_id, "%s.turn" % field_path, 1, errors)
				if entry.has("intents"):
					_validate_intent_entries(entry["intents"], file_path, row_id, "%s.intents" % field_path, errors)


func _validate_intent_entries(value, file_path: String, row_id: String, field_path: String, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field_path, "expected array")
		return

	for index in range(value.size()):
		var entry = value[index]
		var entry_path := "%s[%s]" % [field_path, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, entry_path, "expected object")
			continue
		if entry.has("intents"):
			_validate_intent_entries(entry["intents"], file_path, row_id, "%s.intents" % entry_path, errors)
		else:
			_validate_intent_token(entry, file_path, row_id, entry_path, errors)


func _validate_intent_token(token: Dictionary, file_path: String, row_id: String, field_path: String, errors: Array) -> void:
	_require_fields(
		token,
		["id", "name", "action_type", "strength", "target_scope", "defendable", "interruptible"],
		file_path,
		row_id,
		field_path,
		errors
	)
	if token.has("id"):
		_validate_string_value(token["id"], file_path, row_id, "%s.id" % field_path, errors)
		if typeof(token["id"]) == TYPE_STRING and not _matches_regex(str(token["id"]), ID_PATTERN):
			_add_error(errors, file_path, row_id, "%s.id" % field_path, "must match <kind>.<name> lowercase ID format")
	if token.has("name"):
		_validate_non_empty_string(token, file_path, row_id, "name", errors, field_path)
	if token.has("action_type"):
		_validate_enum_value(token["action_type"], file_path, row_id, "%s.action_type" % field_path, ENUMS["intent_action_type"], errors)
	if token.has("strength"):
		_validate_integer_min_value(token["strength"], file_path, row_id, "%s.strength" % field_path, 0, errors)
	if token.has("target_scope"):
		_validate_enum_value(token["target_scope"], file_path, row_id, "%s.target_scope" % field_path, ENUMS["intent_target_scope"], errors)
	if token.has("defendable"):
		_validate_bool_value(token["defendable"], file_path, row_id, "%s.defendable" % field_path, errors)
	if token.has("interruptible"):
		_validate_bool_value(token["interruptible"], file_path, row_id, "%s.interruptible" % field_path, errors)
	if token.has("source_id"):
		_validate_string_value(token["source_id"], file_path, row_id, "%s.source_id" % field_path, errors)
	if token.has("effects"):
		_validate_intent_effects(token["effects"], file_path, row_id, "%s.effects" % field_path, errors)


func _validate_intent_effects(value, file_path: String, row_id: String, field_path: String, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field_path, "expected array")
		return

	for index in range(value.size()):
		var effect = value[index]
		var effect_path := "%s[%s]" % [field_path, index]
		if typeof(effect) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, effect_path, "expected object")
			continue
		_require_fields(effect, ["type"], file_path, row_id, effect_path, errors)
		if effect.has("type"):
			_validate_string_value(effect["type"], file_path, row_id, "%s.type" % effect_path, errors)
		if effect.has("amount"):
			_validate_integer_min_value(effect["amount"], file_path, row_id, "%s.amount" % effect_path, 0, errors)
		if effect.has("duration"):
			_validate_integer_min_value(effect["duration"], file_path, row_id, "%s.duration" % effect_path, 1, errors)
		if effect.has("target"):
			_validate_string_value(effect["target"], file_path, row_id, "%s.target" % effect_path, errors)
		if effect.has("status_id"):
			_validate_string_value(effect["status_id"], file_path, row_id, "%s.status_id" % effect_path, errors)


func _validate_intent_condition(condition, file_path: String, row_id: String, field_path: String, errors: Array) -> void:
	if typeof(condition) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, field_path, "expected object")
		return

	_require_fields(condition, ["type"], file_path, row_id, field_path, errors)
	if condition.has("type"):
		_validate_enum_value(condition["type"], file_path, row_id, "%s.type" % field_path, ENUMS["intent_condition_type"], errors)
	if condition.has("value"):
		_validate_integer_min_value(condition["value"], file_path, row_id, "%s.value" % field_path, 0, errors)
	if condition.has("amount"):
		_validate_integer_min_value(condition["amount"], file_path, row_id, "%s.amount" % field_path, 0, errors)
	if condition.has("percent"):
		_validate_number_min_value(condition["percent"], file_path, row_id, "%s.percent" % field_path, 0.0, errors)
	if condition.has("turn"):
		_validate_integer_min_value(condition["turn"], file_path, row_id, "%s.turn" % field_path, 1, errors)


func _validate_unlocks(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	var unlocks := _get_array(row, file_path, row_id, "unlocks", errors)
	for index in range(unlocks.size()):
		var unlock = unlocks[index]
		var field_path := "unlocks[%s]" % index
		if typeof(unlock) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, field_path, "expected object")
			continue

		_require_fields(unlock, ["kind", "content_id"], file_path, row_id, field_path, errors)
		_validate_enum_value(unlock.get("kind"), file_path, row_id, "%s.kind" % field_path, ENUMS["unlock_kind"], errors)
		_validate_string_value(unlock.get("content_id"), file_path, row_id, "%s.content_id" % field_path, errors)


func _validate_acts(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	var acts := _get_array(row, file_path, row_id, "acts", errors)
	var act_ids := {}

	for index in range(acts.size()):
		var act = acts[index]
		var field_path := "acts[%s]" % index
		if typeof(act) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, field_path, "expected object")
			continue

		_require_fields(act, ["id", "name", "encounter_ids", "quest_ids"], file_path, row_id, field_path, errors)
		if act.has("id"):
			_validate_string_value(act["id"], file_path, row_id, "%s.id" % field_path, errors)
			if typeof(act["id"]) == TYPE_STRING:
				var act_id := str(act["id"])
				if not _matches_regex(act_id, ID_PATTERN):
					_add_error(errors, file_path, row_id, "%s.id" % field_path, "must match <kind>.<name> lowercase ID format")
				if not act_id.begins_with("act."):
					_add_error(errors, file_path, row_id, "%s.id" % field_path, "must start with 'act.'")
				if act_ids.has(act_id):
					_add_error(errors, file_path, row_id, "%s.id" % field_path, "duplicate act ID '%s'" % act_id)
				else:
					act_ids[act_id] = true

		_validate_non_empty_string(act, file_path, row_id, "name", errors, field_path)
		_validate_string_array(act, file_path, row_id, "encounter_ids", errors, false, field_path)
		_validate_string_array(act, file_path, row_id, "quest_ids", errors, false, field_path)
		if act.has("progression_gate_id"):
			_validate_string_value(act["progression_gate_id"], file_path, row_id, "%s.progression_gate_id" % field_path, errors)


func _validate_event_trigger(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	if not row.has("trigger"):
		return

	var trigger = row["trigger"]
	if typeof(trigger) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, "trigger", "expected object")
		return

	if trigger.has("mode"):
		_validate_enum_value(trigger["mode"], file_path, row_id, "trigger.mode", ENUMS["condition_mode"], errors)
	if trigger.has("turn"):
		_validate_turn_condition(trigger["turn"], file_path, row_id, "trigger.turn", errors)

	_validate_faction_conditions(trigger, file_path, row_id, "faction_state", "trigger", errors)
	_validate_front_conditions(trigger, file_path, row_id, "front_state", "trigger", errors)
	_validate_quest_conditions(trigger, file_path, row_id, "quest_state", "trigger", errors)
	_validate_character_conditions(trigger, file_path, row_id, "character_state", "trigger", errors)
	_validate_prefixed_id_array(trigger, file_path, row_id, "required_flags", "flag.", errors, "trigger")
	_validate_prefixed_id_array(trigger, file_path, row_id, "blocked_flags", "flag.", errors, "trigger")


func _validate_event_effects(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	if not row.has("effects"):
		return

	var effects = row["effects"]
	if typeof(effects) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, "effects", "expected object")
		return

	_validate_prefixed_id_array(effects, file_path, row_id, "set_flags", "flag.", errors, "effects")
	_validate_prefixed_id_array(effects, file_path, row_id, "clear_flags", "flag.", errors, "effects")
	_validate_string_array(effects, file_path, row_id, "available_quest_ids", errors, true, "effects")
	_validate_string_array(effects, file_path, row_id, "unlock_progression_ids", errors, true, "effects")


func _validate_ending_requirements(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	if not row.has("requirements"):
		return

	var requirements = row["requirements"]
	if typeof(requirements) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, "requirements", "expected object")
		return

	if requirements.has("mode"):
		_validate_enum_value(requirements["mode"], file_path, row_id, "requirements.mode", ENUMS["condition_mode"], errors)
	_validate_string_array(requirements, file_path, row_id, "completed_quest_ids", errors, true, "requirements")
	_validate_string_array(requirements, file_path, row_id, "failed_quest_ids", errors, true, "requirements")
	_validate_string_array(requirements, file_path, row_id, "required_progression_ids", errors, true, "requirements")
	_validate_string_array(requirements, file_path, row_id, "blocked_progression_ids", errors, true, "requirements")
	_validate_prefixed_id_array(requirements, file_path, row_id, "required_flags", "flag.", errors, "requirements")
	_validate_prefixed_id_array(requirements, file_path, row_id, "blocked_flags", "flag.", errors, "requirements")
	_validate_character_conditions(requirements, file_path, row_id, "character_state", "requirements", errors)
	_validate_faction_conditions(requirements, file_path, row_id, "faction_state", "requirements", errors)


func _validate_ending_discovery(row: Dictionary, file_path: String, row_id: String, errors: Array) -> void:
	if not row.has("discovery"):
		return

	var discovery = row["discovery"]
	if typeof(discovery) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, "discovery", "expected object")
		return

	_validate_prefixed_id_array(discovery, file_path, row_id, "set_flags", "flag.", errors, "discovery")
	_validate_string_array(discovery, file_path, row_id, "carryover_progression_ids", errors, true, "discovery")
	if discovery.has("notes"):
		_validate_string_value(discovery["notes"], file_path, row_id, "discovery.notes", errors)


func _validate_presentation(
	row: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	required_fields: Array,
	optional_fields: Array,
	errors: Array
) -> void:
	if not row.has(field):
		return

	var presentation = row[field]
	if typeof(presentation) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, field, "expected object")
		return

	_require_fields(presentation, required_fields, file_path, row_id, field, errors)
	for text_field in required_fields:
		if presentation.has(text_field):
			_validate_non_empty_string(presentation, file_path, row_id, str(text_field), errors, field)
	for text_field in optional_fields:
		if presentation.has(text_field):
			_validate_string_value(presentation[text_field], file_path, row_id, "%s.%s" % [field, text_field], errors)
	for id_field in ["art_id", "music_id"]:
		if presentation.has(id_field):
			_validate_string_value(presentation[id_field], file_path, row_id, "%s.%s" % [field, id_field], errors)


func _validate_turn_condition(value, file_path: String, row_id: String, field_path: String, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add_error(errors, file_path, row_id, field_path, "expected object")
		return
	for int_field in ["at", "at_least", "before", "deadline_turn"]:
		if value.has(int_field):
			_validate_integer_min_value(value[int_field], file_path, row_id, "%s.%s" % [field_path, int_field], 1, errors)


func _validate_faction_conditions(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	prefix: String,
	errors: Array
) -> void:
	var entries := _get_array_with_prefix(target, file_path, row_id, field, prefix, errors)
	for index in range(entries.size()):
		var entry = entries[index]
		var entry_path := "%s.%s[%s]" % [prefix, field, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, entry_path, "expected object")
			continue
		_require_fields(entry, ["faction_id"], file_path, row_id, entry_path, errors)
		if entry.has("faction_id"):
			_validate_string_value(entry["faction_id"], file_path, row_id, "%s.faction_id" % entry_path, errors)
		if entry.has("state"):
			_validate_enum_value(entry["state"], file_path, row_id, "%s.state" % entry_path, ENUMS["faction_condition_state"], errors)
		for int_field in ["standing_at_least", "standing_at_most"]:
			if entry.has(int_field) and not _is_integer_value(entry[int_field]):
				_add_error(errors, file_path, row_id, "%s.%s" % [entry_path, int_field], "expected integer")


func _validate_front_conditions(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	prefix: String,
	errors: Array
) -> void:
	var entries := _get_array_with_prefix(target, file_path, row_id, field, prefix, errors)
	for index in range(entries.size()):
		var entry = entries[index]
		var entry_path := "%s.%s[%s]" % [prefix, field, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, entry_path, "expected object")
			continue
		_require_fields(entry, ["front_id"], file_path, row_id, entry_path, errors)
		if entry.has("front_id"):
			_validate_prefixed_id_value(entry["front_id"], file_path, row_id, "%s.front_id" % entry_path, "front.", errors)
		if entry.has("control"):
			_validate_enum_value(entry["control"], file_path, row_id, "%s.control" % entry_path, ENUMS["front_control"], errors)
		for int_field in ["pressure_at_least", "pressure_at_most"]:
			if entry.has(int_field):
				_validate_integer_min_value(entry[int_field], file_path, row_id, "%s.%s" % [entry_path, int_field], 0, errors)
		if entry.has("deadline_turn"):
			_validate_integer_min_value(entry["deadline_turn"], file_path, row_id, "%s.deadline_turn" % entry_path, 1, errors)


func _validate_quest_conditions(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	prefix: String,
	errors: Array
) -> void:
	var entries := _get_array_with_prefix(target, file_path, row_id, field, prefix, errors)
	for index in range(entries.size()):
		var entry = entries[index]
		var entry_path := "%s.%s[%s]" % [prefix, field, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, entry_path, "expected object")
			continue
		_require_fields(entry, ["quest_id", "state"], file_path, row_id, entry_path, errors)
		if entry.has("quest_id"):
			_validate_string_value(entry["quest_id"], file_path, row_id, "%s.quest_id" % entry_path, errors)
		if entry.has("state"):
			_validate_enum_value(entry["state"], file_path, row_id, "%s.state" % entry_path, ENUMS["quest_condition_state"], errors)


func _validate_character_conditions(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	prefix: String,
	errors: Array
) -> void:
	var entries := _get_array_with_prefix(target, file_path, row_id, field, prefix, errors)
	for index in range(entries.size()):
		var entry = entries[index]
		var entry_path := "%s.%s[%s]" % [prefix, field, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_add_error(errors, file_path, row_id, entry_path, "expected object")
			continue
		_require_fields(entry, ["character_id", "state"], file_path, row_id, entry_path, errors)
		if entry.has("character_id"):
			_validate_string_value(entry["character_id"], file_path, row_id, "%s.character_id" % entry_path, errors)
		if entry.has("state"):
			_validate_enum_value(entry["state"], file_path, row_id, "%s.state" % entry_path, ENUMS["character_condition_state"], errors)


func _validate_references(
	content: Dictionary,
	files: Dictionary,
	indexes: Dictionary,
	asset_categories: Dictionary,
	asset_manifest_loaded: bool,
	errors: Array
) -> void:
	_validate_asset_references(content, files, asset_categories, asset_manifest_loaded, errors)

	for row in _rows(content, "cards"):
		var file_path := _file_for(files, "cards")
		var row_id := _row_label(row, 0)
		for index in range(_array_or_empty(row, "effects").size()):
			var effect = row["effects"][index]
			if typeof(effect) == TYPE_DICTIONARY and effect.has("status_id"):
				_validate_ref_value(effect["status_id"], file_path, row_id, "effects[%s].status_id" % index, "statuses", indexes, errors)

	for row in _rows(content, "skills"):
		_validate_ref_array(row, _file_for(files, "skills"), _row_label(row, 0), "status_ids", "statuses", indexes, errors)

	for row in _rows(content, "characters"):
		var file_path := _file_for(files, "characters")
		var row_id := _row_label(row, 0)
		_validate_ref_field(row, file_path, row_id, "faction_id", "factions", indexes, errors)
		_validate_ref_array(row, file_path, row_id, "starting_deck", "cards", indexes, errors)
		_validate_ref_array(row, file_path, row_id, "skill_ids", "skills", indexes, errors)

	for row in _rows(content, "enemies"):
		var file_path := _file_for(files, "enemies")
		var row_id := _row_label(row, 0)
		_validate_ref_field(row, file_path, row_id, "faction_id", "factions", indexes, errors)
		_validate_ref_array(row, file_path, row_id, "skill_ids", "skills", indexes, errors)

	for row in _rows(content, "reward_pools"):
		var file_path := _file_for(files, "reward_pools")
		var row_id := _row_label(row, 0)
		for index in range(_array_or_empty(row, "entries").size()):
			var entry = row["entries"][index]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var kind = entry.get("kind")
			var target_key := ""
			if kind == "card":
				target_key = "cards"
			elif kind == "skill":
				target_key = "skills"
			if not target_key.is_empty() and entry.has("content_id"):
				_validate_ref_value(entry["content_id"], file_path, row_id, "entries[%s].content_id" % index, target_key, indexes, errors)

	for row in _rows(content, "encounters"):
		var file_path := _file_for(files, "encounters")
		var row_id := _row_label(row, 0)
		_validate_ref_field(row, file_path, row_id, "reward_pool_id", "reward_pools", indexes, errors)
		for index in range(_array_or_empty(row, "waves").size()):
			var wave = row["waves"][index]
			if typeof(wave) == TYPE_DICTIONARY and wave.has("enemy_id"):
				_validate_ref_value(wave["enemy_id"], file_path, row_id, "waves[%s].enemy_id" % index, "enemies", indexes, errors)

	for row in _rows(content, "progression_nodes"):
		var file_path := _file_for(files, "progression_nodes")
		var row_id := _row_label(row, 0)
		_validate_ref_array(row, file_path, row_id, "requires", "progression_nodes", indexes, errors)
		for index in range(_array_or_empty(row, "unlocks").size()):
			var unlock = row["unlocks"][index]
			if typeof(unlock) != TYPE_DICTIONARY:
				continue
			var kind = unlock.get("kind")
			if typeof(kind) == TYPE_STRING and KIND_TARGETS.has(kind) and unlock.has("content_id"):
				_validate_ref_value(unlock["content_id"], file_path, row_id, "unlocks[%s].content_id" % index, KIND_TARGETS[kind], indexes, errors)

	for row in _rows(content, "quests"):
		var file_path := _file_for(files, "quests")
		var row_id := _row_label(row, 0)
		_validate_ref_array(row, file_path, row_id, "encounter_ids", "encounters", indexes, errors)
		_validate_ref_field(row, file_path, row_id, "reward_pool_id", "reward_pools", indexes, errors)
		if row.has("progression_reward_id"):
			_validate_ref_field(row, file_path, row_id, "progression_reward_id", "progression_nodes", indexes, errors)

	for row in _rows(content, "campaigns"):
		var file_path := _file_for(files, "campaigns")
		var row_id := _row_label(row, 0)
		_validate_ref_array(row, file_path, row_id, "entry_character_ids", "characters", indexes, errors)
		for index in range(_array_or_empty(row, "acts").size()):
			var act = row["acts"][index]
			if typeof(act) != TYPE_DICTIONARY:
				continue
			_validate_ref_array(act, file_path, row_id, "encounter_ids", "encounters", indexes, errors, "acts[%s]" % index)
			_validate_ref_array(act, file_path, row_id, "quest_ids", "quests", indexes, errors, "acts[%s]" % index)
			if act.has("progression_gate_id"):
				_validate_ref_value(act["progression_gate_id"], file_path, row_id, "acts[%s].progression_gate_id" % index, "progression_nodes", indexes, errors)

	for row in _rows(content, "events"):
		var file_path := _file_for(files, "events")
		var row_id := _row_label(row, 0)
		_validate_ref_field(row, file_path, row_id, "campaign_id", "campaigns", indexes, errors)
		var trigger = row.get("trigger")
		if typeof(trigger) == TYPE_DICTIONARY:
			_validate_condition_refs(trigger, file_path, row_id, "trigger", indexes, errors)
		var effects = row.get("effects")
		if typeof(effects) == TYPE_DICTIONARY:
			_validate_ref_array(effects, file_path, row_id, "available_quest_ids", "quests", indexes, errors, "effects")
			_validate_ref_array(effects, file_path, row_id, "unlock_progression_ids", "progression_nodes", indexes, errors, "effects")

	for row in _rows(content, "endings"):
		var file_path := _file_for(files, "endings")
		var row_id := _row_label(row, 0)
		_validate_ref_field(row, file_path, row_id, "campaign_id", "campaigns", indexes, errors)
		_validate_ref_array(row, file_path, row_id, "related_faction_ids", "factions", indexes, errors)
		_validate_ref_array(row, file_path, row_id, "related_character_ids", "characters", indexes, errors)
		var requirements = row.get("requirements")
		if typeof(requirements) == TYPE_DICTIONARY:
			_validate_ref_array(requirements, file_path, row_id, "completed_quest_ids", "quests", indexes, errors, "requirements")
			_validate_ref_array(requirements, file_path, row_id, "failed_quest_ids", "quests", indexes, errors, "requirements")
			_validate_ref_array(requirements, file_path, row_id, "required_progression_ids", "progression_nodes", indexes, errors, "requirements")
			_validate_ref_array(requirements, file_path, row_id, "blocked_progression_ids", "progression_nodes", indexes, errors, "requirements")
			_validate_condition_refs(requirements, file_path, row_id, "requirements", indexes, errors)
		var discovery = row.get("discovery")
		if typeof(discovery) == TYPE_DICTIONARY:
			_validate_ref_array(discovery, file_path, row_id, "carryover_progression_ids", "progression_nodes", indexes, errors, "discovery")


func _validate_condition_refs(
	target: Dictionary,
	file_path: String,
	row_id: String,
	prefix: String,
	indexes: Dictionary,
	errors: Array
) -> void:
	for index in range(_array_or_empty(target, "faction_state").size()):
		var entry = target["faction_state"][index]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("faction_id"):
			_validate_ref_value(entry["faction_id"], file_path, row_id, "%s.faction_state[%s].faction_id" % [prefix, index], "factions", indexes, errors)
	for index in range(_array_or_empty(target, "quest_state").size()):
		var entry = target["quest_state"][index]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("quest_id"):
			_validate_ref_value(entry["quest_id"], file_path, row_id, "%s.quest_state[%s].quest_id" % [prefix, index], "quests", indexes, errors)
	for index in range(_array_or_empty(target, "character_state").size()):
		var entry = target["character_state"][index]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("character_id"):
			_validate_ref_value(entry["character_id"], file_path, row_id, "%s.character_state[%s].character_id" % [prefix, index], "characters", indexes, errors)


func _load_asset_manifest_categories(manifest_path: String) -> Dictionary:
	var errors := []
	var asset_categories := {}

	if not FileAccess.file_exists(manifest_path):
		_add_error(errors, manifest_path, "<file>", "<file>", "missing asset manifest")
		return {
			"ok": false,
			"asset_categories": asset_categories,
			"errors": errors
		}

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_add_error(errors, manifest_path, "<file>", "<file>", "could not open file, error %s" % FileAccess.get_open_error())
		return {
			"ok": false,
			"asset_categories": asset_categories,
			"errors": errors
		}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		_add_error(
			errors,
			manifest_path,
			"<json>",
			"<json>",
			"parse error at line %s: %s" % [json.get_error_line(), json.get_error_message()]
		)
		return {
			"ok": false,
			"asset_categories": asset_categories,
			"errors": errors
		}

	if typeof(json.data) != TYPE_DICTIONARY:
		_add_error(errors, manifest_path, "<file>", "<root>", "expected JSON object")
		return {
			"ok": false,
			"asset_categories": asset_categories,
			"errors": errors
		}

	var document: Dictionary = json.data
	if typeof(document.get("assets")) != TYPE_ARRAY:
		_add_error(errors, manifest_path, "<file>", "assets", "missing or invalid assets array")
		return {
			"ok": false,
			"asset_categories": asset_categories,
			"errors": errors
		}

	for entry in document["assets"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if typeof(entry.get("id")) == TYPE_STRING and typeof(entry.get("category")) == TYPE_STRING:
			asset_categories[str(entry["id"])] = str(entry["category"])

	return {
		"ok": true,
		"asset_categories": asset_categories,
		"errors": []
	}


func _has_asset_references(content: Dictionary) -> bool:
	for table_key in ASSET_REFERENCE_FIELDS.keys():
		var field: String = ASSET_REFERENCE_FIELDS[table_key]["field"]
		for row in _rows(content, table_key):
			if typeof(row) == TYPE_DICTIONARY and row.has(field):
				return true
	return false


func _validate_asset_references(
	content: Dictionary,
	files: Dictionary,
	asset_categories: Dictionary,
	asset_manifest_loaded: bool,
	errors: Array
) -> void:
	if not asset_manifest_loaded:
		return

	for table_key in ASSET_REFERENCE_FIELDS.keys():
		var spec: Dictionary = ASSET_REFERENCE_FIELDS[table_key]
		var file_path := _file_for(files, table_key)
		for row in _rows(content, table_key):
			_validate_asset_ref_field(
				row,
				file_path,
				_row_label(row, 0),
				spec["field"],
				spec["category"],
				asset_categories,
				errors
			)


func _validate_asset_ref_field(
	row: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	expected_category: String,
	asset_categories: Dictionary,
	errors: Array
) -> void:
	if not row.has(field) or typeof(row[field]) != TYPE_STRING:
		return

	var asset_id := str(row[field])
	if not asset_categories.has(asset_id):
		_add_error(errors, file_path, row_id, field, "unknown asset id '%s'" % asset_id)
		return

	var category := str(asset_categories[asset_id])
	if category != expected_category:
		_add_error(
			errors,
			file_path,
			row_id,
			field,
			"expected asset category '%s', got '%s'" % [expected_category, category]
		)


func _require_fields(target: Dictionary, fields: Array, file_path: String, row_id: String, prefix: String, errors: Array) -> void:
	for field in fields:
		if not target.has(field):
			_add_error(errors, file_path, row_id, _join_field(prefix, field), "missing required field")


func _validate_non_empty_string(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	errors: Array,
	prefix: String = ""
) -> void:
	if not target.has(field):
		return
	var field_path := _join_field(prefix, field)
	if not _validate_string_value(target[field], file_path, row_id, field_path, errors):
		return
	if str(target[field]).strip_edges().is_empty():
		_add_error(errors, file_path, row_id, field_path, "must not be empty")


func _validate_optional_string(target: Dictionary, file_path: String, row_id: String, field: String, errors: Array) -> void:
	if target.has(field):
		_validate_string_value(target[field], file_path, row_id, field, errors)


func _validate_enum(target: Dictionary, file_path: String, row_id: String, field: String, allowed: Array, errors: Array) -> void:
	if not target.has(field):
		return
	_validate_enum_value(target[field], file_path, row_id, field, allowed, errors)


func _validate_enum_value(value, file_path: String, row_id: String, field: String, allowed: Array, errors: Array) -> void:
	if not _validate_string_value(value, file_path, row_id, field, errors):
		return
	if not allowed.has(str(value)):
		_add_error(errors, file_path, row_id, field, "expected one of %s, got '%s'" % [allowed, value])


func _validate_regex_field(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	pattern: String,
	message: String,
	errors: Array
) -> void:
	if not target.has(field):
		return
	if not _validate_string_value(target[field], file_path, row_id, field, errors):
		return
	if not _matches_regex(str(target[field]), pattern):
		_add_error(errors, file_path, row_id, field, message)


func _validate_string_array(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	errors: Array,
	_optional: bool,
	prefix: String = ""
) -> void:
	if not target.has(field):
		return

	var field_path := _join_field(prefix, field)
	if typeof(target[field]) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field_path, "expected array")
		return

	var values: Array = target[field]
	for index in range(values.size()):
		_validate_string_value(values[index], file_path, row_id, "%s[%s]" % [field_path, index], errors)


func _validate_integer_min_field(target: Dictionary, file_path: String, row_id: String, field: String, minimum: int, errors: Array) -> void:
	if target.has(field):
		_validate_integer_min_value(target[field], file_path, row_id, field, minimum, errors)


func _validate_optional_integer(target: Dictionary, file_path: String, row_id: String, field: String, errors: Array) -> void:
	if target.has(field) and not _is_integer_value(target[field]):
		_add_error(errors, file_path, row_id, field, "expected integer")


func _validate_string_value(value, file_path: String, row_id: String, field: String, errors: Array) -> bool:
	if typeof(value) != TYPE_STRING:
		_add_error(errors, file_path, row_id, field, "expected string")
		return false
	if str(value).is_empty():
		_add_error(errors, file_path, row_id, field, "must not be empty")
		return false
	return true


func _validate_integer_min_value(value, file_path: String, row_id: String, field: String, minimum: int, errors: Array) -> bool:
	if not _is_integer_value(value):
		_add_error(errors, file_path, row_id, field, "expected integer")
		return false
	if int(value) < minimum:
		_add_error(errors, file_path, row_id, field, "must be >= %s" % minimum)
		return false
	return true


func _validate_number_min_value(value, file_path: String, row_id: String, field: String, minimum: float, errors: Array) -> bool:
	if not _is_number_value(value):
		_add_error(errors, file_path, row_id, field, "expected number")
		return false
	if float(value) < minimum:
		_add_error(errors, file_path, row_id, field, "must be >= %s" % minimum)
		return false
	return true


func _validate_bool_value(value, file_path: String, row_id: String, field: String, errors: Array) -> bool:
	if typeof(value) != TYPE_BOOL:
		_add_error(errors, file_path, row_id, field, "expected boolean")
		return false
	return true


func _validate_ref_field(
	row: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	target_key: String,
	indexes: Dictionary,
	errors: Array
) -> void:
	if row.has(field):
		_validate_ref_value(row[field], file_path, row_id, field, target_key, indexes, errors)


func _validate_ref_array(
	row: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	target_key: String,
	indexes: Dictionary,
	errors: Array,
	prefix: String = ""
) -> void:
	if not row.has(field) or typeof(row[field]) != TYPE_ARRAY:
		return

	var field_path := _join_field(prefix, field)
	var values: Array = row[field]
	for index in range(values.size()):
		_validate_ref_value(values[index], file_path, row_id, "%s[%s]" % [field_path, index], target_key, indexes, errors)


func _validate_ref_value(value, file_path: String, row_id: String, field: String, target_key: String, indexes: Dictionary, errors: Array) -> void:
	if typeof(value) != TYPE_STRING:
		return
	if not indexes.has(target_key) or not indexes[target_key].has(value):
		_add_error(errors, file_path, row_id, field, "unknown %s id '%s'" % [CONTENT_LABELS[target_key], value])


func _get_array(row: Dictionary, file_path: String, row_id: String, field: String, errors: Array) -> Array:
	if not row.has(field):
		return []
	if typeof(row[field]) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field, "expected array")
		return []
	return row[field]


func _get_array_with_prefix(
	row: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	prefix: String,
	errors: Array
) -> Array:
	if not row.has(field):
		return []
	var field_path := _join_field(prefix, field)
	if typeof(row[field]) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field_path, "expected array")
		return []
	return row[field]


func _validate_prefixed_id_array(
	target: Dictionary,
	file_path: String,
	row_id: String,
	field: String,
	id_prefix: String,
	errors: Array,
	prefix: String = ""
) -> void:
	if not target.has(field):
		return
	var field_path := _join_field(prefix, field)
	if typeof(target[field]) != TYPE_ARRAY:
		_add_error(errors, file_path, row_id, field_path, "expected array")
		return
	var values: Array = target[field]
	for index in range(values.size()):
		_validate_prefixed_id_value(values[index], file_path, row_id, "%s[%s]" % [field_path, index], id_prefix, errors)


func _validate_prefixed_id_value(value, file_path: String, row_id: String, field: String, id_prefix: String, errors: Array) -> void:
	if not _validate_string_value(value, file_path, row_id, field, errors):
		return
	var id := str(value)
	if not _matches_regex(id, ID_PATTERN):
		_add_error(errors, file_path, row_id, field, "must match <kind>.<name> lowercase ID format")
	if not id.begins_with(id_prefix):
		_add_error(errors, file_path, row_id, field, "must start with '%s'" % id_prefix)


func _array_or_empty(row, field: String) -> Array:
	if typeof(row) != TYPE_DICTIONARY:
		return []
	if not row.has(field) or typeof(row[field]) != TYPE_ARRAY:
		return []
	return row[field]


func _rows(content: Dictionary, table_key: String) -> Array:
	var table := _table_for_key(table_key)
	if table.is_empty() or not content.has(table_key):
		return []

	var document = content[table_key]
	if typeof(document) != TYPE_DICTIONARY:
		return []

	var array_key: String = table["array"]
	if not document.has(array_key) or typeof(document[array_key]) != TYPE_ARRAY:
		return []
	return document[array_key]


func _table_for_key(table_key: String) -> Dictionary:
	for table in TABLES:
		if table["key"] == table_key:
			return table
	return {}


func _file_for(files: Dictionary, table_key: String) -> String:
	var table := _table_for_key(table_key)
	return files.get(table_key, _join_data_path(DEFAULT_DATA_ROOT, table["file"]))


func _row_label(row, row_index: int) -> String:
	if typeof(row) == TYPE_DICTIONARY and row.has("id"):
		return str(row["id"])
	return "<row %s>" % row_index


func _join_data_path(root: String, relative_path: String) -> String:
	var normalized_root := root
	while normalized_root.ends_with("/"):
		normalized_root = normalized_root.substr(0, normalized_root.length() - 1)
	return "%s/%s" % [normalized_root, relative_path]


func _join_field(prefix: String, field: String) -> String:
	if prefix.is_empty():
		return field
	return "%s.%s" % [prefix, field]


func _is_integer_value(value) -> bool:
	var value_type := typeof(value)
	if value_type == TYPE_INT:
		return true
	if value_type == TYPE_FLOAT:
		return value == floor(value)
	return false


func _is_number_value(value) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _matches_regex(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	var match_result := regex.search(value)
	return match_result != null and match_result.get_string() == value


func _add_error(errors: Array, file_path: String, row_id: String, field: String, message: String) -> void:
	errors.append("%s [%s] field '%s': %s" % [_display_path(file_path), row_id, field, message])


func _display_path(file_path: String) -> String:
	if file_path.begins_with("res://"):
		return file_path.replace("res://", "")
	return file_path
