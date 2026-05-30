class_name ResourceRegistry
extends RefCounted

const DEFAULT_ASSET_MANIFEST_PATH := "res://assets/asset_manifest.json"

const TYPE_TEXTURE := "texture"
const TYPE_AUDIO := "audio"
const TYPE_SCENE := "scene"
const TYPE_RESOURCE := "resource"
const TYPE_DATA := "data"

const MANIFEST_CATEGORY_TYPES := {
	"card_art": TYPE_TEXTURE,
	"portrait": TYPE_TEXTURE,
	"faction_icon": TYPE_TEXTURE,
	"skill_icon": TYPE_TEXTURE,
	"encounter_background": TYPE_TEXTURE,
	"ui": TYPE_TEXTURE
}

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

	var metadata := {}
	if options.has("metadata"):
		if typeof(options["metadata"]) != TYPE_DICTIONARY:
			errors.append("metadata must be a dictionary")
		else:
			metadata = options["metadata"].duplicate(true)

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
		"cache_policy": cache_policy,
		"metadata": metadata
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

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"manifest_found": true,
			"loaded": 0,
			"errors": ["could not open %s, error %s" % [manifest_path, FileAccess.get_open_error()]]
		}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"ok": false,
			"manifest_found": true,
			"loaded": 0,
			"errors": [
				"parse error in %s at line %s: %s" % [
					manifest_path,
					json.get_error_line(),
					json.get_error_message()
				]
			]
		}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"manifest_found": true,
			"loaded": 0,
			"errors": ["asset manifest root must be a dictionary"]
		}

	var document: Dictionary = json.data
	if typeof(document.get("assets")) != TYPE_ARRAY:
		return {
			"ok": false,
			"manifest_found": true,
			"loaded": 0,
			"errors": ["asset manifest must contain an assets array"]
		}

	var errors := []
	var loaded := 0
	var assets: Array = document["assets"]
	for index in range(assets.size()):
		var entry = assets[index]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("assets[%s] must be a dictionary" % index)
			continue

		var asset_id := str(entry.get("id", ""))
		var category := str(entry.get("category", ""))
		var asset_path := str(entry.get("path", ""))
		var metadata := {
			"category": category,
			"status": str(entry.get("status", "")),
			"required": bool(entry.get("required", false))
		}
		if entry.has("source_id"):
			metadata["source_id"] = str(entry["source_id"])

		var registration := register_resource(
			asset_id,
			_manifest_resource_type(category),
			_to_godot_path(asset_path),
			{
				"cache_policy": CACHE_POLICY_ON_DEMAND,
				"metadata": metadata
			}
		)
		if registration["ok"]:
			loaded += 1
		else:
			for error in registration["errors"]:
				errors.append("%s: %s" % [asset_id, error])

	return {
		"ok": errors.is_empty(),
		"manifest_found": true,
		"loaded": loaded,
		"errors": errors
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


func _manifest_resource_type(category: String) -> String:
	return MANIFEST_CATEGORY_TYPES.get(category, TYPE_RESOURCE)


func _to_godot_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://"):
		return path
	return "res://%s" % path
