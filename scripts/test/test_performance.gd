class_name TestPerformance
extends Node3D

## Stress test harness for Stage-Builder.
## Spawns 5,000 objects in the 3D scene to verify 60 FPS performance on Godot 4 Forward+ renderer.

@export var target_object_count: int = 5000

@onready var stats_label: Label = $CanvasLayer/Panel/VBox/StatsLabel
@onready var count_label: Label = $CanvasLayer/Panel/VBox/CountLabel
@onready var camera: Camera3D = $Camera3D

var _instances_spawned: int = 0
var _multimesh_instance: MultiMeshInstance3D = null

func _ready() -> void:
	_spawn_5000_objects()

func _spawn_5000_objects() -> void:
	# Using MultiMesh for 5,000 spectator figures in a concert festival ground (50x100 grid)
	_multimesh_instance = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = target_object_count

	# Stylized human spectator mesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 1.75, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.35, 0.48)
	mat.roughness = 0.8
	mesh.material = mat
	mm.mesh = mesh

	var cols := 100
	var rows := 50
	var spacing_x := 0.7
	var spacing_z := 0.7

	var idx := 0
	for r in range(rows):
		for c in range(cols):
			if idx >= target_object_count:
				break
			var x := (float(c) - float(cols) * 0.5) * spacing_x + (randf() - 0.5) * 0.15
			var z := (float(r) - float(rows) * 0.5) * spacing_z + (randf() - 0.5) * 0.15
			var t := Transform3D()
			t = t.rotated(Vector3.UP, (randf() - 0.5) * 0.4)
			t.origin = Vector3(x, 1.75 * 0.5, z)
			mm.set_instance_transform(idx, t)
			idx += 1

	_multimesh_instance.multimesh = mm
	add_child(_multimesh_instance)
	_instances_spawned = idx

	count_label.text = "Spawned Objects: %d / %d" % [_instances_spawned, target_object_count]

func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var static_mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
	stats_label.text = "FPS: %d (%.2f ms) | Static RAM: %.1f MB" % [fps, 1000.0 / maxf(1.0, float(fps)), static_mem_mb]

	# Orbit camera slowly around festival crowd to test dynamic rendering
	camera.global_position = Vector3(
		sin(Time.get_ticks_msec() * 0.0005) * 45.0,
		25.0,
		cos(Time.get_ticks_msec() * 0.0005) * 45.0
	)
	camera.look_at(Vector3(0, 2.0, 0), Vector3.UP)

