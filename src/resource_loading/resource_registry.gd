class_name ResourceRegistry
extends RefCounted

const DEFAULT_ASSET_MANIFEST_PATH := "res://assets/asset_manifest.json"

const TYPE_TEXTURE := "texture"
const TYPE_AUDIO := "audio"
const TYPE_SCENE := "scene"
const TYPE_RESOURCE := "resource"
const TYPE_DATA := "data"

const CACHE_POLICY_ON_DEMAND := "on_demand"
const CACHE_POLICY_REUSE := "reuse"
const CACHE_POLICY_KEEP_RESIDENT := "keep_resident"
const CACHE_POLICIES := [
	CACHE_POLICY_ON_DEMAND,
	CACHE_POLICY_REUSE,
	CACHE_POLICY_KEEP_RESIDENT
]

var _entries_by_id := {}
var _ids_by_type := {}
var _ids_by_path := {}


func register_resource(
	resource_id: String,
	resource_type: String,
	godot_path: String,
	options: Dictionary = {}
) -> Dictionary:
	var errors := []
	_validate_required_string(resource_id, "resource_id", errors)
	_validate_required_string(resource_type, "resource_type", errors)
	_validate_godot_path(godot_path, "godot_path", errors)

	if _entries_by_id.has(resource_id):
		errors.append("duplicate resource ID '%s'" % resource_id)

	var placeholder_path := ""
	if options.has("placeholder_path"):
		if typeof(options["placeholder_path"]) != TYPE_STRING:
			errors.append("placeholder_path must be a string")
		else:
			placeholder_path = str(options["placeholder_path"])
			if not placeholder_path.is_empty():
				_validate_godot_path(placeholder_path, "placeholder_path", errors)

	var cache_policy := str(options.get("cache_policy", CACHE_POLICY_ON_DEMAND))
	if not CACHE_POLICIES.has(cache_policy):
		errors.append("cache_policy must be one of %s" % [CACHE_POLICIES])

	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"entry": {}
		}

	var entry := {
		"id": resource_id,
		"resource_type": resource_type,
		"godot_path": godot_path,
		"placeholder_path": placeholder_path,
		"cache_policy": cache_policy
	}
	_entries_by_id[resource_id] = entry
	_add_id_to_index(_ids_by_type, resource_type, resource_id)
	_add_id_to_index(_ids_by_path, godot_path, resource_id)

	return {
		"ok": true,
		"errors": [],
		"entry": entry.duplicate(true)
	}


func has_resource(resource_id: String, expected_type: String = "") -> bool:
	return not get_entry(resource_id, expected_type).is_empty()


func get_entry(resource_id: String, expected_type: String = "") -> Dictionary:
	if not _entries_by_id.has(resource_id):
		return {}

	var entry: Dictionary = _entries_by_id[resource_id]
	if not expected_type.is_empty() and entry["resource_type"] != expected_type:
		return {}
	return entry.duplicate(true)


func get_path(resource_id: String, expected_type: String = "") -> String:
	var entry := get_entry(resource_id, expected_type)
	if entry.is_empty():
		return ""
	return entry["godot_path"]


func get_placeholder_path(resource_id: String, expected_type: String = "") -> String:
	var entry := get_entry(resource_id, expected_type)
	if entry.is_empty():
		return ""
	return entry.get("placeholder_path", "")


func get_cache_policy(resource_id: String, expected_type: String = "") -> String:
	var entry := get_entry(resource_id, expected_type)
	if entry.is_empty():
		return ""
	return entry.get("cache_policy", CACHE_POLICY_ON_DEMAND)


func list_ids_for_type(resource_type: String) -> Array:
	return _copy_id_list(_ids_by_type.get(resource_type, []))


func list_ids_for_path(godot_path: String, expected_type: String = "") -> Array:
	var ids := []
	for resource_id in _ids_by_path.get(godot_path, []):
		if expected_type.is_empty() or get_entry(resource_id, expected_type).has("id"):
			ids.append(resource_id)
	ids.sort()
	return ids


func get_entries_for_path(godot_path: String, expected_type: String = "") -> Array:
	var entries := []
	for resource_id in list_ids_for_path(godot_path, expected_type):
		entries.append(get_entry(resource_id, expected_type))
	return entries


func count() -> int:
	return _entries_by_id.size()


func clear() -> void:
	_entries_by_id.clear()
	_ids_by_type.clear()
	_ids_by_path.clear()


func has_asset_manifest(manifest_path: String = DEFAULT_ASSET_MANIFEST_PATH) -> bool:
	return FileAccess.file_exists(manifest_path)


func load_from_asset_manifest(manifest_path: String = DEFAULT_ASSET_MANIFEST_PATH) -> Dictionary:
	if not has_asset_manifest(manifest_path):
		return {
			"ok": true,
			"manifest_found": false,
			"loaded": 0,
			"errors": []
		}

	return {
		"ok": false,
		"manifest_found": true,
		"loaded": 0,
		"errors": [
			"asset manifest adapter must be wired to the LAC-28 schema before loading %s" % manifest_path
		]
	}


func _add_id_to_index(index: Dictionary, key: String, resource_id: String) -> void:
	if not index.has(key):
		index[key] = []
	if not index[key].has(resource_id):
		index[key].append(resource_id)
		index[key].sort()


func _copy_id_list(ids: Array) -> Array:
	var copied := ids.duplicate()
	copied.sort()
	return copied


func _validate_required_string(value: String, field: String, errors: Array) -> void:
	if value.strip_edges().is_empty():
		errors.append("%s must not be empty" % field)


func _validate_godot_path(path: String, field: String, errors: Array) -> void:
	if path.strip_edges().is_empty():
		errors.append("%s must not be empty" % field)
		return
	if not path.begins_with("res://"):
		errors.append("%s must begin with res://" % field)
