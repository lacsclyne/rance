class_name AppConfig
extends RefCounted

const APPLICATION_NAME := "Rance"
const APPLICATION_VERSION := "0.1.0"

const BOOT_SCENE_PATH := "res://scenes/boot/main.tscn"
const ROOT_NODE_NAME := "AppRoot"

const DEFAULT_VIEWPORT_WIDTH := 1280
const DEFAULT_VIEWPORT_HEIGHT := 720
const STRETCH_MODE := "canvas_items"
const STRETCH_ASPECT := "expand"

const INPUT_ACTION_CONFIRM := "confirm"
const INPUT_ACTION_CANCEL := "cancel"
const INPUT_ACTION_MENU := "menu"
const INPUT_ACTIONS := [
	INPUT_ACTION_CONFIRM,
	INPUT_ACTION_CANCEL,
	INPUT_ACTION_MENU
]

const AUDIO_BUS_LAYOUT_PATH := "res://default_bus_layout.tres"
const AUDIO_MIX_RATE := 48000
const AUDIO_OUTPUT_LATENCY := 15

const SERVICE_APP_CONFIG := "app_config"


func to_dictionary() -> Dictionary:
	return {
		"application_name": APPLICATION_NAME,
		"application_version": APPLICATION_VERSION,
		"boot_scene_path": BOOT_SCENE_PATH,
		"root_node_name": ROOT_NODE_NAME,
		"viewport_width": DEFAULT_VIEWPORT_WIDTH,
		"viewport_height": DEFAULT_VIEWPORT_HEIGHT,
		"stretch_mode": STRETCH_MODE,
		"stretch_aspect": STRETCH_ASPECT,
		"input_actions": INPUT_ACTIONS.duplicate(),
		"audio_bus_layout_path": AUDIO_BUS_LAYOUT_PATH,
		"audio_mix_rate": AUDIO_MIX_RATE,
		"audio_output_latency": AUDIO_OUTPUT_LATENCY
	}
