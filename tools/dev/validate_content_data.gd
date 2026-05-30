extends SceneTree


func _init() -> void:
	var data_root := "res://data"
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for index in range(args.size()):
		if args[index] == "--data-root" and index + 1 < args.size():
			data_root = args[index + 1]

	var loader = load("res://src/data/content_data_loader.gd").new()
	var result: Dictionary = loader.load_and_validate(data_root)

	if result["ok"]:
		print(
			"Content data validation passed: %s collections, %s records."
			% [result["indexes"].size(), loader.count_records(result)]
		)
		quit(0)
		return

	printerr("Content data validation failed:")
	for error in result["errors"]:
		printerr("- %s" % error)
	quit(1)
