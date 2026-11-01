class_name GridPlane
extends Node3D

## 3D Stage Grid with 1m minor lines, 5m major lines, and colored X/Z center axes.
## Reacts to AppState.grid_toggled for toggling visibility.

@export var grid_extent: float = 60.0 # 120m x 120m total area
@export var minor_step: float = 1.0
@export var major_step: float = 5.0

var _mesh_instance: MeshInstance3D = null

func _ready() -> void:
	_create_grid_mesh()
	AppState.grid_toggled.connect(func(v: bool): visible = v)
	visible = AppState.show_grid

func _create_grid_mesh() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()

	_mesh_instance = MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var minor_color := Color(0.35, 0.38, 0.42, 0.25)
	var major_color := Color(0.55, 0.60, 0.70, 0.55)
	var x_axis_color := Color(0.9, 0.2, 0.2, 0.8) # Red for X
	var z_axis_color := Color(0.2, 0.4, 0.9, 0.8) # Blue for Z

	var steps := int(grid_extent / minor_step)
	for i in range(-steps, steps + 1):
		var coord := float(i) * minor_step
		var is_major: bool = fmod(absf(coord) + 0.001, major_step) < 0.01
		var is_center: bool = absf(coord) < 0.001

		# Lines parallel to Z (varying X)
		var col_x := minor_color
		if is_center:
			col_x = z_axis_color
		elif is_major:
			col_x = major_color

		immediate_mesh.surface_set_color(col_x)
		immediate_mesh.surface_add_vertex(Vector3(coord, 0.005, -grid_extent))
		immediate_mesh.surface_set_color(col_x)
		immediate_mesh.surface_add_vertex(Vector3(coord, 0.005, grid_extent))

		# Lines parallel to X (varying Z)
		var col_z := minor_color
		if is_center:
			col_z = x_axis_color
		elif is_major:
			col_z = major_color

		immediate_mesh.surface_set_color(col_z)
		immediate_mesh.surface_add_vertex(Vector3(-grid_extent, 0.005, coord))
		immediate_mesh.surface_set_color(col_z)
		immediate_mesh.surface_add_vertex(Vector3(grid_extent, 0.005, coord))

	immediate_mesh.surface_end()
	_mesh_instance.mesh = immediate_mesh
	add_child(_mesh_instance)
