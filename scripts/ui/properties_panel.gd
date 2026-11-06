class_name PropertiesPanel
extends PanelContainer

const StageGroup = preload("res://scripts/core/stage_group.gd")
const TransformGuard = preload("res://scripts/core/transform_guard.gd")

signal collapse_requested

## Right Inspector Panel for Stage-Builder.
## Displays live properties for single selection, multi-selection, or stage overview.

@onready var content_container: VBoxContainer = %ContentContainer

var _active_object: StageObject = null
var _is_updating_ui: bool = false

func _ready() -> void:
	AppState.selection_changed.connect(_on_selection_changed)
	AppState.project_modified.connect(_on_project_modified)
	_show_stage_overview()

func _on_selection_changed(selected: Array) -> void:
	if selected.is_empty():
		_active_object = null
		_show_stage_overview()
	elif selected.size() == 1 and selected[0] is StageObject:
		_active_object = selected[0] as StageObject
		_show_single_object_inspector(_active_object)
	elif selected.size() == 1 and selected[0] is StageGroup:
		_active_object = null
		_show_group_inspector(selected[0] as StageGroup)
	else:
		_active_object = null
		_show_multi_selection_inspector(selected)

func _show_group_inspector(group: StageGroup) -> void:
	_clear_content()
	_create_header("Group: " + group.group_name, Color(0.3, 0.8, 0.6))

	var objs := group.get_all_stage_objects()
	var total_w := 0.0
	for obj in objs:
		if is_instance_valid(obj):
			total_w += obj.weight_kg

	_add_stat_row("Group Name:", group.group_name)
	_add_stat_row("Contained Items:", "%d objects" % objs.size())
	_add_stat_row("Combined Weight:", "%.1f kg" % total_w)

	var btn_ungroup := Button.new()
	btn_ungroup.text = "Ungroup (" + PlatformUtils.get_modifier_name() + "+Shift+G)"
	btn_ungroup.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_ungroup_selection"):
			vp._ungroup_selection()
	)
	content_container.add_child(btn_ungroup)

	var btn_dup := Button.new()
	btn_dup.text = "Duplicate Group"
	btn_dup.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_duplicate_selection"):
			vp._duplicate_selection()
	)
	content_container.add_child(btn_dup)

	var btn_del := Button.new()
	btn_del.text = "Delete Group"
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
	)
	content_container.add_child(btn_del)

func _on_project_modified() -> void:
	if AppState.selected_objects.is_empty():
		_show_stage_overview()
	elif AppState.selected_objects.size() == 1 and _active_object:
		_update_single_object_values()

func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()

func _create_header(title_text: String, title_color: Color = Color(0.9, 0.95, 1.0)) -> void:
	var hbox := HBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", title_color)
	hbox.add_child(title)

	var collapse_btn := Button.new()
	collapse_btn.text = "▶"
	collapse_btn.tooltip_text = "Collapse Panel (Ctrl+] / Cmd+])"
	collapse_btn.flat = true
	collapse_btn.pressed.connect(func(): collapse_requested.emit())
	hbox.add_child(collapse_btn)

	content_container.add_child(hbox)
	var sep := HSeparator.new()
	content_container.add_child(sep)

func _create_section_header(section_title: String) -> void:
	var sep := HSeparator.new()
	content_container.add_child(sep)

	var lbl := Label.new()
	lbl.text = section_title
	lbl.add_theme_color_override("font_color", Color(0.38, 0.72, 1.0))
	content_container.add_child(lbl)

# --- Stage Overview Mode ---

func _show_stage_overview() -> void:
	_clear_content()
	_create_header("Stage Overview", Color(0.9, 0.95, 1.0))

	var obj_count := AppState.get_total_object_count()
	var total_kg := AppState.get_total_weight()

	_add_stat_row("Total Objects:", str(obj_count))
	_add_stat_row("Total Weight:", "%.1f kg (%.2f t)" % [total_kg, total_kg / 1000.0])
	_add_stat_row("Ground Surface:", AppState.current_ground.capitalize())
	_add_stat_row("Active Project:", AppState.project_name)

	var btn_select_all := Button.new()
	btn_select_all.text = "Select All Objects"
	btn_select_all.pressed.connect(AppState.select_all)
	content_container.add_child(btn_select_all)

