class_name AssetImportDialog
extends ConfirmationDialog

## GLTF/GLB 3D Asset Import Pipeline for Stage-Builder.
## Validates scale, bounding boxes, and triangle counts, sets real-world metadata,
## saves models to user://imported_assets/ (outside repo), and adds to catalog.

signal asset_imported(asset_id: String)

const USER_ASSETS_DIR = "user://imported_assets"
const MAX_RECOMMENDED_TRIS = 150000

var source_file_path: String = ""
var source_triangle_count: int = 0
var source_bounds: AABB = AABB(Vector3.ZERO, Vector3.ONE)

# UI Elements
var name_input: LineEdit
var id_input: LineEdit
var category_select: OptionButton
var subcategory_input: LineEdit
var dim_x: SpinBox
var dim_y: SpinBox
var dim_z: SpinBox
var weight_input: SpinBox
var tags_input: LineEdit
var pivot_select: OptionButton
var stats_label: Label
var warning_label: Label
var snap_points_list: VBoxContainer
var temp_snap_points: Array = []

func _ready() -> void:
	title = "Import 3D Asset (GLTF/GLB)"
	size = Vector2i(540, 680)
	ok_button_text = "Import & Register"
	_build_ui()
	confirmed.connect(_on_import_confirmed)

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	vbox.add_child(stats_label)

	warning_label = Label.new()
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	warning_label.visible = false
	vbox.add_child(warning_label)

	# Name & ID
	vbox.add_child(_create_header("Asset Information"))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Equipment Display Name"
	name_input.text_changed.connect(_on_name_changed)
	vbox.add_child(_create_field_row("Name:", name_input))

	id_input = LineEdit.new()
	id_input.placeholder_text = "Unique Asset ID (e.g. user_my_light)"
	vbox.add_child(_create_field_row("ID:", id_input))

	# Category & Subcategory
	category_select = OptionButton.new()
	vbox.add_child(_create_field_row("Category:", category_select))

	subcategory_input = LineEdit.new()
	subcategory_input.text = "Custom"
	vbox.add_child(_create_field_row("Subcategory:", subcategory_input))

	# Real-World Dimensions (1m = 1 unit)
	vbox.add_child(_create_header("Real-World Physical Scale (Meters)"))
	var dim_hbox := HBoxContainer.new()
	dim_x = _create_spinbox(0.01, 100.0, 1.0, 0.05)
	dim_y = _create_spinbox(0.01, 100.0, 1.0, 0.05)
	dim_z = _create_spinbox(0.01, 100.0, 1.0, 0.05)
	dim_hbox.add_child(dim_x)
	dim_hbox.add_child(dim_y)
	dim_hbox.add_child(dim_z)
	vbox.add_child(dim_hbox)

	# Physical Weight
	vbox.add_child(_create_header("Physical Load (Kilograms)"))
	weight_input = _create_spinbox(0.0, 50000.0, 10.0, 1.0)
	vbox.add_child(_create_field_row("Weight (kg):", weight_input))

	# Tags
	tags_input = LineEdit.new()
	tags_input.text = "custom, imported, user"
	vbox.add_child(_create_field_row("Tags (comma separated):", tags_input))

	# Pivot Placement
	vbox.add_child(_create_header("Pivot Placement"))
	pivot_select = OptionButton.new()
	pivot_select.add_item("Bottom-Center (Default - rests on ground)", 0)
	pivot_select.add_item("Geometric Center", 1)
	pivot_select.add_item("Original Model Origin", 2)
	pivot_select.select(0)
	vbox.add_child(_create_field_row("Pivot Location:", pivot_select))

	# Snap Points Editor
	vbox.add_child(_create_header("Snap Points"))
	var add_snap_btn := Button.new()
	add_snap_btn.text = "+ Add Snap Point"
	add_snap_btn.pressed.connect(_add_snap_point_row)
	vbox.add_child(add_snap_btn)

	snap_points_list = VBoxContainer.new()
	vbox.add_child(snap_points_list)

	scroll.add_child(vbox)
	add_child(scroll)

func inspect_and_open(path: String) -> void:
	source_file_path = path
	temp_snap_points.clear()
	for child in snap_points_list.get_children():
		child.queue_free()

	_populate_categories()

	# Inspect GLTF/GLB
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file(path, state)
	if err != OK:
		warning_label.text = "Error reading 3D file: failed to parse GLTF/GLB structure."
		warning_label.visible = true
		popup_centered()
		return

	# Calculate triangles and bounding box
	source_triangle_count = 0
	source_bounds = AABB()
	var has_bounds := false

	for mesh_idx in range(state.get_meshes().size()):
		var gltf_mesh := state.get_meshes()[mesh_idx]
		var imesh := gltf_mesh.get_mesh()
		if imesh:
			for s in range(imesh.get_surface_count()):
				var arrays: Array = imesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					source_triangle_count += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					source_triangle_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

				var aabb: AABB = imesh.get_aabb()
				if not has_bounds:
					source_bounds = aabb
					has_bounds = true
				else:
					source_bounds = source_bounds.merge(aabb)

	var base_name := path.get_file().get_basename().capitalize()
	name_input.text = base_name
	id_input.text = "user_" + path.get_file().get_basename().to_lower().replace(" ", "_")

	# Set default dimensions from model bounds if valid
	var s_size := source_bounds.size
	if s_size.x > 0.001 and s_size.y > 0.001 and s_size.z > 0.001:
		dim_x.value = s_size.x
		dim_y.value = s_size.y
		dim_z.value = s_size.z

	# Validate Scale & Complexity
	var warnings: Array[String] = []
	if source_triangle_count > MAX_RECOMMENDED_TRIS:
		warnings.append("High Polycount: %d triangles (recommended < %d). Consider decimating." % [source_triangle_count, MAX_RECOMMENDED_TRIS])
	if s_size.length() > 500.0:
		warnings.append("Huge Model Size: %.1fm bounding box. Ensure 1 unit = 1 meter." % s_size.length())
	elif s_size.length() < 0.005:
		warnings.append("Tiny Model Size: %.3fm bounding box. Check export scale units." % s_size.length())

	stats_label.text = "Source: %s | Polycount: %d Tris | Mesh Bounds: %.2fx%.2fx%.2fm" % [
		path.get_file(), source_triangle_count, s_size.x, s_size.y, s_size.z
	]

	if warnings.is_empty():
		warning_label.visible = false
	else:
		warning_label.text = "WARNING: " + " | ".join(warnings)
		warning_label.visible = true

	popup_centered()

