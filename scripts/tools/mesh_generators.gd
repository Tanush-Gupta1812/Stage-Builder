class_name MeshGenerators
extends RefCounted

## Procedural 3D mesh builder for Stage-Builder Phase 2 (125+ equipment assets).
## Generates clean, recognizable, low-drawcall models with shared PBR materials and variant support.

static var _materials: Dictionary = {}

static func get_material(mat_type: String) -> StandardMaterial3D:
	if _materials.has(mat_type):
		return _materials[mat_type]

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.5
	mat.metallic = 0.0

	match mat_type:
		"aluminum":
			mat.albedo_color = Color(0.82, 0.84, 0.86)
			mat.metallic = 0.85
			mat.roughness = 0.28
		"aluminum_black":
			mat.albedo_color = Color(0.12, 0.12, 0.13)
			mat.metallic = 0.7
			mat.roughness = 0.4
		"aluminum_white":
			mat.albedo_color = Color(0.92, 0.93, 0.94)
			mat.metallic = 0.5
			mat.roughness = 0.3
		"aluminum_dark":
			mat.albedo_color = Color(0.32, 0.33, 0.35)
			mat.metallic = 0.75
			mat.roughness = 0.35
		"aluminum_grate":
			mat.albedo_color = Color(0.7, 0.72, 0.75)
			mat.metallic = 0.9
			mat.roughness = 0.3
		"steel_plate":
			mat.albedo_color = Color(0.25, 0.26, 0.28)
			mat.metallic = 0.6
			mat.roughness = 0.4
		"stage_black_deck":
			mat.albedo_color = Color(0.12, 0.12, 0.13)
			mat.roughness = 0.88
			mat.metallic = 0.05
		"wood_natural":
			mat.albedo_color = Color(0.68, 0.52, 0.36)
			mat.roughness = 0.8
		"speaker_cabinet":
			mat.albedo_color = Color(0.14, 0.14, 0.15)
			mat.roughness = 0.78
			mat.metallic = 0.1
		"speaker_grille":
			mat.albedo_color = Color(0.22, 0.22, 0.24)
			mat.metallic = 0.45
			mat.roughness = 0.5
		"flight_case_black":
			mat.albedo_color = Color(0.1, 0.1, 0.11)
			mat.roughness = 0.65
		"flight_case_blue":
			mat.albedo_color = Color(0.12, 0.28, 0.65)
			mat.roughness = 0.6
		"flight_case_red":
			mat.albedo_color = Color(0.72, 0.15, 0.15)
			mat.roughness = 0.6
		"chrome_corner":
			mat.albedo_color = Color(0.9, 0.92, 0.95)
			mat.metallic = 0.95
			mat.roughness = 0.15
		"fixture_housing":
			mat.albedo_color = Color(0.15, 0.15, 0.16)
			mat.roughness = 0.45
			mat.metallic = 0.3
		"led_lens":
			mat.albedo_color = Color(0.2, 0.5, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.65, 1.0)
			mat.emission_energy_multiplier = 2.5
		"led_pixel_panel":
			mat.albedo_color = Color(0.06, 0.06, 0.07)
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.55, 0.95)
			mat.emission_energy_multiplier = 0.9
		"rubber_cable":
			mat.albedo_color = Color(0.16, 0.16, 0.18)
			mat.roughness = 0.92
		"ibc_plastic":
			mat.albedo_color = Color(0.85, 0.88, 0.9, 0.85)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.4
		"canopy_black":
			mat.albedo_color = Color(0.1, 0.1, 0.12)
			mat.roughness = 0.9
		"canopy_white":
			mat.albedo_color = Color(0.9, 0.9, 0.92)
			mat.roughness = 0.85
		"canopy_clear":
			mat.albedo_color = Color(0.85, 0.9, 0.95, 0.45)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.2
		"canopy_silver":
			mat.albedo_color = Color(0.7, 0.72, 0.75)
			mat.metallic = 0.5
			mat.roughness = 0.4
		"drape_black":
			mat.albedo_color = Color(0.08, 0.08, 0.09)
			mat.roughness = 0.95
		"drape_white":
			mat.albedo_color = Color(0.88, 0.88, 0.9)
			mat.roughness = 0.9
		"drape_burgundy":
			mat.albedo_color = Color(0.45, 0.08, 0.14)
			mat.roughness = 0.92
		"drum_shell_black":
			mat.albedo_color = Color(0.08, 0.08, 0.09)
			mat.roughness = 0.2
			mat.metallic = 0.3
		"drum_shell_white":
			mat.albedo_color = Color(0.92, 0.92, 0.94)
			mat.roughness = 0.2
			mat.metallic = 0.2
		"facade_white":
			mat.albedo_color = Color(0.95, 0.95, 0.98)
			mat.roughness = 0.25
			mat.metallic = 0.1
		"crowd_clothing":
			mat.albedo_color = Color(0.24, 0.3, 0.42)
			mat.roughness = 0.85
		"crowd_skin":
			mat.albedo_color = Color(0.78, 0.62, 0.52)
			mat.roughness = 0.6
		"plant_green":
			mat.albedo_color = Color(0.18, 0.38, 0.15)
			mat.roughness = 0.85
		"wood_trunk":
			mat.albedo_color = Color(0.38, 0.26, 0.18)
			mat.roughness = 0.9
		"safety_green":
			mat.albedo_color = Color(0.1, 0.85, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.85, 0.3)
			mat.emission_energy_multiplier = 1.2
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)

	_materials[mat_type] = mat
	return mat