# --- Single Object Inspector ---

func _show_single_object_inspector(obj: StageObject) -> void:
	_clear_content()
	_create_header("Properties: " + obj.asset_name, Color(0.4, 0.75, 1.0))

	# General Info
	var lbl_name := Label.new()
	lbl_name.text = "Asset Name:"
	content_container.add_child(lbl_name)
	var input_name := LineEdit.new()
	input_name.text = obj.asset_name
	input_name.text_changed.connect(func(new_text: String):
		if not _is_updating_ui and is_instance_valid(obj):
			var cmd := BaseCommand.PropertyChangeCommand.new(obj, "asset_name", obj.asset_name, new_text)
			CommandManager.execute_command(cmd)
	)
	content_container.add_child(input_name)

	_add_stat_row("Category:", obj.category)
	_add_stat_row("Dimensions:", "%.2fx%.2fx%.2f m" % [obj.dimensions.x, obj.dimensions.y, obj.dimensions.z])
	_add_stat_row("Weight:", "%.1f kg" % obj.weight_kg)

	# Appearance Section
	if not obj.available_variants.is_empty():
		_create_section_header("Appearance")
		var var_lbl := Label.new()
		var_lbl.text = "Material / Color Variant:"
		content_container.add_child(var_lbl)

		var var_opt := OptionButton.new()
		var selected_idx := 0
		for i in range(obj.available_variants.size()):
			var v: Dictionary = obj.available_variants[i]
			var_opt.add_item(v.get("name", "Default"), i)
			if v.get("id", "") == obj.current_variant:
				selected_idx = i
		var_opt.select(selected_idx)
		var_opt.item_selected.connect(func(idx: int):
			if not _is_updating_ui and is_instance_valid(obj):
				var target_vid: String = obj.available_variants[idx].get("id", "")
				var cmd := BaseCommand.VariantChangeCommand.new(obj, obj.current_variant, target_vid)
				CommandManager.execute_command(cmd)
		)
		content_container.add_child(var_opt)

	# Transform Section
	_create_section_header("Transform")

	var pos_lbl := Label.new()
	pos_lbl.text = "Position (meters):"
	content_container.add_child(pos_lbl)

	var pos_hbox := HBoxContainer.new()
	pos_hbox.add_theme_constant_override("separation", 6)

	var lx := _create_axis_badge("X", Color(0.95, 0.35, 0.35))
	var spin_x := _create_spinbox(-100, 100, obj.global_position.x, 0.1)
	var ly := _create_axis_badge("Y", Color(0.35, 0.85, 0.35))
	var spin_y := _create_spinbox(-100, 100, obj.global_position.y, 0.1)
	var lz := _create_axis_badge("Z", Color(0.40, 0.65, 1.00))
	var spin_z := _create_spinbox(-100, 100, obj.global_position.z, 0.1)

	spin_x.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			if not is_finite(v) or absf(v) > TransformGuard.MAX_COORD:
				return
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.x = v
			new_t[0] = TransformGuard.sanitize(new_t[0], old_t[0], "PropertiesPanel.PositionX")
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	spin_y.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			if not is_finite(v) or absf(v) > TransformGuard.MAX_COORD:
				return
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.y = v
			new_t[0] = TransformGuard.sanitize(new_t[0], old_t[0], "PropertiesPanel.PositionY")
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	spin_z.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			if not is_finite(v) or absf(v) > TransformGuard.MAX_COORD:
				return
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.z = v
			new_t[0] = TransformGuard.sanitize(new_t[0], old_t[0], "PropertiesPanel.PositionZ")
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)

	pos_hbox.add_child(lx)
	pos_hbox.add_child(spin_x)
	pos_hbox.add_child(ly)
	pos_hbox.add_child(spin_y)
	pos_hbox.add_child(lz)
	pos_hbox.add_child(spin_z)
	content_container.add_child(pos_hbox)

	# 3D Rotation (X, Y, Z Degrees)
	var rot_lbl := Label.new()
	rot_lbl.text = "Rotation (degrees):"
	content_container.add_child(rot_lbl)

	var rot_euler := obj.global_basis.get_euler()
	var rot_hbox := HBoxContainer.new()
	rot_hbox.add_theme_constant_override("separation", 6)

	var lrx := _create_axis_badge("X", Color(0.95, 0.35, 0.35))
	var spin_rx := _create_spinbox(-360, 360, rad_to_deg(rot_euler.x), 5.0)
	var lry := _create_axis_badge("Y", Color(0.35, 0.85, 0.35))
	var spin_ry := _create_spinbox(-360, 360, rad_to_deg(rot_euler.y), 5.0)
	var lrz := _create_axis_badge("Z", Color(0.40, 0.65, 1.00))
	var spin_rz := _create_spinbox(-360, 360, rad_to_deg(rot_euler.z), 5.0)

	var update_rotation = func():
		if not _is_updating_ui and is_instance_valid(obj):
			var rad_x := deg_to_rad(spin_rx.value)
			var rad_y := deg_to_rad(spin_ry.value)
			var rad_z := deg_to_rad(spin_rz.value)
			if not (is_finite(rad_x) and is_finite(rad_y) and is_finite(rad_z)):
				return
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			var new_basis := Basis.from_euler(Vector3(rad_x, rad_y, rad_z))
			new_t[0].basis = new_basis

			if AppState.auto_rest_on_rotate:
				var min_offset: float = StageViewport.get_lowest_point_y_offset(obj, new_basis)
				if new_t[0].origin.y + min_offset < 0.0:
					new_t[0].origin.y = -min_offset

			new_t[0] = TransformGuard.sanitize(new_t[0], old_t[0], "PropertiesPanel.Rotation")
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))

	spin_rx.value_changed.connect(func(_v): update_rotation.call())
	spin_ry.value_changed.connect(func(_v): update_rotation.call())
	spin_rz.value_changed.connect(func(_v): update_rotation.call())

	rot_hbox.add_child(lrx)
	rot_hbox.add_child(spin_rx)
	rot_hbox.add_child(lry)
	rot_hbox.add_child(spin_ry)
	rot_hbox.add_child(lrz)
	rot_hbox.add_child(spin_rz)
	content_container.add_child(rot_hbox)

	# Quick Rotation Buttons
	var rot_btn_grid := GridContainer.new()
	rot_btn_grid.columns = 3
	rot_btn_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_btn_grid.add_theme_constant_override("h_separation", 4)
	rot_btn_grid.add_theme_constant_override("v_separation", 4)

	var vp := get_tree().root.find_child("StageViewport", true, false)

	var btn_rot_x := Button.new()
	btn_rot_x.text = "90° X"
	btn_rot_x.tooltip_text = "Rotate 90 degrees around X axis"
	btn_rot_x.pressed.connect(func(): if vp and vp.has_method("rotate_selected_objects"): vp.rotate_selected_objects(Vector3.RIGHT, 90.0))
	rot_btn_grid.add_child(btn_rot_x)

	var btn_rot_y := Button.new()
	btn_rot_y.text = "90° Y"
	btn_rot_y.tooltip_text = "Rotate 90 degrees around Y axis"
	btn_rot_y.pressed.connect(func(): if vp and vp.has_method("rotate_selected_objects"): vp.rotate_selected_objects(Vector3.UP, 90.0))
	rot_btn_grid.add_child(btn_rot_y)

	var btn_rot_z := Button.new()
	btn_rot_z.text = "90° Z"
	btn_rot_z.tooltip_text = "Rotate 90 degrees around Z axis"
	btn_rot_z.pressed.connect(func(): if vp and vp.has_method("rotate_selected_objects"): vp.rotate_selected_objects(Vector3.BACK, 90.0))
	rot_btn_grid.add_child(btn_rot_z)

	var btn_reset_rot := Button.new()
	btn_reset_rot.text = "Reset Rot"
	btn_reset_rot.tooltip_text = "Reset object rotation to default alignment"
	btn_reset_rot.pressed.connect(func():
		if is_instance_valid(obj):
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].basis = Basis.IDENTITY
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	rot_btn_grid.add_child(btn_reset_rot)

	var btn_stand := Button.new()
	btn_stand.text = "Upright"
	btn_stand.tooltip_text = "Stand object upright (keep yaw, reset pitch/roll)"
	btn_stand.pressed.connect(func():
		if is_instance_valid(obj):
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			var cur_yaw := obj.global_basis.get_euler().y
			new_t[0].basis = Basis(Vector3.UP, cur_yaw)
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	rot_btn_grid.add_child(btn_stand)

	var btn_drop := Button.new()
	btn_drop.text = "Drop Surface"
	btn_drop.tooltip_text = "Drop lowest bounding point to resting surface"
	btn_drop.pressed.connect(func(): if vp and vp.has_method("drop_selected_to_surface"): vp.drop_selected_to_surface())
	rot_btn_grid.add_child(btn_drop)

	content_container.add_child(rot_btn_grid)

	# Rigging Section
	_add_rigging_section(obj)

	# Notes Section
	_create_section_header("Notes")
	var notes_edit := TextEdit.new()
	notes_edit.text = obj.custom_notes
	notes_edit.placeholder_text = "Add operational or setup notes..."
	notes_edit.custom_minimum_size = Vector2(0, 60)
	notes_edit.text_changed.connect(func():
		if not _is_updating_ui and is_instance_valid(obj):
			obj.custom_notes = notes_edit.text
			AppState.is_modified = true
	)
	content_container.add_child(notes_edit)

	# Actions
	_create_section_header("Actions")
	var act_hbox := HBoxContainer.new()
	act_hbox.add_theme_constant_override("separation", 6)

	var btn_dup := Button.new()
	btn_dup.text = "Duplicate"
	btn_dup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dup.pressed.connect(func():
		var vp_node := get_tree().root.find_child("StageViewport", true, false)
		if vp_node and vp_node.has_method("_duplicate_selection"):
			vp_node._duplicate_selection()
	)
	act_hbox.add_child(btn_dup)

	var btn_del := Button.new()
	btn_del.text = "Delete"
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp_node := get_tree().root.find_child("StageViewport", true, false)
		if vp_node and vp_node.has_method("_delete_selection"):
			vp_node._delete_selection()
	)
	act_hbox.add_child(btn_del)
	content_container.add_child(act_hbox)


