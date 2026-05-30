class_name AppRoot
extends Node

const AppConfigScript := preload("res://src/config/app_config.gd")

var _app_config: RefCounted = AppConfigScript.new()
var _services := {}
var _initialized := false


func _ready() -> void:
	initialize_technical_services()


func initialize_technical_services() -> Dictionary:
	if _initialized:
		return {
			"ok": true,
			"services": list_services()
		}

	_register_service(AppConfigScript.SERVICE_APP_CONFIG, _app_config)
	_initialized = true

	return {
		"ok": true,
		"services": list_services()
	}


func get_app_config() -> RefCounted:
	return _app_config


func get_service(service_name: String):
	return _services.get(service_name)


func has_service(service_name: String) -> bool:
	return _services.has(service_name)


func list_services() -> Array:
	var names := _services.keys()
	names.sort()
	return names


func is_initialized() -> bool:
	return _initialized


func _register_service(service_name: String, service) -> void:
	if service_name.strip_edges().is_empty() or service == null:
		return
	_services[service_name] = service
