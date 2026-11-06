class_name AppMenuBar
extends MenuBar

## Top professional menu bar for Stage-Builder.
## Routes File, Edit, View, Ground, and Help menu commands.

signal request_open_file
signal request_save_file(save_as: bool)
signal request_new_file
signal request_import_file
signal request_show_shortcuts
signal request_show_about
signal request_toggle_catalog
signal request_toggle_properties
signal request_toggle_checks
signal request_show_performance_settings

var file_menu: PopupMenu
var edit_menu: PopupMenu
var view_menu: PopupMenu
var perf_menu: PopupMenu
var ui_scale_menu: PopupMenu
var camera_menu: PopupMenu
var ground_menu: PopupMenu
var help_menu: PopupMenu

func _ready() -> void:
	_create_menus()
	CommandManager.history_changed.connect(_on_history_changed)
	_on_history_changed(CommandManager.can_undo(), CommandManager.can_redo())

	AppState.grid_toggled.connect(func(enabled: bool):
		if view_menu:
			var idx := view_menu.get_item_index(300)
			if idx >= 0:
				view_menu.set_item_checked(idx, enabled)
	)
	AppState.snap_toggled.connect(func(enabled: bool):
		if view_menu:
			var idx := view_menu.get_item_index(301)
			if idx >= 0:
				view_menu.set_item_checked(idx, enabled)
	)
	AppState.point_snap_toggled.connect(func(enabled: bool):
		if view_menu:
			var idx := view_menu.get_item_index(302)
			if idx >= 0:
				view_menu.set_item_checked(idx, enabled)
	)

	PerformanceSettings.settings_changed.connect(_update_perf_menu_checks)
	_update_perf_menu_checks()

	if UIScale:
		UIScale.scale_changed.connect(func(_s): _update_ui_scale_menu_checks())
	_update_ui_scale_menu_checks()

	RiggingManager.overlay_toggled.connect(func(enabled: bool):
		set_overlay_checked(enabled)
	)