func _update_single_object_values() -> void:
	# Refreshes the display if transforms changed via gizmo
	if _active_object and is_instance_valid(_active_object):
		_is_updating_ui = true
		_show_single_object_inspector(_active_object)
		_is_updating_ui = false

# --- Multi-Selection Inspector ---

func _show_multi_selection_inspector(selected: Array) -> void:
	_clear_content()
	_create_header("Multiple Objects Selected", Color(0.4, 0.75, 1.0))

	var count := selected.size()
	var total_w := 0.0
	for item in selected:
		if is_instance_valid(item):
			if item is StageObject:
				total_w += item.weight_kg
			elif item is StageGroup:
				for o in item.get_all_stage_objects():
					total_w += o.weight_kg

	_add_stat_row("Selected Count:", "%d items" % count)
	_add_stat_row("Combined Weight:", "%.1f kg" % total_w)

	var btn_group := Button.new()
	btn_group.text = "Group Selected (" + PlatformUtils.get_modifier_name() + "+G)"
	btn_group.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_group_selection"):
			vp._group_selection()
	)
	content_container.add_child(btn_group)

	var btn_del := Button.new()
	btn_del.text = "Delete Selected Items"
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
	)
	content_container.add_child(btn_del)

# --- Helpers ---

func _add_stat_row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	hbox.add_child(val)
	content_container.add_child(hbox)

