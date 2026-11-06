class_name RiggingOverlay
extends Node3D

## Visual 3D overlay for Stage-Builder rigging graph, reaction vectors, and load utilization.
## Color-coded by structural utilization:
##   - Green  (< 60%)
##   - Yellow (60% - 90%)
##   - Orange (90% - 100%)
##   - Red    (> 100% OVERLOAD)

var _mesh_inst: MeshInstance3D = null
var _label_container: Node3D = null

func _ready() -> void:
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "RiggingLinesMesh"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true # Visible through geometry for clear inspection
	_mesh_inst.material_override = mat
	add_child(_mesh_inst)

	_label_container = Node3D.new()
	_label_container.name = "RiggingLabels"
	add_child(_label_container)

	RiggingManager.rigging_solved.connect(_on_rigging_solved)
	RiggingManager.overlay_toggled.connect(_on_overlay_toggled)

	visible = RiggingManager.overlay_visible

func _on_overlay_toggled(is_vis: bool) -> void:
	visible = is_vis

func _on_rigging_solved(results: Dictionary) -> void:
	if not visible:
		return

	_redraw_overlay(results.get("lines", []))

func _redraw_overlay(lines: Array) -> void:
	# Clear previous 3D labels
	for child in _label_container.get_children():
		child.queue_free()

	if lines.is_empty():
		_mesh_inst.mesh = null
		return

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	for item in lines:
		var p_from: Vector3 = item.get("from", Vector3.ZERO)
		var p_to: Vector3 = item.get("to", Vector3.ZERO)
		var col: Color = item.get("color", Color.GREEN)

		# Draw primary line
		im.surface_set_color(col)
		im.surface_add_vertex(p_from)
		im.surface_set_color(col)
		im.surface_add_vertex(p_to)

		# Draw end tick / arrow crossbar
		var dir := (p_to - p_from).normalized()
		var perp := Vector3.UP.cross(dir).normalized()
		if perp.length_squared() < 0.01:
			perp = Vector3.RIGHT.cross(dir).normalized()

		im.surface_set_color(col)
		im.surface_add_vertex(p_to - (perp * 0.15))
		im.surface_set_color(col)
		im.surface_add_vertex(p_to + (perp * 0.15))

		# Add 3D text label at midpoint if provided
		var txt: String = item.get("text", "")
		if txt != "" and (p_to - p_from).length() > 0.3:
			var mid := (p_from + p_to) * 0.5 + Vector3(0, 0.25, 0)
			var lbl := Label3D.new()
			lbl.text = txt
			lbl.font_size = 20
			lbl.pixel_size = 0.005
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.modulate = col
			lbl.position = mid
			_label_container.add_child(lbl)

	im.surface_end()
	_mesh_inst.mesh = im