func _create_menus() -> void:
	var mod_key := PlatformUtils.get_modifier_name()

	# --- File Menu ---
	file_menu = PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("New Project (" + mod_key + "+N)", 100)
	file_menu.add_item("Open Project... (" + mod_key + "+O)", 101)
	file_menu.add_separator()
	file_menu.add_item("Save (" + mod_key + "+S)", 102)
	file_menu.add_item("Save As...", 103)
	file_menu.add_separator()
	file_menu.add_item("Import 3D Asset (GLTF/GLB)...", 105)
	file_menu.add_separator()
	file_menu.add_item("Export Screenshot (PNG)...", 104)
	file_menu.add_separator()
	file_menu.add_item("Quit", 109)
	file_menu.id_pressed.connect(_on_file_menu_pressed)
	add_child(file_menu)

	# --- Edit Menu ---
	edit_menu = PopupMenu.new()
	edit_menu.name = "Edit"
	edit_menu.add_item("Undo (" + mod_key + "+Z)", 200)
	edit_menu.add_item("Redo (" + mod_key + "+Y)", 201)
	edit_menu.add_separator()
	edit_menu.add_item("Duplicate (" + mod_key + "+D)", 202)
	edit_menu.add_item("Delete (Del)", 203)
	edit_menu.add_separator()
	edit_menu.add_item("Group Selection (" + mod_key + "+G)", 204)
	edit_menu.add_item("Ungroup (" + mod_key + "+Shift+G)", 205)
	edit_menu.add_separator()
	edit_menu.add_item("Select All (" + mod_key + "+A)", 206)
	edit_menu.add_item("Deselect All (Esc)", 207)
	edit_menu.id_pressed.connect(_on_edit_menu_pressed)
	add_child(edit_menu)

	# --- View Menu ---
	view_menu = PopupMenu.new()
	view_menu.name = "View"
	view_menu.add_check_item("Show 3D Grid (G)", 300)
	view_menu.set_item_checked(0, AppState.show_grid)
	view_menu.add_check_item("Snap to Grid (S)", 301)
	view_menu.set_item_checked(1, AppState.snap_to_grid)
	view_menu.add_check_item("Snap Point-to-Point", 302)
	view_menu.set_item_checked(2, AppState.snap_to_points)
	view_menu.add_separator()
	view_menu.add_item("Top View (Numpad 7)", 303)
	view_menu.add_item("Front View (Numpad 1)", 304)
	view_menu.add_item("Side View (Numpad 3)", 305)
	view_menu.add_item("Perspective View (Numpad 0)", 306)
	view_menu.add_separator()
	view_menu.add_item("Frame Selection (F)", 307)
	view_menu.add_separator()
	view_menu.add_check_item("Equipment Catalog (" + mod_key + "+[)", 308)
	view_menu.set_item_checked(view_menu.get_item_count() - 1, true)
	view_menu.add_check_item("Properties Inspector (" + mod_key + "+])", 309)
	view_menu.set_item_checked(view_menu.get_item_count() - 1, true)
	view_menu.add_check_item("Structural Checks (" + mod_key + "+3)", 314)
	view_menu.set_item_checked(view_menu.get_item_count() - 1, false)
	view_menu.add_separator()
	view_menu.add_check_item("Rigging 3D Overlay (O)", 310)
	view_menu.set_item_checked(view_menu.get_item_count() - 1, RiggingManager.overlay_visible)
	view_menu.add_separator()

	# UI Scale Submenu
	ui_scale_menu = PopupMenu.new()
	ui_scale_menu.name = "UIScaleMenu"
	ui_scale_menu.add_radio_check_item("Auto (" + mod_key + "+0)", 320)
	ui_scale_menu.add_separator()
	ui_scale_menu.add_radio_check_item("100%", 321)
	ui_scale_menu.add_radio_check_item("125%", 322)
	ui_scale_menu.add_radio_check_item("150%", 323)
	ui_scale_menu.add_radio_check_item("175%", 324)
	ui_scale_menu.add_radio_check_item("200%", 325)
	ui_scale_menu.add_radio_check_item("250%", 326)
	ui_scale_menu.add_radio_check_item("300%", 327)
	ui_scale_menu.add_separator()
	ui_scale_menu.add_item("Zoom In (" + mod_key + "+Plus)", 328)
	ui_scale_menu.add_item("Zoom Out (" + mod_key + "+Minus)", 329)
	ui_scale_menu.id_pressed.connect(_on_ui_scale_menu_pressed)
	view_menu.add_child(ui_scale_menu)
	view_menu.add_submenu_node_item("UI Scale", ui_scale_menu, 319)

	# Camera Submenu
	camera_menu = PopupMenu.new()
	camera_menu.name = "CameraMenu"
	camera_menu.add_check_item("Invert middle-drag movement", 350)
	camera_menu.id_pressed.connect(_on_camera_menu_pressed)
	view_menu.add_child(camera_menu)
	view_menu.add_submenu_node_item("Camera", camera_menu, 318)

	# Performance Submenu
	perf_menu = PopupMenu.new()
	perf_menu.name = "PerformanceMenu"
	perf_menu.add_radio_check_item("VSync (Default)", 311)
	perf_menu.set_item_tooltip(0, "Synchronize rendering with display refresh rate to eliminate tearing. (On macOS, system compositor always enforces display sync).")
	perf_menu.add_radio_check_item("Custom FPS Limit...", 312)
	perf_menu.set_item_tooltip(1, "Cap rendering to a specific target frame rate. Disables VSync. (Note: On macOS, system sync may still cap rate to display Hz).")
	perf_menu.add_radio_check_item("Unlimited", 313)
	perf_menu.set_item_tooltip(2, "Uncapped rendering with VSync disabled. Note: on macOS, 'Unlimited' is not meaningful as macOS Metal compositor forces display sync.")
	perf_menu.add_separator()
	perf_menu.add_check_item("Limit to 30 FPS when Unfocused", 314)
	perf_menu.set_item_tooltip(4, "Reduces engine rendering to 30 FPS whenever the application window loses focus or is minimized to save battery and GPU power.")
	perf_menu.add_separator()
	perf_menu.add_item("Frame Rate & Performance Settings...", 315)
	perf_menu.id_pressed.connect(_on_perf_menu_pressed)
	view_menu.add_child(perf_menu)
	view_menu.add_submenu_node_item("Performance", perf_menu, 310)

	# Developer Submenu
	var dev_menu := PopupMenu.new()
	dev_menu.name = "DevMenu"
	dev_menu.add_item("Regenerate All Thumbnails", 330)
	dev_menu.id_pressed.connect(_on_dev_menu_pressed)
	view_menu.add_child(dev_menu)
	view_menu.add_submenu_node_item("Developer", dev_menu, 316)

	view_menu.id_pressed.connect(_on_view_menu_pressed)
	view_menu.about_to_popup.connect(_update_camera_menu_checks)

	add_child(view_menu)

	# --- Ground Menu ---
	ground_menu = PopupMenu.new()
	ground_menu.name = "Ground"
	ground_menu.add_radio_check_item("Concrete Arena Slab", 400)
	ground_menu.add_radio_check_item("Festival Meadow Grass", 401)
	ground_menu.add_radio_check_item("Parking Lot Asphalt", 402)
	ground_menu.set_item_checked(0, true)
	ground_menu.id_pressed.connect(_on_ground_menu_pressed)
	add_child(ground_menu)

	# --- Help Menu ---
	help_menu = PopupMenu.new()
	help_menu.name = "Help"
	help_menu.add_item("Keyboard & Mouse Controls...", 500)
	help_menu.add_item("About Stage-Builder", 501)
	help_menu.id_pressed.connect(_on_help_menu_pressed)
	add_child(help_menu)

