extends Node

func _ready() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	print("Starting UI Polish Screenshot Capture...")
	DirAccess.make_dir_recursive_absolute("docs/ui_polish")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var root_node: Window = get_tree().root

	var main_inst: Control = main_scene.instantiate()
	root_node.add_child(main_inst)

	# Wait for initial tree setup
	for i in range(10):
		await get_tree().process_frame

	# Place a sample asset on stage so properties panel and gizmo have active context
	var sample_asset: Node3D = CatalogManager.instantiate_asset("truss_box_2m")
	if sample_asset:
		var stage_container: Node3D = AppState.stage_container
		if stage_container:
			stage_container.add_child(sample_asset)
			sample_asset.global_position = Vector3(0, 0, 0)
			AppState.set_selection([sample_asset])

	var test_configs := [
		{"width": 1000, "height": 900, "scale": 1.0, "tool": AppState.ToolMode.MOVE, "name": "ui_scale_100_w1000"},
		{"width": 1400, "height": 900, "scale": 1.0, "tool": AppState.ToolMode.ROTATE, "name": "ui_scale_100_w1400"},
		{"width": 1920, "height": 1080, "scale": 1.0, "tool": AppState.ToolMode.MOVE, "name": "ui_scale_100_w1920"},
		{"width": 1400, "height": 900, "scale": 1.5, "tool": AppState.ToolMode.MOVE, "name": "ui_scale_150_w1400"},
		{"width": 1920, "height": 1080, "scale": 1.5, "tool": AppState.ToolMode.ROTATE, "name": "ui_scale_150_w1920"},
		{"width": 1400, "height": 900, "scale": 2.0, "tool": AppState.ToolMode.SCALE, "name": "ui_scale_200_w1400"},
		{"width": 1920, "height": 1080, "scale": 2.0, "tool": AppState.ToolMode.MOVE, "name": "ui_scale_200_w1920"},
	]

	for cfg in test_configs:
		var w: int = cfg["width"]
		var h: int = cfg["height"]
		var s: float = cfg["scale"]
		var tool_mode: AppState.ToolMode = cfg["tool"]
		var filename: String = cfg["name"]

		AppState.current_tool = tool_mode
		if tool_mode == AppState.ToolMode.ROTATE:
			AppState.show_all_rotation_axes = true

		root_node.size = Vector2i(w, h)
		main_inst.size = Vector2(w, h)
		main_inst.custom_minimum_size = Vector2(w, h)
		UIScale.set_scale(s)

		for i in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var img: Image = root_node.get_texture().get_image()
		if img and not img.is_empty():
			var path := "docs/ui_polish/%s.png" % filename
			var err := img.save_png(path)
			if err == OK:
				print("Saved screenshot: %s (%dx%d, scale %.1f)" % [path, w, h, s])
			else:
				push_error("Failed to save: %s, error %d" % [path, err])
		else:
			print("Note: root texture image empty in current rasterizer mode for %s" % filename)

	print("Capture complete.")
	get_tree().quit(0)
