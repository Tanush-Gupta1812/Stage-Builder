extends Node

## Helper script to pre-render 3D thumbnails for all catalog items,
## compile docs/thumbnail_sheet.png, and capture docs/catalog_list_view.png and docs/catalog_grid_view.png.

func _ready() -> void:
	print("=== Thumbnail Builder & Screenshot Generator Started ===")
	call_deferred("_run")

func _run() -> void:
	var win := get_window()
	if win:
		win.size = Vector2i(1920, 1080)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Control = main_scene.instantiate()
	get_tree().root.add_child(main_inst)

	await get_tree().process_frame
	await get_tree().process_frame

	var renderer = ThumbnailRenderer.instance
	if renderer == null:
		push_error("ThumbnailRenderer instance is null!")
		get_tree().quit(1)
		return

	print("Regenerating all thumbnails in 3D...")
	renderer.regenerate_all()

	var start_time := Time.get_ticks_msec()
	while renderer._is_processing or not renderer._queue.is_empty():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > 60000: # 60s timeout
			print("Warning: Thumbnail rendering timeout reached.")
			break

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	print("All thumbnails rendered! Generating contact sheet...")
	var cs_ok := ThumbnailRenderer.generate_contact_sheet("docs/thumbnail_sheet.png")
	print("Contact sheet generated: ", cs_ok)

	var asset_panel := main_inst.find_child("AssetPanel", true, false) as Control
	if asset_panel:
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

		# 1. Capture List View
		var win_img := get_viewport().get_texture().get_image()
		var panel_rect := asset_panel.get_global_rect()
		var scale_factor: float = get_tree().root.content_scale_factor if get_tree().root.content_scale_factor > 0.0 else 1.0
		var pixel_rect := Rect2i(
			Vector2i(int(panel_rect.position.x * scale_factor), int(panel_rect.position.y * scale_factor)),
			Vector2i(int(panel_rect.size.x * scale_factor), int(panel_rect.size.y * scale_factor))
		).intersection(Rect2i(Vector2i.ZERO, win_img.get_size()))

		var list_img := win_img.get_region(pixel_rect)
		list_img.save_png("docs/catalog_list_view.png")
		print("Saved docs/catalog_list_view.png")

		# 2. Switch to Grid View
		var view_btn := asset_panel.find_child("ViewModeBtn", true, false) as Button
		if view_btn:
			view_btn.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw

			win_img = get_viewport().get_texture().get_image()
			var grid_img := win_img.get_region(pixel_rect)
			grid_img.save_png("docs/catalog_grid_view.png")
			print("Saved docs/catalog_grid_view.png")

	print("=== Thumbnail Builder & Screenshot Generator Finished Successfully ===")
	get_tree().quit(0)