func _create_axis_badge(axis_name: String, col: Color) -> Label:
	var badge := Label.new()
	badge.text = axis_name
	badge.add_theme_color_override("font_color", col)
	badge.custom_minimum_size = Vector2(12, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return badge

func _create_spinbox(min_val: float, max_val: float, initial: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.value = initial
	sb.custom_minimum_size = Vector2(54, 28)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb

func _add_rigging_section(obj: StageObject) -> void:
	_create_section_header("Rigging & Structural Loads")

	var raw: Dictionary = obj.raw_catalog_data
	var cat: String = obj.category

	# Mass with editable override
	var mass_hbox := HBoxContainer.new()
	mass_hbox.add_theme_constant_override("separation", 6)
	var mass_lbl := Label.new()
	mass_lbl.text = "Mass (%s):" % RiggingManager.active_unit
	mass_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mass_hbox.add_child(mass_lbl)
	var mass_spin := _create_spinbox(0.1, 50000.0, obj.weight_kg, 1.0)
	mass_spin.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			obj.set_rigging_override("weight_kg", v)
	)
	mass_hbox.add_child(mass_spin)
	content_container.add_child(mass_hbox)

	# CoG
	var cog: Vector3 = Vector3(0, obj.dimensions.y * 0.5, 0)
	if raw.has("cog_offset") and raw["cog_offset"] is Array and raw["cog_offset"].size() == 3:
		cog = Vector3(raw["cog_offset"][0], raw["cog_offset"][1], raw["cog_offset"][2])
	_add_stat_row("Center of Gravity:", "(%.2f, %.2f, %.2f)m" % [cog.x, cog.y, cog.z])

	# Truss Rating
	if cat == "Truss":
		var prof: String = raw.get("truss_profile", "box_f34")
		_add_stat_row("Truss Profile:", "F34 Box" if prof == "box_f34" else "F33 Triangle")
		_add_stat_row("Load Rating:", "Standard Span Table (Placeholder)")

	# Hoist / Rigging
	if raw.has("swl_kg") or cat == "Rigging":
		var cur_swl := float(obj.get_rigging_value("swl_kg", raw.get("swl_kg", 1000.0)))
		var swl_hbox := HBoxContainer.new()
		swl_hbox.add_theme_constant_override("separation", 6)
		var swl_lbl := Label.new()
		swl_lbl.text = "Rated SWL (kg):"
		swl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swl_hbox.add_child(swl_lbl)
		var swl_spin := _create_spinbox(10.0, 100000.0, cur_swl, 10.0)
		swl_spin.value_changed.connect(func(v: float):
			if not _is_updating_ui and is_instance_valid(obj):
				obj.set_rigging_override("swl_kg", v)
		)
		swl_hbox.add_child(swl_spin)
		content_container.add_child(swl_hbox)

	if raw.has("motor_capacity_kg"):
		var cur_mc := float(obj.get_rigging_value("motor_capacity_kg", raw.get("motor_capacity_kg", 1000.0)))
		var mc_hbox := HBoxContainer.new()
		mc_hbox.add_theme_constant_override("separation", 6)
		var mc_lbl := Label.new()
		mc_lbl.text = "Motor Capacity (kg):"
		mc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc_hbox.add_child(mc_lbl)
		var mc_spin := _create_spinbox(10.0, 50000.0, cur_mc, 10.0)
		mc_spin.value_changed.connect(func(v: float):
			if not _is_updating_ui and is_instance_valid(obj):
				obj.set_rigging_override("motor_capacity_kg", v)
		)
		mc_hbox.add_child(mc_spin)
		content_container.add_child(mc_hbox)

	# Support
	if raw.get("is_support", false):
		var cur_mvl := float(obj.get_rigging_value("max_vertical_load_kg", raw.get("max_vertical_load_kg", 4000.0)))
		var sup_hbox := HBoxContainer.new()
		sup_hbox.add_theme_constant_override("separation", 6)
		var sup_lbl := Label.new()
		sup_lbl.text = "Max Vert Load (kg):"
		sup_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sup_hbox.add_child(sup_lbl)
		var sup_spin := _create_spinbox(50.0, 100000.0, cur_mvl, 50.0)
		sup_spin.value_changed.connect(func(v: float):
			if not _is_updating_ui and is_instance_valid(obj):
				obj.set_rigging_override("max_vertical_load_kg", v)
		)
		sup_hbox.add_child(sup_spin)
		content_container.add_child(sup_hbox)

	# Rigging Points
	if raw.has("rigging_points") and raw["rigging_points"] is Array:
		var rps: Array = raw["rigging_points"]
		_add_stat_row("Rigging Points:", "%d point(s)" % rps.size())

	# Disclaimer note
	var disc_lbl := Label.new()
	disc_lbl.text = "All calculations are PLANNING AIDS ONLY, not engineering sign-off or structural certification. Verify all rigging, loads and ballasting with a certified structural engineer or licensed rigger before production."
	disc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	content_container.add_child(disc_lbl)

