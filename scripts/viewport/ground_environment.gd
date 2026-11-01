class_name GroundEnvironment
extends Node3D

## Manages 3D lighting, dusk sky ambiance, and selectable ground materials
## (Concrete, Festival Grass, and Parking Lot Asphalt).

@export var ground_size: float = 250.0

var _ground_mesh: MeshInstance3D = null
var _ground_body: StaticBody3D = null
var _materials: Dictionary = {}

func _ready() -> void:
	_init_materials()
	_create_ground()
	_create_lighting_and_sky()

	AppState.ground_changed.connect(set_ground_type)
	set_ground_type(AppState.current_ground)

func _init_materials() -> void:
	# Concrete
	var mat_concrete := StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.48, 0.50, 0.52)
	mat_concrete.roughness = 0.72
	mat_concrete.metallic = 0.05
	mat_concrete.uv1_scale = Vector3(50, 50, 50)
	_materials["concrete"] = mat_concrete

	# Festival Grass
	var mat_grass := StandardMaterial3D.new()
	mat_grass.albedo_color = Color(0.22, 0.36, 0.18)
	mat_grass.roughness = 0.92
	mat_grass.metallic = 0.0
	mat_grass.uv1_scale = Vector3(50, 50, 50)
	_materials["grass"] = mat_grass

	# Parking Lot / Asphalt
	var mat_asphalt := StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.16, 0.17, 0.18)
	mat_asphalt.roughness = 0.85
	mat_asphalt.metallic = 0.08
	mat_asphalt.uv1_scale = Vector3(50, 50, 50)
	_materials["parking_lot"] = mat_asphalt

func _create_ground() -> void:
	_ground_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ground_size, ground_size)
	_ground_mesh.mesh = plane
	_ground_mesh.position = Vector3(0, 0, 0)
	add_child(_ground_mesh)

	# Static collision body for raycasting mouse onto floor
	_ground_body = StaticBody3D.new()
	_ground_body.collision_layer = 1
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size, 0.1, ground_size)
	col_shape.shape = box
	col_shape.position = Vector3(0, -0.05, 0)
	_ground_body.add_child(col_shape)
	add_child(_ground_body)

func _create_lighting_and_sky() -> void:
	# Soft dusk directional sun
	var sun := DirectionalLight3D.new()
	sun.name = "DuskSun"
	sun.light_color = Color(1.0, 0.88, 0.76)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.rotation_degrees = Vector3(-35, -50, 0)
	add_child(sun)

	# Secondary fill light (soft blue skylight)
	var fill := DirectionalLight3D.new()
	fill.name = "SkylightFill"
	fill.light_color = Color(0.55, 0.65, 0.85)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(60, 130, 0)
	add_child(fill)

	# Atmospheric WorldEnvironment
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnv"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.35, 0.58)
	sky_mat.sky_horizon_color = Color(0.85, 0.62, 0.48)
	sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.16)
	sky_mat.ground_horizon_color = Color(0.45, 0.40, 0.38)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat

	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	env_node.environment = env
	add_child(env_node)

func set_ground_type(type_name: String) -> void:
	if _materials.has(type_name) and _ground_mesh:
		_ground_mesh.material_override = _materials[type_name]
		print("GroundEnvironment: Set ground surface to '%s'" % type_name)

