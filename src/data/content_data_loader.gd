class_name ContentDataLoader
extends RefCounted

const DEFAULT_DATA_ROOT := "res://data"
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
	"campaigns": ["id", "name", "entry_character_ids", "acts"]
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
	"reward_kind": ["card", "skill"],
	"unlock_kind": ["character", "card", "skill", "encounter", "quest"]
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
	"campaigns": "campaign"
}


func load_and_validate(data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	var load_result := load_content(data_root)
	if not load_result["ok"]:
		return {
			"ok": false,
			"data": load_result["data"],
			"indexes": {},
			"errors": load_result["errors"]
		}

	return validate_content(load_result["data"], load_result["files"])


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


func validate_content(content: Dictionary, files: Dictionary = {}) -> Dictionary:
	var errors := []
	var indexes := {}
	var all_ids := {}

	for table in TABLES:
		indexes[table["key"]] = {}
		_validate_collection_shape(table, content, files, indexes, all_ids, errors)

	_validate_references(content, files, indexes, errors)

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


func _validate_references(content: Dictionary, files: Dictionary, indexes: Dictionary, errors: Array) -> void:
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
