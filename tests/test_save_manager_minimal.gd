extends SceneTree

const SaveManagerScript := preload("res://src/save/save_manager.gd")
const SaveSnapshotContractScript := preload("res://src/save/save_snapshot_contract.gd")

var _failures := []


func _init() -> void:
	_test_empty_save_creation()
	_test_slot_metadata_extraction()
	_test_round_trip_encode_decode()
	_test_version_mismatch_behavior()
	_test_missing_optional_sections()
	_finish()


func _test_empty_save_creation() -> void:
	var manager = SaveManagerScript.new()
	var snapshot: Dictionary = manager.create_empty_save(
		"slot_001",
		{
			"slot_label": "First Slot",
			"campaign_id": "campaign.sample",
			"playtime_seconds": 120
		}
	)

	_expect_equal(
		SaveSnapshotContractScript.CURRENT_VERSION,
		snapshot["version"],
		"empty save uses the current save version"
	)
	for section_key in SaveSnapshotContractScript.SECTION_KEYS:
		_expect(snapshot.has(section_key), "empty save includes %s section" % section_key)
		_expect(
			typeof(snapshot[section_key]) == TYPE_DICTIONARY,
			"empty save section %s is dictionary-shaped" % section_key
		)
		_expect(snapshot[section_key].is_empty(), "empty save section %s starts empty" % section_key)

	var metadata: Dictionary = snapshot["metadata"]
	_expect_equal("slot_001", metadata["slot_id"], "slot id is written to metadata")
	_expect_equal("First Slot", metadata["slot_label"], "slot label is written to metadata")
	_expect_equal("campaign.sample", metadata["campaign_id"], "campaign id is written to metadata")
	_expect_equal(120, metadata["playtime_seconds"], "playtime seconds is written to metadata")
	_expect_equal({}, metadata["summary"], "metadata summary defaults to an empty dictionary")


func _test_slot_metadata_extraction() -> void:
	var manager = SaveManagerScript.new()
	var snapshot: Dictionary = manager.create_empty_save(
		"slot_meta",
		{
			"slot_label": "Metadata Slot",
			"updated_at": "2026-05-30T00:00:00Z",
			"summary": {"chapter": "opening"}
		}
	)
	var result: Dictionary = manager.extract_slot_metadata(snapshot)
	_expect(result["ok"], "slot metadata extraction succeeds")
	var metadata: Dictionary = result.get("metadata", {})
	_expect_equal(
		SaveSnapshotContractScript.CURRENT_VERSION,
		metadata["version"],
		"slot metadata exposes the save version"
	)
	_expect_equal("slot_meta", metadata["slot_id"], "slot metadata includes slot id")
	_expect_equal("Metadata Slot", metadata["slot_label"], "slot metadata includes label")
	_expect_equal(
		{"chapter": "opening"},
		metadata["summary"],
		"slot metadata preserves summary dictionary"
	)


func _test_round_trip_encode_decode() -> void:
	var manager = SaveManagerScript.new()
	var original: Dictionary = manager.create_save(
		"slot_story",
		{
			"slot_label": "Story",
			"created_at": "2026-05-30T01:00:00Z",
			"updated_at": "2026-05-30T02:00:00Z",
			"campaign_id": "campaign.sample",
			"playtime_seconds": 42,
			"summary": {"node": "crossroad"}
		},
		{
			"campaign": {"active_campaign_id": "campaign.sample"},
			"collection": {"owned_character_ids": ["character.iris"]},
			"formation": {"leader_ids": ["character.iris"]},
			"quest": {"active_quest_id": "quest.secure_crossroad"},
			"progression": {"unlocked_ids": ["progression.first_victory"]},
			"settings": {"text_speed": "normal"}
		}
	)

	var encoded: Dictionary = manager.serialize_snapshot(original)
	_expect(encoded["ok"], "snapshot serializes")
	var decoded: Dictionary = manager.deserialize_snapshot(encoded["data"])
	_expect(decoded["ok"], "serialized snapshot deserializes")
	_expect_equal(original, decoded["snapshot"], "round trip preserves normalized snapshot data")

	encoded["data"]["campaign"]["active_campaign_id"] = "campaign.changed"
	_expect_equal(
		"campaign.sample",
		original["campaign"]["active_campaign_id"],
		"serialized data is a deep copy of the original snapshot"
	)


func _test_version_mismatch_behavior() -> void:
	var manager = SaveManagerScript.new()
	var future_snapshot: Dictionary = manager.create_empty_save()
	future_snapshot["version"] = SaveSnapshotContractScript.CURRENT_VERSION + 1

	var future_result: Dictionary = manager.deserialize_snapshot(future_snapshot)
	_expect(not future_result["ok"], "future save versions are rejected")
	_expect(
		future_result["errors"][0].contains("newer than supported"),
		"future version error explains the mismatch"
	)

	var missing_version_result: Dictionary = manager.deserialize_snapshot({"metadata": {}})
	_expect(not missing_version_result["ok"], "missing save versions are rejected")


func _test_missing_optional_sections() -> void:
	var manager = SaveManagerScript.new()
	var minimal_payload := {
		"version": SaveSnapshotContractScript.CURRENT_VERSION,
		"metadata": {"slot_id": "slot_minimal"}
	}
	var result: Dictionary = manager.deserialize_snapshot(minimal_payload)
	_expect(result["ok"], "minimal payload with missing optional sections decodes")
	var snapshot: Dictionary = result["snapshot"]
	for section_key in SaveSnapshotContractScript.SECTION_KEYS:
		_expect(snapshot.has(section_key), "decoded minimal save includes %s section" % section_key)
		_expect_equal(
			{},
			snapshot[section_key],
			"decoded minimal save defaults %s section to an empty dictionary" % section_key
		)
	_expect_equal("slot_minimal", snapshot["metadata"]["slot_id"], "minimal metadata is preserved")
	_expect_equal("", snapshot["metadata"]["slot_label"], "missing metadata fields use defaults")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("Save manager minimal test passed.")
		quit(0)
		return

	printerr("Save manager minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
