extends SceneTree

const ResourceRegistryScript := preload("res://src/resource_loading/resource_registry.gd")

var _failures := []


func _init() -> void:
	_test_registration_and_lookup()
	_test_duplicate_ids_do_not_overwrite()
	_test_missing_ids_are_empty()
	_test_optional_placeholder_paths()
	_test_manifest_adapter_loads_lac28_schema()
	_finish()


func _test_registration_and_lookup() -> void:
	var registry = ResourceRegistryScript.new()
	var result: Dictionary = registry.register_resource(
		"portrait.guardian",
		ResourceRegistryScript.TYPE_TEXTURE,
		"res://assets/portraits/guardian.png",
		{
			"placeholder_path": "res://assets/placeholders/portrait.png",
			"cache_policy": ResourceRegistryScript.CACHE_POLICY_REUSE
		}
	)

	_expect(result["ok"], "resource registers successfully")
	_expect(registry.count() == 1, "registry count includes registered resource")
	_expect(registry.has_resource("portrait.guardian"), "registry reports known ID")
	_expect(
		registry.get_path("portrait.guardian", ResourceRegistryScript.TYPE_TEXTURE) == "res://assets/portraits/guardian.png",
		"typed lookup returns the Godot path"
	)
	_expect(
		registry.get_entry("portrait.guardian", ResourceRegistryScript.TYPE_AUDIO).is_empty(),
		"typed lookup rejects mismatched resource type"
	)
	_expect(
		registry.list_ids_for_type(ResourceRegistryScript.TYPE_TEXTURE) == ["portrait.guardian"],
		"type index returns registered IDs"
	)
	_expect(
		registry.list_ids_for_path("res://assets/portraits/guardian.png") == ["portrait.guardian"],
		"path index returns registered IDs"
	)
	_expect(
		registry.get_cache_policy("portrait.guardian") == ResourceRegistryScript.CACHE_POLICY_REUSE,
		"cache policy placeholder is stored without loading the resource"
	)


func _test_duplicate_ids_do_not_overwrite() -> void:
	var registry = ResourceRegistryScript.new()
	registry.register_resource(
		"portrait.guardian",
		ResourceRegistryScript.TYPE_TEXTURE,
		"res://assets/portraits/guardian.png"
	)
	var duplicate: Dictionary = registry.register_resource(
		"portrait.guardian",
		ResourceRegistryScript.TYPE_SCENE,
		"res://scenes/portraits/guardian.tscn"
	)

	_expect(not duplicate["ok"], "duplicate ID registration fails")
	_expect(duplicate["errors"].size() == 1, "duplicate ID reports one focused error")
	_expect(
		registry.get_path("portrait.guardian") == "res://assets/portraits/guardian.png",
		"duplicate ID does not overwrite the original path"
	)
	_expect(registry.count() == 1, "duplicate ID does not increase registry count")


func _test_missing_ids_are_empty() -> void:
	var registry = ResourceRegistryScript.new()

	_expect(not registry.has_resource("portrait.missing"), "unknown ID is not present")
	_expect(registry.get_entry("portrait.missing").is_empty(), "unknown ID lookup returns an empty dictionary")
	_expect(registry.get_path("portrait.missing").is_empty(), "unknown ID path lookup returns an empty string")
	_expect(registry.get_placeholder_path("portrait.missing").is_empty(), "unknown ID placeholder lookup returns an empty string")
	_expect(registry.get_cache_policy("portrait.missing").is_empty(), "unknown ID cache policy lookup returns an empty string")


func _test_optional_placeholder_paths() -> void:
	var registry = ResourceRegistryScript.new()
	registry.register_resource(
		"portrait.guardian",
		ResourceRegistryScript.TYPE_TEXTURE,
		"res://assets/portraits/guardian.png",
		{"placeholder_path": "res://assets/placeholders/portrait.png"}
	)
	registry.register_resource(
		"portrait.tactician",
		ResourceRegistryScript.TYPE_TEXTURE,
		"res://assets/portraits/tactician.png"
	)

	_expect(
		registry.get_placeholder_path("portrait.guardian") == "res://assets/placeholders/portrait.png",
		"registered placeholder path is available"
	)
	_expect(
		registry.get_placeholder_path("portrait.tactician").is_empty(),
		"placeholder path remains optional"
	)


func _test_manifest_adapter_loads_lac28_schema() -> void:
	var registry = ResourceRegistryScript.new()
	var result: Dictionary = registry.load_from_asset_manifest("res://assets/asset_manifest.json")

	_expect(result["ok"], "asset manifest loads into the registry")
	_expect(result["manifest_found"], "manifest adapter reports that a manifest was found")
	_expect(result["loaded"] > 0, "manifest loads registry entries")
	_expect(
		registry.get_path("portrait.iris", ResourceRegistryScript.TYPE_TEXTURE) == "res://assets/portraits/iris.png",
		"manifest paths are exposed as Godot res paths"
	)
	var entry := registry.get_entry("portrait.iris")
	_expect(entry.get("metadata", {}).get("category", "") == "portrait", "manifest category metadata is retained")
	_expect(entry.get("metadata", {}).get("status", "") == "placeholder", "manifest status metadata is retained")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Resource registry test passed.")
		quit(0)
		return

	printerr("Resource registry test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