static func create_mesh(generator_id: String, dims: Dictionary, variant_material: String = "") -> Node3D:
	var root := Node3D.new()
	var dx: float = float(dims.get("x", 1.0))
	var dy: float = float(dims.get("y", 1.0))
	var dz: float = float(dims.get("z", 1.0))

	# Dispatch by generator ID
	match generator_id:
		# --- Truss ---
		"gen_truss_box", "gen_truss_straight":
			_build_truss_box(root, dx, dy, dz, variant_material)
		"gen_truss_tri":
			_build_truss_tri(root, dx, dy, dz, variant_material)
		"gen_truss_corner_2way_90":
			_build_truss_corner_90(root, dx, dy, dz, variant_material)
		"gen_truss_corner_2way_angle":
			_build_truss_corner_angle(root, dx, dy, dz, variant_material)
		"gen_truss_junction_t":
			_build_truss_junction_t(root, dx, dy, dz, variant_material)
		"gen_truss_junction_cross":
			_build_truss_junction_cross(root, dx, dy, dz, variant_material)
		"gen_truss_corner_box", "gen_truss_corner":
			_build_truss_corner_box(root, dx, dy, dz, variant_material)
		"gen_truss_base_plate":
			_build_truss_base_plate(root, dx, dy, dz)
		"gen_truss_tower":
			_build_truss_tower(root, dx, dy, dz, variant_material)
		"gen_truss_sleeve_block":
			_build_truss_sleeve_block(root, dx, dy, dz, variant_material)
		"gen_truss_coupler":
			_build_truss_coupler(root, dx, dy, dz)

		# --- Roof & Structure ---
		"gen_roof_tower":
			_build_roof_tower(root, dx, dy, dz)
		"gen_stage_roof":
			_build_stage_roof(root, dx, dy, dz, variant_material)
		"gen_roof_wing":
			_build_roof_wing(root, dx, dy, dz)
		"gen_delay_tower":
			_build_delay_tower(root, dx, dy, dz)
		"gen_tent_structure":
			_build_tent_structure(root, dx, dy, dz, variant_material)
		"gen_scaffolding_standard":
			_build_scaffolding_standard(root, dx, dy, dz)
		"gen_scaffolding_bay":
			_build_scaffolding_bay(root, dx, dy, dz)
		"gen_scaffolding_stairs":
			_build_scaffolding_stairs(root, dx, dy, dz)

		# --- Rigging ---
		"gen_chain_hoist":
			_build_chain_hoist(root, dx, dy, dz)
		"gen_rigging_shackle":
			_build_rigging_shackle(root, dx, dy, dz)
		"gen_rigging_sling":
			_build_rigging_sling(root, dx, dy, dz)
		"gen_rigging_clamp":
			_build_rigging_clamp(root, dx, dy, dz)
		"gen_rigging_safety_cable":
			_build_rigging_safety_cable(root, dx, dy, dz)

		# --- Staging ---
		"gen_stage_deck":
			_build_stage_deck(root, dx, dy, dz, variant_material)
		"gen_stage_deck_tri":
			_build_stage_deck_tri(root, dx, dy, dz, variant_material)
		"gen_stage_deck_wedge":
			_build_stage_deck_wedge(root, dx, dy, dz, variant_material)
		"gen_stage_deck_rolling":
			_build_stage_deck_rolling(root, dx, dy, dz, variant_material)
		"gen_stage_platform_large":
			_build_stage_platform_large(root, dx, dy, dz, variant_material)
		"gen_stage_skirt":
			_build_stage_skirt(root, dx, dy, dz)
		"gen_stage_ramp":
			_build_stage_ramp(root, dx, dy, dz)
		"gen_stage_stairs":
			_build_stage_stairs(root, dx, dy, dz)
		"gen_stage_stairs_railed":
			_build_stage_stairs_railed(root, dx, dy, dz)
		"gen_crowd_barrier":
			_build_crowd_barrier(root, dx, dy, dz)
		"gen_crowd_barrier_corner":
			_build_crowd_barrier_corner(root, dx, dy, dz)
		"gen_crowd_barrier_gate":
			_build_crowd_barrier_gate(root, dx, dy, dz)

		# --- Audio ---
		"gen_audio_line_array":
			_build_audio_line_array(root, dx, dy, dz)
		"gen_audio_sub_single":
			_build_audio_sub_single(root, dx, dy, dz)
		"gen_audio_subwoofer":
			_build_audio_subwoofer(root, dx, dy, dz)
		"gen_audio_sub_cardioid":
			_build_audio_sub_cardioid(root, dx, dy, dz)
		"gen_audio_frontfill":
			_build_audio_frontfill(root, dx, dy, dz)
		"gen_audio_pole_stack":
			_build_audio_pole_stack(root, dx, dy, dz)
		"gen_audio_monitor":
			_build_audio_monitor(root, dx, dy, dz)
		"gen_audio_sidefill":
			_build_audio_sidefill(root, dx, dy, dz)
		"gen_audio_foh":
			_build_audio_foh(root, dx, dy, dz)
		"gen_flight_case_rack":
			_build_flight_case_rack(root, dx, dy, dz, variant_material)
		"gen_mic_stand":
			_build_mic_stand(root, dx, dy, dz)
		"gen_cable_ramp":
			_build_cable_ramp(root, dx, dy, dz)

		# --- Lighting ---
		"gen_lighting_moving_head":
			_build_lighting_moving_head(root, dx, dy, dz)
		"gen_lighting_par":
			_build_lighting_par(root, dx, dy, dz)
		"gen_lighting_bar":
			_build_lighting_bar(root, dx, dy, dz)
		"gen_lighting_strobe":
			_build_lighting_strobe(root, dx, dy, dz)
		"gen_lighting_blinder":
			_build_lighting_blinder(root, dx, dy, dz)
		"gen_lighting_followspot":
			_build_lighting_followspot(root, dx, dy, dz)
		"gen_lighting_console":
			_build_lighting_console(root, dx, dy, dz)
		"gen_lighting_prerig_truss":
			_build_lighting_prerig_truss(root, dx, dy, dz)
		"gen_fog_machine":
			_build_fog_machine(root, dx, dy, dz)

		# --- Video ---
		"gen_video_led_panel":
			_build_video_led_panel(root, dx, dy, dz)
		"gen_video_led_mesh":
			_build_video_led_mesh(root, dx, dy, dz)
		"gen_video_led_stack_frame":
			_build_video_led_stack_frame(root, dx, dy, dz)
		"gen_video_fastfold_screen":
			_build_video_fastfold_screen(root, dx, dy, dz)
		"gen_video_projector":
			_build_video_projector(root, dx, dy, dz)
		"gen_video_camera_tripod":
			_build_video_camera_tripod(root, dx, dy, dz)
		"gen_video_camera_crane":
			_build_video_camera_crane(root, dx, dy, dz)

		# --- Power ---
		"gen_power_distro":
			_build_power_distro(root, dx, dy, dz)
		"gen_generator":
			_build_generator(root, dx, dy, dz)
		"gen_ballast_tank":
			_build_ballast_tank(root, dx, dy, dz)
		"gen_ballast_concrete":
			_build_ballast_concrete(root, dx, dy, dz)
		"gen_cable_coil":
			_build_cable_coil(root, dx, dy, dz)

		# --- DJ & Backline ---
		"gen_dj_booth_curved":
			_build_dj_booth_curved(root, dx, dy, dz, variant_material)
		"gen_dj_table_folding":
			_build_dj_table_folding(root, dx, dy, dz)
		"gen_dj_setup":
			_build_dj_setup(root, dx, dy, dz)
		"gen_dj_mixer":
			_build_dj_mixer(root, dx, dy, dz)
		"gen_backline_drums":
			_build_backline_drums(root, dx, dy, dz, variant_material)
		"gen_backline_guitar_amp":
			_build_backline_guitar_amp(root, dx, dy, dz)
		"gen_backline_bass_amp":
			_build_backline_bass_amp(root, dx, dy, dz)
		"gen_backline_keyboard":
			_build_backline_keyboard(root, dx, dy, dz)
		"gen_backline_guitar_rack":
			_build_backline_guitar_rack(root, dx, dy, dz)
		"gen_backline_grand_piano":
			_build_backline_grand_piano(root, dx, dy, dz)
		"gen_backline_congas":
			_build_backline_congas(root, dx, dy, dz)

		# --- Environment ---
		"gen_stage_drape":
			_build_stage_drape(root, dx, dy, dz, variant_material)
		"gen_stage_starcloth":
			_build_stage_starcloth(root, dx, dy, dz)
		"gen_scrim_banner":
			_build_scrim_banner(root, dx, dy, dz)
		"gen_heras_fence":
			_build_heras_fence(root, dx, dy, dz)
		"gen_bikerack_barrier":
			_build_bikerack_barrier(root, dx, dy, dz)
		"gen_tree_prop":
			_build_tree_prop(root, dx, dy, dz)
		"gen_hedge_prop":
			_build_hedge_prop(root, dx, dy, dz)
		"gen_portable_toilet":
			_build_portable_toilet(root, dx, dy, dz)
		"gen_food_trailer":
			_build_food_trailer(root, dx, dy, dz)
		"gen_golf_cart":
			_build_golf_cart(root, dx, dy, dz)
		"gen_truck_trailer":
			_build_truck_trailer(root, dx, dy, dz)
		"gen_exit_sign":
			_build_exit_sign(root, dx, dy, dz)

		# --- Crowd ---
		"gen_crowd_figure":
			_build_crowd_figure(root, dx, dy, dz)
		"gen_crowd_figure_seated":
			_build_crowd_figure_seated(root, dx, dy, dz)
		"gen_crowd_multimesh_block":
			_build_crowd_multimesh(root, dx, dy, dz, 100)
		"gen_crowd_multimesh_block_50":
			_build_crowd_multimesh(root, dx, dy, dz, 50)
		"gen_crowd_multimesh_block_200":
			_build_crowd_multimesh(root, dx, dy, dz, 200)
		"gen_grandstand_row":
			_build_grandstand_row(root, dx, dy, dz)

		_:
			_build_fallback_box(root, dx, dy, dz)

	return root