func _populate_categories() -> void:
	category_select.clear()
	var cats := CatalogManager.get_categories()
	for c in cats:
		category_select.add_item(c)

func _on_name_changed(new_text: String) -> void:
	if id_input.text.begins_with("user_") or id_input.text == "":
		id_input.text = "user_" + new_text.strip_edges().to_lower().replace(" ", "_")

func _add_snap_point_row() -> void:
	var row := HBoxContainer.new()
	var tag_in := LineEdit.new()
	tag_in.placeholder_text = "Tag (e.g. truss_f34)"
	tag_in.text = "custom_snap"
	tag_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var px := _create_spinbox(-10, 10, 0.0, 0.05)
	var py := _create_spinbox(-10, 10, 0.0, 0.05)
	var pz := _create_spinbox(-10, 10, 0.0, 0.05)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func():
		row.queue_free()
	)

	row.add_child(tag_in)
	row.add_child(px)
	row.add_child(py)
	row.add_child(pz)
	row.add_child(del_btn)
	snap_points_list.add_child(row)

func _on_import_confirmed() -> void:
	if source_file_path == "" or not FileAccess.file_exists(source_file_path):
		AppState.status_message.emit("Import failed: source file does not exist.")
		return

	# 1. Ensure user library folder exists outside repository
	DirAccess.make_dir_absolute(USER_ASSETS_DIR)

	var file_name := source_file_path.get_file()
	var dest_path := USER_ASSETS_DIR + "/" + file_name

	# Copy file to user library
	var dir := DirAccess.open("user://")
	var err := dir.copy(source_file_path, dest_path)
	if err != OK:
		# Fallback: manual copy
		var src_f := FileAccess.open(source_file_path, FileAccess.READ)
		var dst_f := FileAccess.open(dest_path, FileAccess.WRITE)
		if src_f and dst_f:
			dst_f.store_buffer(src_f.get_buffer(src_f.get_length()))
		else:
			AppState.status_message.emit("Failed to copy file to user library.")
			return

	# 2. Extract snap points from UI
	var snaps: Array = []
	for row in snap_points_list.get_children():
		var tag_field: LineEdit = row.get_child(0)
		var sp_x: SpinBox = row.get_child(1)
		var sp_y: SpinBox = row.get_child(2)
		var sp_z: SpinBox = row.get_child(3)
		snaps.append({
			"tag": tag_field.text.strip_edges(),
			"pos": [sp_x.value, sp_y.value, sp_z.value],
			"normal": [0.0, 1.0, 0.0]
		})

	# 3. Build asset catalog entry
	var asset_id := id_input.text.strip_edges()
	if asset_id == "":
		asset_id = "user_" + str(Time.get_ticks_usec())

	var tags_list: Array = []
	for t in tags_input.text.split(","):
		var cleaned := t.strip_edges()
		if cleaned != "":
			tags_list.append(cleaned)

	var pivot_choice_idx := pivot_select.selected
	var pivot_mode := "bottom_center"
	var p_offset_y: float = dim_y.value * 0.5
	if pivot_choice_idx == 1:
		pivot_mode = "center"
		p_offset_y = 0.0
	elif pivot_choice_idx == 2:
		pivot_mode = "custom"
		p_offset_y = 0.0
	else:
		pivot_mode = "bottom_center"
		if source_bounds.size.y > 0.001:
			p_offset_y = -source_bounds.position.y
		else:
			p_offset_y = dim_y.value * 0.5

	var asset_dict := {
		"id": asset_id,
		"name": name_input.text.strip_edges(),
		"category": category_select.get_item_text(category_select.selected),
		"subcategory": subcategory_input.text.strip_edges(),
		"dimensions": {"x": dim_x.value, "y": dim_y.value, "z": dim_z.value},
		"weight_kg": weight_input.value,
		"mesh_generator": "",
		"model_path": dest_path,
		"snap_points": snaps,
		"tags": tags_list,
		"pivot_mode": pivot_mode,
		"pivot_offset_y": p_offset_y
	}

	# 4. Register with CatalogManager
	var ok := CatalogManager.register_imported_asset(asset_dict)
	if ok:
		AppState.status_message.emit("Successfully imported asset '%s' into library!" % asset_dict["name"])
		asset_imported.emit(asset_id)
		print("AssetImportDialog: Successfully registered user asset: %s" % dest_path)
	else:
		AppState.status_message.emit("Failed to register asset in user catalog.")

# --- UI Helpers ---

func _create_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	return lbl

func _create_field_row(label_text: String, control: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	hbox.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(control)
	return hbox

func _create_spinbox(min_v: float, max_v: float, val: float, step_v: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.value = val
	sb.step = step_v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb
