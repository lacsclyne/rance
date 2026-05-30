class_name UIShell
extends Control

const SceneRouterScript := preload("res://src/ui/scene_router.gd")

@export var initial_route_id := ""
@export var initial_screen_scene: PackedScene

var router := SceneRouterScript.new()


func _ready() -> void:
	if initial_screen_scene == null:
		return
	var route_id := initial_route_id
	if route_id.strip_edges().is_empty():
		route_id = "initial"
	register_screen(route_id, initial_screen_scene)
	show_screen(route_id)


func register_screen(route_id: String, screen_scene: PackedScene) -> Dictionary:
	return router.register(route_id, screen_scene)


func show_screen(route_id: String) -> Dictionary:
	var host := get_screen_host()
	if host == null:
		return {
			"ok": false,
			"error": "ScreenHost node is missing"
		}
	return router.show(route_id, host)


func clear_screen() -> Dictionary:
	return router.clear()


func current() -> Dictionary:
	return router.current()


func get_current_route_id() -> String:
	return router.get_current_route_id()


func get_screen_host() -> Control:
	return get_node_or_null("ScreenHost") as Control