# --- Helper Methods ---

static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	if rot != Vector3.ZERO:
		mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _add_cylinder(parent: Node3D, top_r: float, bot_r: float, height: float, pos: Vector3, mat: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = height
	cyl.radial_segments = 12
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	if rot != Vector3.ZERO:
		mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _build_fallback_box(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum"))

# --- 1. Truss Builders ---

static func _build_truss_box(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	var pipe_r := 0.024
	var half_x := (dx - pipe_r * 2) * 0.5
	var half_y := (dy - pipe_r * 2) * 0.5

	for ox in [-half_x, half_x]:
		for oy in [-half_y, half_y]:
			_add_cylinder(parent, pipe_r, pipe_r, dz, Vector3(ox, oy, 0), mat, Vector3(PI * 0.5, 0, 0))

	var segments := maxi(1, int(dz / 0.5))
	var seg_len := dz / float(segments)
	var brace_r := 0.01

	for s in range(segments):
		var z_start := -dz * 0.5 + float(s) * seg_len
		var z_mid := z_start + seg_len * 0.5
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, half_y, z_mid), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, -half_y, z_mid), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, brace_r, brace_r, dy - pipe_r * 2, Vector3(-half_x, 0, z_mid), mat)
		_add_cylinder(parent, brace_r, brace_r, dy - pipe_r * 2, Vector3(half_x, 0, z_mid), mat)

static func _build_truss_tri(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	var pipe_r := 0.024
	var half_x := (dx - pipe_r * 2) * 0.5

	# 3 main longitudinal chords: 2 at bottom, 1 at top apex
	_add_cylinder(parent, pipe_r, pipe_r, dz, Vector3(-half_x, -dy * 0.4, 0), mat, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, pipe_r, pipe_r, dz, Vector3(half_x, -dy * 0.4, 0), mat, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, pipe_r, pipe_r, dz, Vector3(0, dy * 0.4, 0), mat, Vector3(PI * 0.5, 0, 0))

	var segments := maxi(1, int(dz / 0.5))
	var seg_len := dz / float(segments)
	var brace_r := 0.01
	for s in range(segments):
		var z_mid := -dz * 0.5 + (float(s) + 0.5) * seg_len
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, -dy * 0.4, z_mid), mat, Vector3(0, 0, PI * 0.5))

static func _build_truss_corner_90(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx * 0.4, dy * 0.9, dz * 0.9), Vector3(dx * 0.25, 0, 0), mat)
	_add_box(parent, Vector3(dx * 0.9, dy * 0.9, dz * 0.4), Vector3(0, 0, -dz * 0.25), mat)

static func _build_truss_corner_angle(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx * 0.5, dy * 0.9, 0.29), Vector3(-dx * 0.2, 0, 0), mat)
	_add_box(parent, Vector3(dx * 0.5, dy * 0.9, 0.29), Vector3(dx * 0.2, 0, dz * 0.2), mat, Vector3(0, PI * 0.25, 0))

static func _build_truss_junction_t(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx, dy * 0.9, 0.29), Vector3(0, 0, 0), mat)
	_add_box(parent, Vector3(0.29, dy * 0.9, dz * 0.5), Vector3(0, 0, dz * 0.25), mat)

static func _build_truss_junction_cross(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx, dy * 0.9, 0.29), Vector3.ZERO, mat)
	_add_box(parent, Vector3(0.29, dy * 0.9, dz), Vector3.ZERO, mat)

static func _build_truss_corner_box(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx * 0.9, dy * 0.9, dz * 0.9), Vector3.ZERO, mat)
	var spigot_r := 0.03
	var hx := dx * 0.5
	var hy := dy * 0.5
	var hz := dz * 0.5
	var mat_sp := get_material("steel_plate")
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, 0, -hz), mat_sp, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, 0, hz), mat_sp, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(-hx, 0, 0), mat_sp, Vector3(0, 0, PI * 0.5))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(hx, 0, 0), mat_sp, Vector3(0, 0, PI * 0.5))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, -hy, 0), mat_sp)
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, hy, 0), mat_sp)

static func _build_truss_base_plate(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("steel_plate"))
	for ox in [-0.12, 0.12]:
		for oz in [-0.12, 0.12]:
			_add_cylinder(parent, 0.018, 0.018, 0.08, Vector3(ox, dy * 0.5 + 0.04, oz), get_material("aluminum"))

