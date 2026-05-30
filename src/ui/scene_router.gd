class_name SceneRouter
extends RefCounted

var _routes := {}
var _current_route_id := ""
var _current_screen: Node = null


func register(route_id: String, screen_scene: PackedScene) -> Dictionary:
	if route_id.strip_edges().is_empty():
		return _error("route_id must not be empty")
	if screen_scene == null:
		return _error("screen_scene must not be null")

	_routes[route_id] = screen_scene
	return {
		"ok": true,
		"route_id": route_id
	}


func show(route_id: String, host: Node) -> Dictionary:
	if host == null:
		return _error("host must not be null")
	if not _routes.has(route_id):
		return _error("route '%s' is not registered" % route_id)

	var screen_scene: PackedScene = _routes[route_id]
	var screen := screen_scene.instantiate()
	if screen == null:
		return _error("route '%s' could not instantiate a screen" % route_id)

	clear()
	host.add_child(screen)
	_current_route_id = route_id
	_current_screen = screen

	return {
		"ok": true,
		"route_id": route_id,
		"screen": screen
	}


func current() -> Dictionary:
	return {
		"route_id": _current_route_id,
		"screen": _current_screen
	}


func clear() -> Dictionary:
	if _current_screen != null and is_instance_valid(_current_screen):
		var parent := _current_screen.get_parent()
		if parent != null:
			parent.remove_child(_current_screen)
		_current_screen.free()

	_current_route_id = ""
	_current_screen = null

	return {"ok": true}


func has_route(route_id: String) -> bool:
	return _routes.has(route_id)


func get_registered_routes() -> Array:
	var route_ids := _routes.keys()
	route_ids.sort()
	return route_ids


func get_current_route_id() -> String:
	return _current_route_id


func get_current_screen() -> Node:
	return _current_screen


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message
	}