func _on_file_menu_pressed(id: int) -> void:
	match id:
		100: request_new_file.emit()
		101: request_open_file.emit()
		102: request_save_file.emit(false)
		103: request_save_file.emit(true)
		104: AppState.request_screenshot.emit()
		105: request_import_file.emit()
		109: get_tree().quit()

func _on_edit_menu_pressed(id: int) -> void:
	match id:
		200: CommandManager.undo()
		201: CommandManager.redo()
		202:
			var vp := get_tree().root.find_child("StageViewport", true, false)
			if vp and vp.has_method("_duplicate_selection"):
				vp._duplicate_selection()
		203:
			var vp := get_tree().root.find_child("StageViewport", true, false)
			if vp and vp.has_method("_delete_selection"):
				vp._delete_selection()
		204:
			var vp := get_tree().root.find_child("StageViewport", true, false)
			if vp and vp.has_method("_group_selection"):
				vp._group_selection()
		205:
			var vp := get_tree().root.find_child("StageViewport", true, false)
			if vp and vp.has_method("_ungroup_selection"):
				vp._ungroup_selection()
		206: AppState.select_all()
		207: AppState.clear_selection()

func _on_view_menu_pressed(id: int) -> void:
	var camera: StageCamera = get_tree().root.find_child("StageCamera", true, false)
	match id:
		300:
			AppState.show_grid = not AppState.show_grid
			view_menu.set_item_checked(0, AppState.show_grid)
		301:
			AppState.snap_to_grid = not AppState.snap_to_grid
			view_menu.set_item_checked(1, AppState.snap_to_grid)
		302:
			AppState.snap_to_points = not AppState.snap_to_points
			view_menu.set_item_checked(2, AppState.snap_to_points)
		303: if camera: camera.set_view_top()
		304: if camera: camera.set_view_front()
		305: if camera: camera.set_view_side()
		306: if camera: camera.set_view_perspective()
		307: if camera: camera.frame_selection()
		308: request_toggle_catalog.emit()
		309: request_toggle_properties.emit()
		310: RiggingManager.toggle_overlay()
		314: request_toggle_checks.emit()

func set_checks_checked(is_checked: bool) -> void:
	if view_menu:
		var idx := view_menu.get_item_index(314)
		if idx >= 0:
			view_menu.set_item_checked(idx, is_checked)

func set_overlay_checked(is_checked: bool) -> void:
	if view_menu:
		var idx := view_menu.get_item_index(310)
		if idx >= 0:
			view_menu.set_item_checked(idx, is_checked)

func set_catalog_checked(is_checked: bool) -> void:
	if view_menu:
		var idx := view_menu.get_item_index(308)
		if idx >= 0:
			view_menu.set_item_checked(idx, is_checked)

