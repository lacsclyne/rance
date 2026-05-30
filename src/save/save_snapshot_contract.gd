class_name SaveSnapshotContract
extends RefCounted

const CURRENT_VERSION := 1
const MIN_SUPPORTED_VERSION := 1

const SECTION_CAMPAIGN := "campaign"
const SECTION_COLLECTION := "collection"
const SECTION_FORMATION := "formation"
const SECTION_QUEST := "quest"
const SECTION_PROGRESSION := "progression"
const SECTION_SETTINGS := "settings"

const SECTION_KEYS := [
	SECTION_CAMPAIGN,
	SECTION_COLLECTION,
	SECTION_FORMATION,
	SECTION_QUEST,
	SECTION_PROGRESSION,
	SECTION_SETTINGS
]

const METADATA_SLOT_ID := "slot_id"
const METADATA_SLOT_LABEL := "slot_label"
const METADATA_CREATED_AT := "created_at"
const METADATA_UPDATED_AT := "updated_at"
const METADATA_CAMPAIGN_ID := "campaign_id"
const METADATA_PLAYTIME_SECONDS := "playtime_seconds"
const METADATA_SUMMARY := "summary"


static func create_snapshot(
	slot_id: String = "",
	slot_metadata: Dictionary = {},
	section_snapshots: Dictionary = {}
) -> Dictionary:
	var snapshot := {
		"version": CURRENT_VERSION,
		"metadata": create_slot_metadata(slot_id, slot_metadata)
	}
	for section_key in SECTION_KEYS:
		snapshot[section_key] = _dictionary_or_empty(section_snapshots.get(section_key, {}))
	return snapshot


static func create_slot_metadata(slot_id: String = "", slot_metadata: Dictionary = {}) -> Dictionary:
	var metadata := {
		METADATA_SLOT_ID: slot_id,
		METADATA_SLOT_LABEL: "",
		METADATA_CREATED_AT: "",
		METADATA_UPDATED_AT: "",
		METADATA_CAMPAIGN_ID: "",
		METADATA_PLAYTIME_SECONDS: 0,
		METADATA_SUMMARY: {}
	}
	for key in slot_metadata.keys():
		var metadata_key := str(key)
		metadata[metadata_key] = _json_friendly_copy(slot_metadata[key])
	if not slot_id.is_empty():
		metadata[METADATA_SLOT_ID] = slot_id
	if typeof(metadata.get(METADATA_SUMMARY, {})) != TYPE_DICTIONARY:
		metadata[METADATA_SUMMARY] = {}
	if typeof(metadata.get(METADATA_PLAYTIME_SECONDS, 0)) != TYPE_INT:
		metadata[METADATA_PLAYTIME_SECONDS] = int(metadata.get(METADATA_PLAYTIME_SECONDS, 0))
	return metadata


static func normalize_snapshot(payload: Dictionary) -> Dictionary:
	var migration_result := migrate_to_current_version(payload)
	if not migration_result["ok"]:
		return migration_result

	var migrated_snapshot: Dictionary = migration_result["snapshot"]
	var normalized := {
		"version": CURRENT_VERSION,
		"metadata": create_slot_metadata("", _dictionary_or_empty(migrated_snapshot.get("metadata", {})))
	}
	for section_key in SECTION_KEYS:
		normalized[section_key] = _dictionary_or_empty(migrated_snapshot.get(section_key, {}))

	return {
		"ok": true,
		"errors": [],
		"snapshot": normalized,
		"migrated": migration_result.get("migrated", false)
	}


static func migrate_to_current_version(payload: Dictionary) -> Dictionary:
	var version_result := _read_version(payload)
	if not version_result["ok"]:
		return _error(version_result["errors"][0])

	var version: int = version_result["version"]
	if version > CURRENT_VERSION:
		return _error("save version %s is newer than supported version %s" % [
			version,
			CURRENT_VERSION
		])
	if version < MIN_SUPPORTED_VERSION:
		return _error("save version %s is older than minimum supported version %s" % [
			version,
			MIN_SUPPORTED_VERSION
		])

	var migrated_snapshot: Dictionary = payload.duplicate(true)
	var migrated := version != CURRENT_VERSION
	while version < CURRENT_VERSION:
		var step_result := _apply_migration_step(version, migrated_snapshot)
		if not step_result["ok"]:
			return step_result
		migrated_snapshot = step_result["snapshot"]
		version = int(migrated_snapshot.get("version", version + 1))

	return {
		"ok": true,
		"errors": [],
		"snapshot": migrated_snapshot,
		"migrated": migrated
	}


static func migration_placeholders() -> Dictionary:
	return {}


static func _apply_migration_step(from_version: int, _snapshot: Dictionary) -> Dictionary:
	return _error("no migration path from save version %s to %s" % [
		from_version,
		from_version + 1
	])


static func _read_version(payload: Dictionary) -> Dictionary:
	if not payload.has("version"):
		return _error("save snapshot is missing a version")

	var version_value = payload["version"]
	if typeof(version_value) != TYPE_INT and typeof(version_value) != TYPE_FLOAT:
		return _error("save version must be numeric")

	return {
		"ok": true,
		"errors": [],
		"version": int(version_value)
	}


static func _dictionary_or_empty(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return _json_friendly_copy(value)


static func _json_friendly_copy(value):
	if typeof(value) == TYPE_DICTIONARY:
		var copied_dictionary := {}
		for key in value.keys():
			copied_dictionary[str(key)] = _json_friendly_copy(value[key])
		return copied_dictionary

	if typeof(value) == TYPE_ARRAY:
		var copied_array := []
		for item in value:
			copied_array.append(_json_friendly_copy(item))
		return copied_array

	return value


static func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": [message],
		"snapshot": {},
		"migrated": false
	}
