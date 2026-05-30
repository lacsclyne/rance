extends SceneTree

const SceneRouterScript := preload("res://src/ui/scene_router.gd")
const UIShellScene := preload("res://scenes/ui/shell.tscn")

var _failures := []


func _init() -> void:
	_test_router_operations()
	_test_shell_scene_loads()
	_finish()


func _test_router_operations() -> void:
	var router := SceneRouterScript.new()
	var host := Control.new()

	var alpha_scene := _make_screen_scene("AlphaScreen")
	var beta_scene := _make_screen_scene("BetaScreen")

	_expect(router.register("beta", beta_scene).get("ok"), "beta route registers")
	_expect(router.register("alpha", alpha_scene).get("ok"), "alpha route registers")
	_expect(router.get_registered_routes() == ["alpha", "beta"], "registered routes are sorted")
	_expect(not router.register("", alpha_scene).get("ok"), "empty route ids are rejected")

	var missing_result: Dictionary = router.show("missing", host)
	_expect(not missing_result.get("ok"), "missing route cannot be shown")
	_expect(host.get_child_count() == 0, "missing route does not mutate host")

	var alpha_result: Dictionary = router.show("alpha", host)
	_expect(alpha_result.get("ok"), "alpha route shows")
	_expect(router.get_current_route_id() == "alpha", "current route id is alpha")
	_expect(router.current().get("route_id") == "alpha", "current operation exposes route id")
	_expect(host.get_child_count() == 1, "show adds one screen to host")
	_expect(host.get_child(0).name == "AlphaScreen", "alpha screen instance is hosted")

	var beta_result: Dictionary = router.show("beta", host)
	_expect(beta_result.get("ok"), "beta route shows")
	_expect(router.get_current_route_id() == "beta", "current route id is beta")
	_expect(host.get_child_count() == 1, "show replaces the previous screen")
	_expect(host.get_child(0).name == "BetaScreen", "beta screen instance is hosted")

	_expect(router.clear().get("ok"), "clear succeeds")
	_expect(router.get_current_route_id().is_empty(), "clear resets current route id")
	_expect(router.get_current_screen() == null, "clear resets current screen")
	_expect(host.get_child_count() == 0, "clear empties the host")

	host.free()


func _test_shell_scene_loads() -> void:
	var shell := UIShellScene.instantiate()
	get_root().add_child(shell)

	_expect(shell.has_method("show_screen"), "shell scene instantiates its script")
	_expect(shell.has_node("ScreenHost"), "shell has a ScreenHost")

	var shell_route_result: Dictionary = shell.register_screen("alpha", _make_screen_scene("ShellScreen"))
	_expect(shell_route_result.get("ok"), "shell registers a screen route")

	var show_result: Dictionary = shell.show_screen("alpha")
	_expect(show_result.get("ok"), "shell shows a registered route")
	_expect(shell.get_current_route_id() == "alpha", "shell exposes current route id")
	_expect(shell.get_node("ScreenHost").get_child_count() == 1, "shell hosts one screen")

	_expect(shell.clear_screen().get("ok"), "shell clears the current screen")
	_expect(shell.get_node("ScreenHost").get_child_count() == 0, "shell host is empty after clear")

	get_root().remove_child(shell)
	shell.free()


func _make_screen_scene(screen_name: String) -> PackedScene:
	var screen := Control.new()
	screen.name = screen_name
	var scene := PackedScene.new()
	var result := scene.pack(screen)
	_expect(result == OK, "%s packs into a scene" % screen_name)
	screen.free()
	return scene


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("UI router minimal test passed.")
		quit(0)
		return

	printerr("UI router minimal test failed:")
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
