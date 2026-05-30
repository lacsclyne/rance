extends SceneTree

const AppConfigScript := preload("res://src/config/app_config.gd")
const MainScene := preload("res://scenes/boot/main.tscn")

var _failures := []


func _init() -> void:
	_test_project_settings()
	_test_main_scene_root()
	_finish()


func _test_project_settings() -> void:
	_expect(
		ProjectSettings.get_setting("application/config/name") == AppConfigScript.APPLICATION_NAME,
		"application name matches AppConfig"
	)
	_expect(
		ProjectSettings.get_setting("application/config/version") == AppConfigScript.APPLICATION_VERSION,
		"application version matches AppConfig"
	)
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == AppConfigScript.BOOT_SCENE_PATH,
		"main scene points at the boot scene"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == AppConfigScript.DEFAULT_VIEWPORT_WIDTH,
		"viewport width matches AppConfig"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_height")) == AppConfigScript.DEFAULT_VIEWPORT_HEIGHT,
		"viewport height matches AppConfig"
	)
	_expect(
		ProjectSettings.get_setting("display/window/stretch/mode") == AppConfigScript.STRETCH_MODE,
		"stretch mode matches AppConfig"
	)
	_expect(
		ProjectSettings.get_setting("display/window/stretch/aspect") == AppConfigScript.STRETCH_ASPECT,
		"stretch aspect matches AppConfig"
	)
	_expect(
		ProjectSettings.get_setting("audio/buses/default_bus_layout") == AppConfigScript.AUDIO_BUS_LAYOUT_PATH,
		"audio bus layout path matches AppConfig"
	)
	_expect(
		int(ProjectSettings.get_setting("audio/driver/mix_rate")) == AppConfigScript.AUDIO_MIX_RATE,
		"audio mix rate matches AppConfig"
	)
	_expect(
		int(ProjectSettings.get_setting("audio/driver/output_latency")) == AppConfigScript.AUDIO_OUTPUT_LATENCY,
		"audio output latency matches AppConfig"
	)

	for action in AppConfigScript.INPUT_ACTIONS:
		_expect(InputMap.has_action(action), "input action '%s' exists" % action)
		_expect(InputMap.action_get_events(action).is_empty(), "input action '%s' is a placeholder" % action)


func _test_main_scene_root() -> void:
	var root := MainScene.instantiate()
	get_root().add_child(root)

	_expect(root.name == AppConfigScript.ROOT_NODE_NAME, "main scene root uses the configured node name")
	_expect(root.has_method("initialize_technical_services"), "main scene root exposes service initialization")

	var result: Dictionary = root.initialize_technical_services()
	_expect(result.get("ok"), "technical service initialization succeeds")
	_expect(root.is_initialized(), "app root records initialization state")
	_expect(root.has_service(AppConfigScript.SERVICE_APP_CONFIG), "app_config service is registered")
	_expect(root.get_service(AppConfigScript.SERVICE_APP_CONFIG) == root.get_app_config(), "app_config service is readable")
	_expect(root.list_services() == [AppConfigScript.SERVICE_APP_CONFIG], "service list is stable and sorted")

	get_root().remove_child(root)
	root.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Boot app root minimal test passed.")
		quit(0)
		return

	printerr("Boot app root minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
