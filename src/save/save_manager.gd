class_name SaveManager
extends RefCounted

const SaveSnapshotContractScript := preload("res://src/save/save_snapshot_contract.gd")


func create_empty_save(slot_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	return SaveSnapshotContractScript.create_snapshot(slot_id, metadata)


func create_save(
	slot_id: String = "",
	metadata: Dictionary = {},
	section_snapshots: Dictionary = {}
) -> Dictionary:
	return SaveSnapshotContractScript.create_snapshot(slot_id, metadata, section_snapshots)


func serialize_snapshot(snapshot: Dictionary) -> Dictionary:
	var normalized := SaveSnapshotContractScript.normalize_snapshot(snapshot)
	if not normalized["ok"]:
		return {
			"ok": false,
			"errors": normalized["errors"].duplicate(true),
			"data": {}
		}

	return {
		"ok": true,
		"errors": [],
		"data": normalized["snapshot"].duplicate(true)
	}


func deserialize_snapshot(payload: Dictionary) -> Dictionary:
	var normalized := SaveSnapshotContractScript.normalize_snapshot(payload)
	if not normalized["ok"]:
		return {
			"ok": false,
			"errors": normalized["errors"].duplicate(true),
			"snapshot": {},
			"migrated": false
		}

	return {
		"ok": true,
		"errors": [],
		"snapshot": normalized["snapshot"].duplicate(true),
		"migrated": normalized.get("migrated", false)
	}


func migrate_snapshot(payload: Dictionary) -> Dictionary:
	return SaveSnapshotContractScript.migrate_to_current_version(payload)


func extract_slot_metadata(payload: Dictionary) -> Dictionary:
	var decoded := deserialize_snapshot(payload)
	if not decoded["ok"]:
		return {
			"ok": false,
			"errors": decoded["errors"].duplicate(true),
			"metadata": {}
		}

	var snapshot: Dictionary = decoded["snapshot"]
	var metadata: Dictionary = SaveSnapshotContractScript.create_slot_metadata(
		"",
		snapshot.get("metadata", {})
	)
	metadata["version"] = snapshot["version"]
	return {
		"ok": true,
		"errors": [],
		"metadata": metadata
	}