static func _build_truss_tower(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum_dark")
	var pipe_r := 0.03
	var hx := (dx - pipe_r * 2) * 0.5
	var hz := (dz - pipe_r * 2) * 0.5
	for ox in [-hx, hx]:
		for oz in [-hz, hz]:
			_add_cylinder(parent, pipe_r, pipe_r, dy, Vector3(ox, 0, oz), mat)
	var rungs := maxi(2, int(dy / 0.4))
	for r in range(rungs + 1):
		var y := -dy * 0.5 + float(r) * (dy / float(rungs))
		_add_cylinder(parent, 0.015, 0.015, dx, Vector3(0, y, hz), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, 0.015, 0.015, dx, Vector3(0, y, -hz), mat, Vector3(0, 0, PI * 0.5))

static func _build_truss_sleeve_block(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "aluminum")
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat)
	# Center guide rollers
	_add_box(parent, Vector3(dx * 0.7, dy * 1.05, dz * 0.7), Vector3.ZERO, get_material("rubber_cable"))

static func _build_truss_coupler(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.024, 0.024, dz, Vector3.ZERO, get_material("aluminum"), Vector3(PI * 0.5, 0, 0))

# --- 2. Roof & Structure Builders ---

static func _build_roof_tower(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum_dark")
	for ox in [-dx * 0.4, dx * 0.4]:
		for oz in [-dz * 0.4, dz * 0.4]:
			_add_cylinder(parent, 0.04, 0.04, dy, Vector3(ox, 0, oz), mat)
	# Heavy bottom outriggers
	_add_box(parent, Vector3(dx * 2.2, 0.1, 0.1), Vector3(0, -dy * 0.5 + 0.05, 0), get_material("steel_plate"))
	_add_box(parent, Vector3(0.1, 0.1, dz * 2.2), Vector3(0, -dy * 0.5 + 0.05, 0), get_material("steel_plate"))

static func _build_stage_roof(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat_canopy := get_material(var_mat if var_mat != "" else "canopy_black")
	var mat_truss := get_material("aluminum")

	# 4 Corner support pillars
	for ox in [-dx * 0.48, dx * 0.48]:
		for oz in [-dz * 0.48, dz * 0.48]:
			_add_cylinder(parent, 0.06, 0.06, dy * 0.7, Vector3(ox, -dy * 0.15, oz), mat_truss)

	# Perimeter roof truss grid
	_add_box(parent, Vector3(dx, 0.4, 0.4), Vector3(0, dy * 0.2, dz * 0.48), mat_truss)
	_add_box(parent, Vector3(dx, 0.4, 0.4), Vector3(0, dy * 0.2, -dz * 0.48), mat_truss)
	_add_box(parent, Vector3(0.4, 0.4, dz), Vector3(dx * 0.48, dy * 0.2, 0), mat_truss)
	_add_box(parent, Vector3(0.4, 0.4, dz), Vector3(-dx * 0.48, dy * 0.2, 0), mat_truss)

	# Pitched canopy roof skin
	_add_box(parent, Vector3(dx * 1.02, 0.1, dz * 1.02), Vector3(0, dy * 0.35, 0), mat_canopy)

static func _build_roof_wing(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat)

static func _build_delay_tower(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum_dark")
	_add_box(parent, Vector3(dx * 0.4, dy, dz * 0.4), Vector3.ZERO, mat)
	_add_box(parent, Vector3(dx, 0.1, dz), Vector3(0, -dy * 0.5 + 0.05, 0), get_material("steel_plate"))

static func _build_tent_structure(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat_canopy := get_material(var_mat if var_mat != "" else "canopy_white")
	var mat_frame := get_material("aluminum")
	# Frame posts
	for ox in [-dx * 0.48, dx * 0.48]:
		for oz in [-dz * 0.48, dz * 0.48]:
			_add_cylinder(parent, 0.03, 0.03, dy * 0.7, Vector3(ox, -dy * 0.15, oz), mat_frame)
	# Peak canopy
	_add_box(parent, Vector3(dx, 0.08, dz), Vector3(0, dy * 0.35, 0), mat_canopy)

static func _build_scaffolding_standard(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	_add_cylinder(parent, 0.024, 0.024, dy, Vector3.ZERO, mat)
	# Rosettes
	for i in range(int(dy / 0.5)):
		var y := -dy * 0.5 + float(i) * 0.5
		_add_cylinder(parent, 0.06, 0.06, 0.015, Vector3(0, y, 0), mat)

static func _build_scaffolding_bay(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	_add_box(parent, Vector3(dx, 0.06, dz), Vector3(0, dy * 0.5 - 0.03, 0), mat)
	for ox in [-dx * 0.48, dx * 0.48]:
		for oz in [-dz * 0.48, dz * 0.48]:
			_add_cylinder(parent, 0.024, 0.024, dy, Vector3(ox, 0, oz), mat)

static func _build_scaffolding_stairs(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	_build_scaffolding_bay(parent, dx, dy, dz)
	var steps := 8
	for i in range(steps):
		var y := -dy * 0.5 + (float(i) + 0.5) * (dy / float(steps))
		var z := -dz * 0.5 + (float(i) + 0.5) * (dz / float(steps))
		_add_box(parent, Vector3(dx * 0.8, 0.04, dz / float(steps)), Vector3(0, y, z), mat)

# --- 3. Rigging Builders ---

static func _build_chain_hoist(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_body := get_material("flight_case_black")
	var mat_hook := get_material("steel_plate")
	_add_cylinder(parent, dx * 0.35, dx * 0.35, dy * 0.5, Vector3(0, 0, 0), mat_body, Vector3(0, 0, PI * 0.5))
	_add_box(parent, Vector3(dx * 0.6, dy * 0.4, dz * 0.6), Vector3(0, -dy * 0.1, 0), get_material("fixture_housing"))
	# Top Hook & Bottom Chain Hook
	_add_cylinder(parent, 0.02, 0.02, dy * 0.25, Vector3(0, dy * 0.35, 0), mat_hook)
	_add_cylinder(parent, 0.02, 0.02, dy * 0.25, Vector3(0, -dy * 0.35, 0), mat_hook)

static func _build_rigging_shackle(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	_add_cylinder(parent, dx * 0.3, dx * 0.3, dy * 0.6, Vector3.ZERO, mat)
	_add_cylinder(parent, dx * 0.12, dx * 0.12, dx * 1.2, Vector3(0, -dy * 0.3, 0), get_material("plant_green"), Vector3(0, 0, PI * 0.5))

static func _build_rigging_sling(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.02, 0.02, dy, Vector3.ZERO, get_material("rubber_cable"))

static func _build_rigging_clamp(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("steel_plate"))

static func _build_rigging_safety_cable(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.005, 0.005, dy, Vector3.ZERO, get_material("chrome_corner"))

# --- 4. Staging Builders ---

static func _build_stage_deck(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat_deck := get_material(var_mat if var_mat != "" else "stage_black_deck")
	var mat_frame := get_material("aluminum")
	var deck_thickness := 0.09
	_add_box(parent, Vector3(dx - 0.04, 0.02, dz - 0.04), Vector3(0, dy * 0.5 - 0.01, 0), mat_deck)
	_add_box(parent, Vector3(dx, deck_thickness, 0.04), Vector3(0, dy * 0.5 - deck_thickness * 0.5, dz * 0.5 - 0.02), mat_frame)
	_add_box(parent, Vector3(dx, deck_thickness, 0.04), Vector3(0, dy * 0.5 - deck_thickness * 0.5, -dz * 0.5 + 0.02), mat_frame)
	_add_box(parent, Vector3(0.04, deck_thickness, dz - 0.08), Vector3(dx * 0.5 - 0.02, dy * 0.5 - deck_thickness * 0.5, 0), mat_frame)
	_add_box(parent, Vector3(0.04, deck_thickness, dz - 0.08), Vector3(-dx * 0.5 + 0.02, dy * 0.5 - deck_thickness * 0.5, 0), mat_frame)
	var leg_r := 0.03
	var leg_h := dy - deck_thickness
	for ox in [-dx * 0.5 + 0.06, dx * 0.5 - 0.06]:
		for oz in [-dz * 0.5 + 0.06, dz * 0.5 - 0.06]:
			_add_cylinder(parent, leg_r, leg_r, leg_h, Vector3(ox, -dy * 0.5 + leg_h * 0.5, oz), mat_frame)

static func _build_stage_deck_tri(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	_build_stage_deck(parent, dx, dy, dz, var_mat)

static func _build_stage_deck_wedge(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	_build_stage_deck(parent, dx, dy, dz, var_mat)

static func _build_stage_deck_rolling(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	_build_stage_deck(parent, dx, dy, dz, var_mat)
	for ox in [-dx * 0.4, dx * 0.4]:
		for oz in [-dz * 0.4, dz * 0.4]:
			_add_cylinder(parent, 0.05, 0.05, 0.04, Vector3(ox, -dy * 0.5 - 0.05, oz), get_material("rubber_cable"), Vector3(0, 0, PI * 0.5))

static func _build_stage_platform_large(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	_build_stage_deck(parent, dx, dy, dz, var_mat)

static func _build_stage_skirt(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("drape_black"))

static func _build_stage_ramp(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("stage_black_deck")
	_add_box(parent, Vector3(dx, 0.04, dz), Vector3(0, 0, 0), mat, Vector3(atan2(dy, dz), 0, 0))

static func _build_stage_stairs(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_deck := get_material("stage_black_deck")
	var num_steps := 4
	var step_h := dy / float(num_steps)
	var step_d := dz / float(num_steps)
	for i in range(num_steps):
		var y := -dy * 0.5 + (float(i) + 0.5) * step_h
		var z := -dz * 0.5 + (float(i) + 0.5) * step_d
		_add_box(parent, Vector3(dx, 0.04, step_d), Vector3(0, y, z), mat_deck)

static func _build_stage_stairs_railed(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_build_stage_stairs(parent, dx, dy * 0.6, dz)
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(-dx * 0.5, dy * 0.2, 0), get_material("steel_plate"))
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(dx * 0.5, dy * 0.2, 0), get_material("steel_plate"))

static func _build_crowd_barrier(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	_add_box(parent, Vector3(dx, dy * 0.9, 0.04), Vector3(0, 0.05, dz * 0.5 - 0.05), mat)
	_add_box(parent, Vector3(dx, 0.02, dz * 0.8), Vector3(0, -dy * 0.5 + 0.01, -0.05), mat)

static func _build_crowd_barrier_corner(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_build_crowd_barrier(parent, dx, dy, dz)

static func _build_crowd_barrier_gate(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_build_crowd_barrier(parent, dx, dy, dz)

# --- 5. Audio Builders ---

static func _build_audio_line_array(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cab := get_material("speaker_cabinet")
	var mat_grille := get_material("speaker_grille")
	_add_box(parent, Vector3(dx, dy * 0.95, dz * 0.8), Vector3(0, 0, dz * 0.1), mat_cab)
	_add_box(parent, Vector3(dx * 0.96, dy * 0.9, 0.02), Vector3(0, 0, -dz * 0.4), mat_grille)

static func _build_audio_sub_single(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.92, dy * 0.92, 0.02), Vector3(0, 0, -dz * 0.5 + 0.01), get_material("speaker_grille"))

static func _build_audio_subwoofer(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.94, dy * 0.92, 0.02), Vector3(0, 0, -dz * 0.5 + 0.02), get_material("speaker_grille"))

static func _build_audio_sub_cardioid(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var sub_h := dy / 3.0
	for i in range(3):
		var y := -dy * 0.5 + (float(i) + 0.5) * sub_h
		_add_box(parent, Vector3(dx, sub_h * 0.95, dz), Vector3(0, y, 0), get_material("speaker_cabinet"))

static func _build_audio_frontfill(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.95, dy * 0.9, 0.01), Vector3(0, 0, -dz * 0.5), get_material("speaker_grille"))

static func _build_audio_pole_stack(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Subwoofer on floor
	_add_box(parent, Vector3(dx, 0.6, dz), Vector3(0, -dy * 0.5 + 0.3, 0), get_material("speaker_cabinet"))
	# Distance rod
	_add_cylinder(parent, 0.02, 0.02, 1.2, Vector3(0, 0.2, 0), get_material("steel_plate"))
	# Top satellite speaker
	_add_box(parent, Vector3(dx * 0.65, 0.6, dz * 0.6), Vector3(0, dy * 0.5 - 0.3, 0), get_material("speaker_cabinet"))

static func _build_audio_monitor(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.6, dz * 0.8), Vector3(0, -dy * 0.2, dz * 0.1), get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.92, dy * 0.8, 0.02), Vector3(0, dy * 0.1, -dz * 0.15), get_material("speaker_grille"), Vector3(-PI * 0.25, 0, 0))

static func _build_audio_sidefill(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.5, dz), Vector3(0, -dy * 0.25, 0), get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.9, dy * 0.45, dz * 0.85), Vector3(0, dy * 0.25, 0), get_material("speaker_cabinet"))

static func _build_audio_foh(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, 0.1, dz), Vector3(0, -dy * 0.45, 0), get_material("flight_case_black"))
	_add_box(parent, Vector3(dx * 0.96, 0.08, dz * 0.5), Vector3(0, -0.1, 0.15), get_material("aluminum_dark"), Vector3(PI * 0.08, 0, 0))
	_add_box(parent, Vector3(dx * 0.8, dy * 0.35, 0.04), Vector3(0, dy * 0.15, -dz * 0.2), get_material("led_lens"), Vector3(-PI * 0.15, 0, 0))

static func _build_flight_case_rack(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat_case := get_material(var_mat if var_mat != "" else "flight_case_black")
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_case)
	_add_box(parent, Vector3(dx * 0.82, dy * 0.86, 0.02), Vector3(0, 0, -dz * 0.5 + 0.01), get_material("aluminum_dark"))
	# Chrome edges
	var cr := 0.04
	for ox in [-dx * 0.5, dx * 0.5]:
		for oy in [-dy * 0.5, dy * 0.5]:
			for oz in [-dz * 0.5, dz * 0.5]:
				_add_box(parent, Vector3(cr, cr, cr), Vector3(ox, oy, oz), get_material("chrome_corner"))

static func _build_mic_stand(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	_add_cylinder(parent, 0.012, 0.012, dy * 0.7, Vector3(0, -dy * 0.15, 0), mat)
	_add_cylinder(parent, 0.008, 0.008, 0.7, Vector3(0, dy * 0.25, 0.2), mat, Vector3(PI * 0.25, 0, 0))
	_add_cylinder(parent, dx * 0.45, dx * 0.45, 0.02, Vector3(0, -dy * 0.5, 0), mat)

static func _build_cable_ramp(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("rubber_cable"))
	# Yellow lid stripe
	_add_box(parent, Vector3(dx, dy * 0.2, dz * 0.5), Vector3(0, dy * 0.45, 0), get_material("safety_green"))

# --- 6. Lighting Builders ---

static func _build_lighting_moving_head(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_base := get_material("fixture_housing")
	_add_box(parent, Vector3(dx * 0.8, 0.12, dz * 0.8), Vector3(0, -dy * 0.5 + 0.06, 0), mat_base)
	_add_cylinder(parent, 0.035, 0.035, dy * 0.45, Vector3(-dx * 0.32, -dy * 0.15, 0), mat_base)
	_add_cylinder(parent, 0.035, 0.035, dy * 0.45, Vector3(dx * 0.32, -dy * 0.15, 0), mat_base)
	_add_cylinder(parent, 0.12, 0.14, dy * 0.42, Vector3(0, dy * 0.12, 0), mat_base)
	_add_cylinder(parent, 0.1, 0.1, 0.02, Vector3(0, dy * 0.33 + 0.01, 0), get_material("led_lens"))

static func _build_lighting_par(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, dx * 0.4, dx * 0.35, dy * 0.65, Vector3.ZERO, get_material("aluminum_dark"))
	_add_cylinder(parent, dx * 0.38, dx * 0.38, 0.02, Vector3(0, dy * 0.33, 0), get_material("led_lens"))

static func _build_lighting_bar(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum_dark"))
	for i in range(12):
		var ox := -dx * 0.5 + 0.04 + (float(i) + 0.5) * ((dx - 0.08) / 12.0)
		_add_cylinder(parent, 0.02, 0.02, 0.015, Vector3(ox, 0, dz * 0.5 + 0.008), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_lighting_strobe(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("fixture_housing"))
	_add_box(parent, Vector3(dx * 0.95, dy * 0.9, 0.01), Vector3(0, 0, dz * 0.5), get_material("led_lens"))

static func _build_lighting_blinder(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("fixture_housing"))
	_add_cylinder(parent, 0.08, 0.08, 0.02, Vector3(-dx * 0.25, 0, dz * 0.5), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, 0.08, 0.08, 0.02, Vector3(dx * 0.25, 0, dz * 0.5), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_lighting_followspot(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.15, 0.12, dz * 0.7, Vector3(0, dy * 0.25, 0), get_material("fixture_housing"), Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, 0.03, 0.03, dy * 0.6, Vector3(0, -dy * 0.2, 0), get_material("steel_plate"))

static func _build_lighting_console(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, 0.1, dz), Vector3(0, -dy * 0.4, 0), get_material("flight_case_black"))
	_add_box(parent, Vector3(dx * 0.8, dy * 0.4, 0.04), Vector3(0, dy * 0.15, -dz * 0.2), get_material("led_lens"), Vector3(-PI * 0.15, 0, 0))

static func _build_lighting_prerig_truss(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_build_truss_box(parent, dx, dy, dz)
	# Internal fixture bar
	_add_cylinder(parent, 0.02, 0.02, dz * 0.9, Vector3(0, 0, 0), get_material("aluminum_dark"), Vector3(PI * 0.5, 0, 0))

static func _build_fog_machine(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("fixture_housing"))
	_add_cylinder(parent, 0.05, 0.05, 0.04, Vector3(0, 0, dz * 0.5 + 0.02), get_material("steel_plate"), Vector3(PI * 0.5, 0, 0))

# --- 7. Video Builders ---

static func _build_video_led_panel(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz * 0.5), Vector3(0, 0, -dz * 0.25), get_material("aluminum_dark"))
	_add_box(parent, Vector3(dx * 0.98, dy * 0.98, 0.01), Vector3(0, 0, dz * 0.5 - 0.005), get_material("led_pixel_panel"))

static func _build_video_led_mesh(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("canopy_clear"))
	_add_box(parent, Vector3(dx, 0.04, dz * 1.5), Vector3(0, dy * 0.5, 0), get_material("aluminum"))

static func _build_video_led_stack_frame(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(0.08, dy, 0.08), Vector3(0, 0, 0), get_material("steel_plate"))
	_add_box(parent, Vector3(dx, 0.06, dz), Vector3(0, -dy * 0.5 + 0.03, dz * 0.3), get_material("steel_plate"))

static func _build_video_fastfold_screen(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.75, 0.02), Vector3(0, dy * 0.1, 0), get_material("canopy_white"))
	_add_box(parent, Vector3(dx + 0.15, dy * 0.75 + 0.15, 0.04), Vector3(0, dy * 0.1, -0.02), get_material("drape_black"))
	# Support legs
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(-dx * 0.5, -dy * 0.1, 0), get_material("aluminum"))
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(dx * 0.5, -dy * 0.1, 0), get_material("aluminum"))

static func _build_video_projector(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum_white"))
	_add_cylinder(parent, 0.08, 0.08, 0.06, Vector3(dx * 0.25, 0, -dz * 0.5 - 0.03), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_video_camera_tripod(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Tripod
	_add_cylinder(parent, 0.02, dx * 0.45, dy * 0.65, Vector3(0, -dy * 0.15, 0), get_material("steel_plate"))
	# Camera body
	_add_box(parent, Vector3(0.2, 0.22, 0.45), Vector3(0, dy * 0.3, 0), get_material("fixture_housing"))
	# Lens
	_add_cylinder(parent, 0.06, 0.07, 0.2, Vector3(0, dy * 0.3, -0.32), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_video_camera_crane(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.04, 0.04, dy * 0.5, Vector3(0, -dy * 0.25, 0), get_material("steel_plate"))
	_add_box(parent, Vector3(0.12, 0.12, dz), Vector3(0, dy * 0.1, dz * 0.2), get_material("aluminum_dark"), Vector3(-0.15, 0, 0))

# --- 8. Power Builders ---

static func _build_power_distro(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("rubber_cable"))
	_add_box(parent, Vector3(dx * 0.85, dy * 0.85, 0.02), Vector3(0, 0, -dz * 0.5 + 0.01), get_material("aluminum_dark"))

static func _build_generator(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.85, dz), Vector3(0, 0.05, 0), get_material("plant_green"))
	# Exhaust and louvers
	_add_cylinder(parent, 0.08, 0.08, 0.2, Vector3(dx * 0.3, dy * 0.5 + 0.1, 0), get_material("steel_plate"))

static func _build_ballast_tank(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx * 0.9, dy * 0.88, dz * 0.9), Vector3(0, 0.02, 0), get_material("ibc_plastic"))
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum"))

static func _build_ballast_concrete(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("steel_plate"))
	_add_cylinder(parent, 0.02, 0.02, 0.15, Vector3(0, dy * 0.5 + 0.075, 0), get_material("plant_green"))

static func _build_cable_coil(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = dx * 0.25
	torus.outer_radius = dx * 0.45
	torus.material = get_material("rubber_cable")
	mi.mesh = torus
	parent.add_child(mi)

# --- 9. DJ & Backline Builders ---

static func _build_dj_booth_curved(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "facade_white")
	_add_box(parent, Vector3(dx, dy, dz * 0.6), Vector3(0, 0, 0), mat)
	_add_box(parent, Vector3(dx * 0.9, 0.04, dz * 0.7), Vector3(0, dy * 0.4, 0), get_material("stage_black_deck"))

static func _build_dj_table_folding(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, 0.04, dz), Vector3(0, dy * 0.5, 0), get_material("stage_black_deck"))
	_add_box(parent, Vector3(dx * 0.95, dy * 0.95, 0.03), Vector3(0, 0, 0), get_material("aluminum"))

static func _build_dj_setup(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.5, dz), Vector3(0, -dy * 0.25, 0), get_material("flight_case_black"))
	var num_players := 4
	var deck_w := (dx - 0.1) / float(num_players)
	for i in range(num_players):
		var ox := -dx * 0.5 + 0.05 + (float(i) + 0.5) * deck_w
		_add_box(parent, Vector3(deck_w * 0.92, 0.06, dz * 0.9), Vector3(ox, 0.03, 0), get_material("aluminum_dark"))
		_add_cylinder(parent, deck_w * 0.35, deck_w * 0.35, 0.015, Vector3(ox, 0.07, dz * 0.1), get_material("chrome_corner"))

static func _build_dj_mixer(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum_dark"))

static func _build_backline_drums(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat_shell := get_material(var_mat if var_mat != "" else "drum_shell_black")
	var mat_head := get_material("canopy_white")
	var mat_cymbal := get_material("chrome_corner")

	# Bass drum
	_add_cylinder(parent, 0.28, 0.28, 0.45, Vector3(0, 0.3, 0), mat_shell, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, 0.27, 0.27, 0.01, Vector3(0, 0.3, 0.23), mat_head, Vector3(PI * 0.5, 0, 0))
	# Snare
	_add_cylinder(parent, 0.18, 0.18, 0.16, Vector3(-0.35, 0.65, 0.15), mat_shell)
	# Hi-hat & Ride cymbals
	_add_cylinder(parent, 0.22, 0.22, 0.005, Vector3(-0.6, 0.95, 0.1), mat_cymbal)
	_add_cylinder(parent, 0.26, 0.26, 0.005, Vector3(0.65, 0.95, -0.1), mat_cymbal)

static func _build_backline_guitar_amp(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.65, dz), Vector3(0, -dy * 0.15, 0), get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.95, dy * 0.3, dz * 0.9), Vector3(0, dy * 0.35, 0), get_material("flight_case_black"))

static func _build_backline_bass_amp(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.8, dz), Vector3(0, -dy * 0.1, 0), get_material("speaker_cabinet"))
	_add_box(parent, Vector3(dx * 0.9, dy * 0.18, dz * 0.85), Vector3(0, dy * 0.4, 0), get_material("aluminum_dark"))

static func _build_backline_keyboard(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, 0.08, dz * 0.7), Vector3(0, dy * 0.45, 0), get_material("aluminum_dark"))
	# X-stand
	_add_box(parent, Vector3(dx * 0.8, dy * 0.9, 0.04), Vector3(0, 0, 0), get_material("steel_plate"))

static func _build_backline_guitar_rack(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("rubber_cable"))

static func _build_backline_grand_piano(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.45, dz), Vector3(0, dy * 0.25, 0), get_material("flight_case_black"))
	# 3 Legs
	_add_cylinder(parent, 0.04, 0.04, dy * 0.55, Vector3(-dx * 0.4, -dy * 0.22, dz * 0.4), get_material("flight_case_black"))
	_add_cylinder(parent, 0.04, 0.04, dy * 0.55, Vector3(dx * 0.4, -dy * 0.22, dz * 0.4), get_material("flight_case_black"))
	_add_cylinder(parent, 0.04, 0.04, dy * 0.55, Vector3(0, -dy * 0.22, -dz * 0.4), get_material("flight_case_black"))

static func _build_backline_congas(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_cylinder(parent, 0.15, 0.1, dy * 0.6, Vector3(-dx * 0.25, dy * 0.15, 0), get_material("wood_natural"))
	_add_cylinder(parent, 0.16, 0.11, dy * 0.6, Vector3(dx * 0.25, dy * 0.15, 0), get_material("wood_natural"))

# --- 10. Environment Builders ---

static func _build_stage_drape(parent: Node3D, dx: float, dy: float, dz: float, var_mat: String = "") -> void:
	var mat := get_material(var_mat if var_mat != "" else "drape_black")
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat)

static func _build_stage_starcloth(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("drape_black"))
	for i in range(16):
		var rx := (randf() - 0.5) * dx * 0.9
		var ry := (randf() - 0.5) * dy * 0.9
		_add_cylinder(parent, 0.015, 0.015, 0.01, Vector3(rx, ry, dz * 0.5 + 0.005), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_scrim_banner(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("drape_black"))

static func _build_heras_fence(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	# Frame
	_add_cylinder(parent, 0.02, 0.02, dy, Vector3(-dx * 0.5, 0, 0), mat)
	_add_cylinder(parent, 0.02, 0.02, dy, Vector3(dx * 0.5, 0, 0), mat)
	_add_cylinder(parent, 0.02, 0.02, dx, Vector3(0, dy * 0.5, 0), mat, Vector3(0, 0, PI * 0.5))
	_add_cylinder(parent, 0.02, 0.02, dx, Vector3(0, -dy * 0.5, 0), mat, Vector3(0, 0, PI * 0.5))
	# Mesh fill
	_add_box(parent, Vector3(dx * 0.96, dy * 0.96, 0.01), Vector3.ZERO, get_material("canopy_clear"))
	# Concrete base feet
	_add_box(parent, Vector3(0.2, 0.12, dz), Vector3(-dx * 0.5, -dy * 0.5 + 0.06, 0), mat)
	_add_box(parent, Vector3(0.2, 0.12, dz), Vector3(dx * 0.5, -dy * 0.5 + 0.06, 0), mat)

static func _build_bikerack_barrier(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	_add_box(parent, Vector3(dx, dy * 0.9, 0.03), Vector3(0, 0.05, 0), mat)
	_add_box(parent, Vector3(0.04, 0.04, dz), Vector3(-dx * 0.45, -dy * 0.5 + 0.02, 0), mat)
	_add_box(parent, Vector3(0.04, 0.04, dz), Vector3(dx * 0.45, -dy * 0.5 + 0.02, 0), mat)

static func _build_tree_prop(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Planter pot
	_add_cylinder(parent, dx * 0.3, dx * 0.25, 0.5, Vector3(0, -dy * 0.5 + 0.25, 0), get_material("fixture_housing"))
	# Trunk
	_add_cylinder(parent, 0.06, 0.08, dy * 0.6, Vector3(0, -dy * 0.1, 0), get_material("wood_trunk"))
	# Foliage
	_add_cylinder(parent, dx * 0.45, dx * 0.45, dy * 0.5, Vector3(0, dy * 0.25, 0), get_material("plant_green"))

static func _build_hedge_prop(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.3, dz), Vector3(0, -dy * 0.35, 0), get_material("fixture_housing"))
	_add_box(parent, Vector3(dx * 0.95, dy * 0.7, dz * 0.9), Vector3(0, dy * 0.15, 0), get_material("plant_green"))

static func _build_portable_toilet(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("flight_case_blue"))
	_add_box(parent, Vector3(dx * 0.9, dy * 0.1, dz * 0.9), Vector3(0, dy * 0.45, 0), get_material("canopy_white"))

static func _build_food_trailer(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum_white"))
	_add_box(parent, Vector3(dx * 0.6, dy * 0.4, 0.02), Vector3(0, 0.1, dz * 0.5), get_material("stage_black_deck"))

static func _build_golf_cart(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.4, dz), Vector3(0, -dy * 0.2, 0), get_material("canopy_white"))
	_add_box(parent, Vector3(dx * 0.8, dy * 0.05, dz * 0.9), Vector3(0, dy * 0.45, 0), get_material("canopy_white"))

static func _build_truck_trailer(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy * 0.8, dz), Vector3(0, dy * 0.1, 0), get_material("aluminum_white"))
	# Wheels chassis
	_add_box(parent, Vector3(dx * 0.9, 0.3, dz * 0.8), Vector3(0, -dy * 0.35, 0), get_material("steel_plate"))

static func _build_exit_sign(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("safety_green"))

# --- 11. Crowd Builders ---

static func _build_crowd_figure(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx * 0.8, dy * 0.45, dz * 0.8), Vector3(0, -dy * 0.25, 0), get_material("crowd_clothing"))
	_add_box(parent, Vector3(dx, dy * 0.35, dz), Vector3(0, dy * 0.15, 0), get_material("crowd_clothing"))
	_add_cylinder(parent, dx * 0.25, dx * 0.25, dy * 0.18, Vector3(0, dy * 0.42, 0), get_material("crowd_skin"))

static func _build_crowd_figure_seated(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Chair
	_add_box(parent, Vector3(dx, dy * 0.4, dz * 0.8), Vector3(0, -dy * 0.25, 0), get_material("flight_case_blue"))
	# Torso
	_add_box(parent, Vector3(dx * 0.9, dy * 0.4, dz * 0.4), Vector3(0, dy * 0.15, -dz * 0.15), get_material("crowd_clothing"))
	# Head
	_add_cylinder(parent, dx * 0.22, dx * 0.22, dy * 0.18, Vector3(0, dy * 0.42, -dz * 0.15), get_material("crowd_skin"))

static func _build_crowd_multimesh(parent: Node3D, dx: float, dy: float, dz: float, count: int) -> void:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count

	var figure_mesh := BoxMesh.new()
	figure_mesh.size = Vector3(0.4, 1.75, 0.3)
	figure_mesh.material = get_material("crowd_clothing")
	mm.mesh = figure_mesh

	var side := int(sqrt(float(count)))
	var idx := 0
	for r in range(side):
		for c in range(side):
			if idx >= count:
				break
			var x := -dx * 0.5 + (float(c) + 0.5) * (dx / float(side)) + (randf() - 0.5) * 0.2
			var z := -dz * 0.5 + (float(r) + 0.5) * (dz / float(side)) + (randf() - 0.5) * 0.2
			var t := Transform3D()
			t = t.rotated(Vector3.UP, (randf() - 0.5) * 0.5)
			t.origin = Vector3(x, -dy * 0.5 + 1.75 * 0.5, z)
			mm.set_instance_transform(idx, t)
			idx += 1

	mmi.multimesh = mm
	parent.add_child(mmi)

static func _build_grandstand_row(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Bleacher frame
	_add_box(parent, Vector3(dx, 0.08, dz), Vector3(0, -dy * 0.45, 0), get_material("aluminum"))
	# 10 Stadium seats
	var seat_w := dx / 10.0
	for i in range(10):
		var ox := -dx * 0.5 + (float(i) + 0.5) * seat_w
		_add_box(parent, Vector3(seat_w * 0.85, 0.08, dz * 0.7), Vector3(ox, -dy * 0.15, 0), get_material("flight_case_blue"))
		_add_box(parent, Vector3(seat_w * 0.85, dy * 0.5, 0.06), Vector3(ox, dy * 0.15, -dz * 0.3), get_material("flight_case_blue"))
