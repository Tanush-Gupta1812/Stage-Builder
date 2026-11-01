class_name AppMenuBar
extends MenuBar

## Top professional menu bar for Stage-Builder.
## Routes File, Edit, View, Ground, and Help menu commands.

signal request_open_file
signal request_save_file(save_as: bool)
signal request_new_file
signal request_show_shortcuts
signal request_show_about

var file_menu: PopupMenu
var edit_menu: PopupMenu
var view_menu: PopupMenu
var ground_menu: PopupMenu
var help_menu: PopupMenu

func _ready() -> void:
	_create_menus()
	CommandManager.history_changed.connect(_on_history_changed)

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
	view_menu.id_pressed.connect(_on_view_menu_pressed)
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