func set_properties_checked(is_checked: bool) -> void:
	if view_menu:
		var idx := view_menu.get_item_index(309)
		if idx >= 0:
			view_menu.set_item_checked(idx, is_checked)

func _on_ground_menu_pressed(id: int) -> void:
	ground_menu.set_item_checked(0, id == 400)
	ground_menu.set_item_checked(1, id == 401)
	ground_menu.set_item_checked(2, id == 402)
	match id:
		400: AppState.current_ground = "concrete"
		401: AppState.current_ground = "grass"
		402: AppState.current_ground = "parking_lot"

func _on_help_menu_pressed(id: int) -> void:
	match id:
		500: request_show_shortcuts.emit()
		501: request_show_about.emit()

func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	if edit_menu:
		edit_menu.set_item_disabled(0, not can_undo)
		edit_menu.set_item_disabled(1, not can_redo)

func _update_perf_menu_checks() -> void:
	if not is_instance_valid(perf_menu):
		return
	var mode := PerformanceSettings.fps_mode
	perf_menu.set_item_checked(0, mode == PerformanceSettings.FPSMode.VSYNC)
	perf_menu.set_item_checked(1, mode == PerformanceSettings.FPSMode.CUSTOM_LIMIT)
	perf_menu.set_item_checked(2, mode == PerformanceSettings.FPSMode.UNLIMITED)
	perf_menu.set_item_checked(4, PerformanceSettings.limit_fps_unfocused)

func _on_perf_menu_pressed(id: int) -> void:
	match id:
		311:
			PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.VSYNC)
		312:
			PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.CUSTOM_LIMIT)
			request_show_performance_settings.emit()
		313:
			PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.UNLIMITED)
		314:
			PerformanceSettings.set_limit_fps_unfocused(not PerformanceSettings.limit_fps_unfocused)
		315:
			request_show_performance_settings.emit()

func _update_ui_scale_menu_checks() -> void:
	if not is_instance_valid(ui_scale_menu):
		return
	var is_auto: bool = UIScale.is_auto_scale()
	var cur_scale: float = UIScale.get_current_scale()

	ui_scale_menu.set_item_checked(0, is_auto)
	# Indices for percentages:
	# item 0 is Auto, item 1 is separator, item 2 is 100%, 3 is 125%, 4 is 150%, 5 is 175%, 6 is 200%, 7 is 250%, 8 is 300%
	var pct_map := {
		2: 1.0,
		3: 1.25,
		4: 1.5,
		5: 1.75,
		6: 2.0,
		7: 2.5,
		8: 3.0
	}
	for idx in pct_map:
		var target_scale: float = pct_map[idx]
		ui_scale_menu.set_item_checked(idx, not is_auto and is_equal_approx(cur_scale, target_scale))

func _on_ui_scale_menu_pressed(id: int) -> void:
	match id:
		320: UIScale.reset_to_auto()
		321: UIScale.set_manual_scale(1.0)
		322: UIScale.set_manual_scale(1.25)
		323: UIScale.set_manual_scale(1.5)
		324: UIScale.set_manual_scale(1.75)
		325: UIScale.set_manual_scale(2.0)
		326: UIScale.set_manual_scale(2.5)
		327: UIScale.set_manual_scale(3.0)
		328: UIScale.zoom_in()
		329: UIScale.zoom_out()

func _on_dev_menu_pressed(id: int) -> void:
	match id:
		330:
			if is_instance_valid(ThumbnailRenderer.instance):
				ThumbnailRenderer.instance.regenerate_all()
				AppState.status_message.emit("Regenerating all asset thumbnails...")

func _update_camera_menu_checks() -> void:
	if not is_instance_valid(camera_menu):
		return
	var camera: StageCamera = get_tree().root.find_child("StageCamera", true, false)
	if camera:
		camera_menu.set_item_checked(0, camera.invert_middle_drag)

func _on_camera_menu_pressed(id: int) -> void:
	match id:
		350:
			var camera: StageCamera = get_tree().root.find_child("StageCamera", true, false)
			if camera:
				var new_val := not camera.invert_middle_drag
				camera.set_invert_middle_drag(new_val)
				camera_menu.set_item_checked(0, new_val)





