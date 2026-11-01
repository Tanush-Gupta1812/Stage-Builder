class_name MeshGenerators
extends RefCounted

## Procedural 3D mesh builder for all Stage-Builder production equipment.
## Generates clean, recognizable, primitive-based models with shared PBR materials.

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
		"aluminum_dark":
			mat.albedo_color = Color(0.35, 0.36, 0.38)
			mat.metallic = 0.75
			mat.roughness = 0.35
		"steel_plate":
			mat.albedo_color = Color(0.25, 0.26, 0.28)
			mat.metallic = 0.6
			mat.roughness = 0.4
		"stage_black_deck":
			mat.albedo_color = Color(0.12, 0.12, 0.13)
			mat.roughness = 0.85
			mat.metallic = 0.05
		"speaker_cabinet":
			mat.albedo_color = Color(0.14, 0.14, 0.15)
			mat.roughness = 0.75
			mat.metallic = 0.1
		"speaker_grille":
			mat.albedo_color = Color(0.2, 0.2, 0.22)
			mat.metallic = 0.4
			mat.roughness = 0.5
		"flight_case_black":
			mat.albedo_color = Color(0.1, 0.1, 0.11)
			mat.roughness = 0.65
		"chrome_corner":
			mat.albedo_color = Color(0.9, 0.92, 0.95)
			mat.metallic = 0.95
			mat.roughness = 0.15
		"fixture_housing":
			mat.albedo_color = Color(0.15, 0.15, 0.16)
			mat.roughness = 0.45
			mat.metallic = 0.3
		"led_lens":
			mat.albedo_color = Color(0.2, 0.4, 0.8)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.6, 1.0)
			mat.emission_energy_multiplier = 2.0
		"led_pixel_panel":
			mat.albedo_color = Color(0.08, 0.08, 0.09)
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.5, 0.9)
			mat.emission_energy_multiplier = 0.8
		"rubber_cable":
			mat.albedo_color = Color(0.18, 0.18, 0.2)
			mat.roughness = 0.9
		"ibc_plastic":
			mat.albedo_color = Color(0.85, 0.87, 0.88, 0.8)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.4
		"crowd_clothing":
			mat.albedo_color = Color(0.25, 0.32, 0.42)
			mat.roughness = 0.8
		"crowd_skin":
			mat.albedo_color = Color(0.78, 0.62, 0.52)
			mat.roughness = 0.6
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5)

	_materials[mat_type] = mat
	return mat

static func create_mesh(generator_id: String, dims: Dictionary) -> Node3D:
	var root := Node3D.new()
	var dx: float = float(dims.get("x", 1.0))
	var dy: float = float(dims.get("y", 1.0))
	var dz: float = float(dims.get("z", 1.0))

	match generator_id:
		"gen_truss_straight":
			_build_truss_straight(root, dx, dy, dz)
		"gen_truss_corner":
			_build_truss_corner(root, dx, dy, dz)
		"gen_truss_tower":
			_build_truss_tower(root, dx, dy, dz)
		"gen_truss_base_plate":
			_build_truss_base_plate(root, dx, dy, dz)
		"gen_stage_deck":
			_build_stage_deck(root, dx, dy, dz)
		"gen_stage_stairs":
			_build_stage_stairs(root, dx, dy, dz)
		"gen_stage_handrail":
			_build_stage_handrail(root, dx, dy, dz)
		"gen_crowd_barrier":
			_build_crowd_barrier(root, dx, dy, dz)
		"gen_audio_line_array":
			_build_audio_line_array(root, dx, dy, dz)
		"gen_audio_subwoofer":
			_build_audio_subwoofer(root, dx, dy, dz)
		"gen_audio_monitor":
			_build_audio_monitor(root, dx, dy, dz)
		"gen_audio_foh":
			_build_audio_foh(root, dx, dy, dz)
		"gen_flight_case_rack":
			_build_flight_case_rack(root, dx, dy, dz)
		"gen_lighting_moving_head":
			_build_lighting_moving_head(root, dx, dy, dz)
		"gen_lighting_par":
			_build_lighting_par(root, dx, dy, dz)
		"gen_lighting_bar":
			_build_lighting_bar(root, dx, dy, dz)
		"gen_video_led_panel":
			_build_video_led_panel(root, dx, dy, dz)
		"gen_power_distro":
			_build_power_distro(root, dx, dy, dz)
		"gen_ballast_tank":
			_build_ballast_tank(root, dx, dy, dz)
		"gen_dj_booth":
			_build_dj_booth(root, dx, dy, dz)
		"gen_dj_setup":
			_build_dj_setup(root, dx, dy, dz)
		"gen_crowd_figure":
			_build_crowd_figure(root, dx, dy, dz)
		"gen_crowd_multimesh_block":
			_build_crowd_multimesh_block(root, dx, dy, dz)
		_:
			_build_fallback_box(root, dx, dy, dz)

	return root

# --- Helper to add primitive MeshInstance3D ---
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

# --- Builders ---

static func _build_fallback_box(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, get_material("aluminum"))

static func _build_truss_straight(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	var pipe_r := 0.024
	var half_x := (dx - pipe_r * 2) * 0.5
	var half_y := (dy - pipe_r * 2) * 0.5

	# 4 main longitudinal chords (running along Z)
	for ox in [-half_x, half_x]:
		for oy in [-half_y, half_y]:
			_add_cylinder(parent, pipe_r, pipe_r, dz, Vector3(ox, oy, 0), mat, Vector3(PI * 0.5, 0, 0))

	# Cross/diagonal lacing bars
	var segments := maxi(1, int(dz / 0.5))
	var seg_len := dz / float(segments)
	var brace_r := 0.01

	for s in range(segments):
		var z_start := -dz * 0.5 + float(s) * seg_len
		var z_mid := z_start + seg_len * 0.5

		# Top & bottom horizontal cross-bars
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, half_y, z_mid), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, -half_y, z_mid), mat, Vector3(0, 0, PI * 0.5))
		# Left & right vertical cross-bars
		_add_cylinder(parent, brace_r, brace_r, dy - pipe_r * 2, Vector3(-half_x, 0, z_mid), mat)
		_add_cylinder(parent, brace_r, brace_r, dy - pipe_r * 2, Vector3(half_x, 0, z_mid), mat)

static func _build_truss_corner(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	var mat_spigot := get_material("steel_plate")

	# Central cube body
	_add_box(parent, Vector3(dx * 0.9, dy * 0.9, dz * 0.9), Vector3.ZERO, mat)

	# 6 face connecting plates / spigots
	var spigot_r := 0.03
	var hx := dx * 0.5
	var hy := dy * 0.5
	var hz := dz * 0.5
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, 0, -hz), mat_spigot, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, 0, hz), mat_spigot, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(-hx, 0, 0), mat_spigot, Vector3(0, 0, PI * 0.5))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(hx, 0, 0), mat_spigot, Vector3(0, 0, PI * 0.5))
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, -hy, 0), mat_spigot)
	_add_cylinder(parent, spigot_r, spigot_r, 0.04, Vector3(0, hy, 0), mat_spigot)

static func _build_truss_tower(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum_dark")
	var pipe_r := 0.03
	var half_x := (dx - pipe_r * 2) * 0.5
	var half_z := (dz - pipe_r * 2) * 0.5

	# 4 vertical columns running along Y
	for ox in [-half_x, half_x]:
		for oz in [-half_z, half_z]:
			_add_cylinder(parent, pipe_r, pipe_r, dy, Vector3(ox, 0, oz), mat)

	# Tower ladders and horizontal rungs
	var rungs := maxi(2, int(dy / 0.4))
	var rung_step := dy / float(rungs)
	var brace_r := 0.015
	for r in range(rungs + 1):
		var y_pos := -dy * 0.5 + float(r) * rung_step
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, y_pos, half_z), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, brace_r, brace_r, dx - pipe_r * 2, Vector3(0, y_pos, -half_z), mat, Vector3(0, 0, PI * 0.5))
		_add_cylinder(parent, brace_r, brace_r, dz - pipe_r * 2, Vector3(half_x, y_pos, 0), mat, Vector3(PI * 0.5, 0, 0))
		_add_cylinder(parent, brace_r, brace_r, dz - pipe_r * 2, Vector3(-half_x, y_pos, 0), mat, Vector3(PI * 0.5, 0, 0))

static func _build_truss_base_plate(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_plate := get_material("steel_plate")
	var mat_spigot := get_material("aluminum")

	# Heavy steel plate
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_plate)

	# Central truss mounting spigots (30cm and 40cm mounting points)
	var pin_r := 0.018
	for ox in [-0.12, 0.12]:
		for oz in [-0.12, 0.12]:
			_add_cylinder(parent, pin_r, pin_r, 0.08, Vector3(ox, dy * 0.5 + 0.04, oz), mat_spigot)

static func _build_stage_deck(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_frame := get_material("aluminum")
	var mat_deck := get_material("stage_black_deck")
	var deck_thickness := 0.09

	# Top phenolic black plywood deck surface
	_add_box(parent, Vector3(dx - 0.04, 0.02, dz - 0.04), Vector3(0, dy * 0.5 - 0.01, 0), mat_deck)

	# Aluminum extrusion perimeter frame
	_add_box(parent, Vector3(dx, deck_thickness, 0.04), Vector3(0, dy * 0.5 - deck_thickness * 0.5, dz * 0.5 - 0.02), mat_frame)
	_add_box(parent, Vector3(dx, deck_thickness, 0.04), Vector3(0, dy * 0.5 - deck_thickness * 0.5, -dz * 0.5 + 0.02), mat_frame)
	_add_box(parent, Vector3(0.04, deck_thickness, dz - 0.08), Vector3(dx * 0.5 - 0.02, dy * 0.5 - deck_thickness * 0.5, 0), mat_frame)
	_add_box(parent, Vector3(0.04, deck_thickness, dz - 0.08), Vector3(-dx * 0.5 + 0.02, dy * 0.5 - deck_thickness * 0.5, 0), mat_frame)

	# 4 corner telescopic legs
	var leg_r := 0.03
	var leg_height := dy - deck_thickness
	var leg_y := -dy * 0.5 + leg_height * 0.5
	for ox in [-dx * 0.5 + 0.06, dx * 0.5 - 0.06]:
		for oz in [-dz * 0.5 + 0.06, dz * 0.5 - 0.06]:
			_add_cylinder(parent, leg_r, leg_r, leg_height, Vector3(ox, leg_y, oz), mat_frame)
			# Rubber foot
			_add_cylinder(parent, leg_r * 1.2, leg_r * 1.2, 0.02, Vector3(ox, -dy * 0.5 + 0.01, oz), get_material("rubber_cable"))

static func _build_stage_stairs(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_deck := get_material("stage_black_deck")
	var mat_frame := get_material("aluminum")
	var num_steps := 4
	var step_h := dy / float(num_steps)
	var step_d := dz / float(num_steps)

	for i in range(num_steps):
		var y := -dy * 0.5 + (float(i) + 0.5) * step_h
		var z := -dz * 0.5 + (float(i) + 0.5) * step_d
		_add_box(parent, Vector3(dx, 0.04, step_d), Vector3(0, y, z), mat_deck)
		_add_box(parent, Vector3(dx, step_h, 0.02), Vector3(0, y - step_h * 0.5 + 0.02, z + step_d * 0.5), mat_frame)

static func _build_stage_handrail(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("steel_plate")
	var pipe_r := 0.02

	# Top rail
	_add_cylinder(parent, pipe_r, pipe_r, dx, Vector3(0, dy * 0.5 - pipe_r, 0), mat, Vector3(0, 0, PI * 0.5))
	# Mid rail
	_add_cylinder(parent, pipe_r * 0.8, pipe_r * 0.8, dx, Vector3(0, 0.0, 0), mat, Vector3(0, 0, PI * 0.5))
	# Vertical posts
	for ox in [-dx * 0.5 + 0.05, 0.0, dx * 0.5 - 0.05]:
		_add_cylinder(parent, pipe_r, pipe_r, dy, Vector3(ox, 0, 0), mat)
	# Toe board
	_add_box(parent, Vector3(dx, 0.1, 0.015), Vector3(0, -dy * 0.5 + 0.05, 0), mat)

static func _build_crowd_barrier(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat := get_material("aluminum")
	# Upright perforated wall
	_add_box(parent, Vector3(dx, dy * 0.9, 0.04), Vector3(0, 0.05, dz * 0.5 - 0.05), mat)
	# Bottom standing plate
	_add_box(parent, Vector3(dx, 0.02, dz * 0.8), Vector3(0, -dy * 0.5 + 0.01, -0.05), mat)
	# Rear angled stabilizer strut
	_add_cylinder(parent, 0.02, 0.02, dz * 0.9, Vector3(0, -0.1, 0), mat, Vector3(PI * 0.28, 0, 0))

static func _build_audio_line_array(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cab := get_material("speaker_cabinet")
	var mat_grille := get_material("speaker_grille")
	var mat_pin := get_material("steel_plate")

	# Trapezoidal cabinet
	_add_box(parent, Vector3(dx, dy * 0.95, dz * 0.8), Vector3(0, 0, dz * 0.1), mat_cab)
	# Front metal acoustic grille
	_add_box(parent, Vector3(dx * 0.96, dy * 0.9, 0.02), Vector3(0, 0, -dz * 0.4), mat_grille)
	# Side rigging hardware brackets
	for ox in [-dx * 0.5 - 0.01, dx * 0.5 + 0.01]:
		_add_box(parent, Vector3(0.015, dy * 0.8, 0.12), Vector3(ox, 0, 0), mat_pin)

static func _build_audio_subwoofer(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cab := get_material("speaker_cabinet")
	var mat_grille := get_material("speaker_grille")
	var mat_metal := get_material("steel_plate")

	# Heavy plywood enclosure
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_cab)
	# Front speaker grille recessed
	_add_box(parent, Vector3(dx * 0.94, dy * 0.92, 0.02), Vector3(0, 0, -dz * 0.5 + 0.02), mat_grille)
	# Two dual 18" speaker cone outlines behind grille
	_add_cylinder(parent, 0.23, 0.23, 0.03, Vector3(-dx * 0.25, 0, -dz * 0.5 + 0.03), mat_metal, Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, 0.23, 0.23, 0.03, Vector3(dx * 0.25, 0, -dz * 0.5 + 0.03), mat_metal, Vector3(PI * 0.5, 0, 0))
	# Recessed side handles
	for ox in [-dx * 0.5 + 0.01, dx * 0.5 - 0.01]:
		_add_box(parent, Vector3(0.02, 0.15, 0.25), Vector3(ox, 0, 0), mat_metal)

static func _build_audio_monitor(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cab := get_material("speaker_cabinet")
	var mat_grille := get_material("speaker_grille")

	# Wedge base
	_add_box(parent, Vector3(dx, dy * 0.6, dz * 0.8), Vector3(0, -dy * 0.2, dz * 0.1), mat_cab)
	# Angled front grille
	_add_box(parent, Vector3(dx * 0.92, dy * 0.8, 0.02), Vector3(0, dy * 0.1, -dz * 0.15), mat_grille, Vector3(-PI * 0.25, 0, 0))

static func _build_audio_foh(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_case := get_material("flight_case_black")
	var mat_surf := get_material("aluminum_dark")
	var mat_screen := get_material("led_lens")

	# Console base and stand
	_add_box(parent, Vector3(dx, 0.1, dz), Vector3(0, -dy * 0.45, 0), mat_case)
	# Sloped fader and channel strip surface
	_add_box(parent, Vector3(dx * 0.96, 0.08, dz * 0.5), Vector3(0, -0.1, 0.15), mat_surf, Vector3(PI * 0.08, 0, 0))
	# Angled digital touch screens
	_add_box(parent, Vector3(dx * 0.8, dy * 0.35, 0.04), Vector3(0, dy * 0.15, -dz * 0.2), mat_screen, Vector3(-PI * 0.15, 0, 0))
	# Padded leatherette wrist rest
	_add_box(parent, Vector3(dx * 0.98, 0.04, 0.08), Vector3(0, -0.15, dz * 0.45), get_material("rubber_cable"))

static func _build_flight_case_rack(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_case := get_material("flight_case_black")
	var mat_chrome := get_material("chrome_corner")
	var mat_rack := get_material("aluminum_dark")

	# Main black flightcase body
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_case)
	# Front rack bay opening
	_add_box(parent, Vector3(dx * 0.82, dy * 0.86, 0.02), Vector3(0, 0, -dz * 0.5 + 0.01), mat_rack)
	# 8 Chrome ball corners
	var cr := 0.04
	var hx := dx * 0.5
	var hy := dy * 0.5
	var hz := dz * 0.5
	for ox in [-hx, hx]:
		for oy in [-hy, hy]:
			for oz in [-hz, hz]:
				_add_box(parent, Vector3(cr, cr, cr), Vector3(ox, oy, oz), mat_chrome)
	# 4 Heavy-duty casters at the bottom
	for ox in [-hx + 0.1, hx - 0.1]:
		for oz in [-hz + 0.1, hz - 0.1]:
			_add_cylinder(parent, 0.04, 0.04, 0.03, Vector3(ox, -hy - 0.04, oz), get_material("rubber_cable"), Vector3(0, 0, PI * 0.5))

static func _build_lighting_moving_head(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_base := get_material("fixture_housing")
	var mat_lens := get_material("led_lens")

	# Base box with handles and display
	_add_box(parent, Vector3(dx * 0.8, 0.12, dz * 0.8), Vector3(0, -dy * 0.5 + 0.06, 0), mat_base)

	# Rotating yoke arms (U-shape)
	var yoke_h := dy * 0.45
	_add_cylinder(parent, 0.035, 0.035, yoke_h, Vector3(-dx * 0.32, -dy * 0.15, 0), mat_base)
	_add_cylinder(parent, 0.035, 0.035, yoke_h, Vector3(dx * 0.32, -dy * 0.15, 0), mat_base)
	_add_cylinder(parent, 0.05, 0.05, dx * 0.64, Vector3(0, -dy * 0.5 + 0.14, 0), mat_base, Vector3(0, 0, PI * 0.5))

	# Moving head lamp fixture pod
	_add_cylinder(parent, 0.12, 0.14, dy * 0.42, Vector3(0, dy * 0.12, 0), mat_base)
	# Front optical output lens
	_add_cylinder(parent, 0.1, 0.1, 0.02, Vector3(0, dy * 0.33 + 0.01, 0), mat_lens)

static func _build_lighting_par(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_body := get_material("aluminum_dark")
	var mat_lens := get_material("led_lens")
	var mat_yoke := get_material("steel_plate")

	# Cylindrical par can barrel
	_add_cylinder(parent, dx * 0.4, dx * 0.35, dy * 0.65, Vector3(0, 0, 0), mat_body)
	# Front LED cluster lens
	_add_cylinder(parent, dx * 0.38, dx * 0.38, 0.02, Vector3(0, dy * 0.33, 0), mat_lens)
	# Mounting yoke bracket
	_add_box(parent, Vector3(dx * 1.05, 0.02, 0.04), Vector3(0, dy * 0.5 - 0.02, 0), mat_yoke)
	_add_box(parent, Vector3(0.02, dy * 0.6, 0.04), Vector3(-dx * 0.5, 0.1, 0), mat_yoke)
	_add_box(parent, Vector3(0.02, dy * 0.6, 0.04), Vector3(dx * 0.5, 0.1, 0), mat_yoke)

static func _build_lighting_bar(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_case := get_material("aluminum_dark")
	var mat_lens := get_material("led_lens")

	# Sleek aluminum extrusion housing
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_case)

	# 12 separate pixel lenses along the face
	var num_leds := 12
	var step := (dx - 0.08) / float(num_leds)
	for i in range(num_leds):
		var ox := -dx * 0.5 + 0.04 + (float(i) + 0.5) * step
		_add_cylinder(parent, 0.02, 0.02, 0.015, Vector3(ox, 0, dz * 0.5 + 0.008), mat_lens, Vector3(PI * 0.5, 0, 0))

static func _build_video_led_panel(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_frame := get_material("aluminum_dark")
	var mat_panel := get_material("led_pixel_panel")
	var mat_lock := get_material("chrome_corner")

	# Ultra-slim die-cast aluminum frame
	_add_box(parent, Vector3(dx, dy, dz * 0.5), Vector3(0, 0, -dz * 0.25), mat_frame)
	# Front active LED display matrix
	_add_box(parent, Vector3(dx * 0.98, dy * 0.98, 0.01), Vector3(0, 0, dz * 0.5 - 0.005), mat_panel)
	# Fast-locking corner cam pins
	for ox in [-dx * 0.5 + 0.02, dx * 0.5 - 0.02]:
		for oy in [-dy * 0.5 + 0.02, dy * 0.5 - 0.02]:
			_add_box(parent, Vector3(0.03, 0.03, dz), Vector3(ox, oy, 0), mat_lock)

static func _build_power_distro(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_housing := get_material("rubber_cable")
	var mat_panel := get_material("aluminum_dark")

	# Heavy shock-proof rubber distro case
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_housing)
	# Recessed front breaker panel
	_add_box(parent, Vector3(dx * 0.85, dy * 0.85, 0.02), Vector3(0, 0, -dz * 0.5 + 0.01), mat_panel)
	# CEE power sockets (Red 32A/63A, Blue 16A)
	_add_cylinder(parent, 0.045, 0.045, 0.03, Vector3(-0.15, -0.1, -dz * 0.5 - 0.01), get_material("fixture_housing"), Vector3(PI * 0.5, 0, 0))
	_add_cylinder(parent, 0.035, 0.035, 0.03, Vector3(0.15, -0.1, -dz * 0.5 - 0.01), get_material("led_lens"), Vector3(PI * 0.5, 0, 0))

static func _build_ballast_tank(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cage := get_material("aluminum")
	var mat_tank := get_material("ibc_plastic")

	# Inner blow-molded polyethylene tank
	_add_box(parent, Vector3(dx * 0.9, dy * 0.88, dz * 0.9), Vector3(0, 0.02, 0), mat_tank)
	# Galvanized tubular steel cage grid
	_add_box(parent, Vector3(dx, dy, dz), Vector3.ZERO, mat_cage)
	# Bottom four-way pallet
	_add_box(parent, Vector3(dx, 0.12, dz), Vector3(0, -dy * 0.5 + 0.06, 0), get_material("steel_plate"))

static func _build_dj_booth(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_booth := get_material("stage_black_deck")
	var mat_trim := get_material("aluminum")

	# Front facade cover panel
	_add_box(parent, Vector3(dx, dy, 0.04), Vector3(0, 0, -dz * 0.5 + 0.02), mat_booth)
	# Side privacy wings
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(-dx * 0.5 + 0.02, 0, 0), mat_booth)
	_add_box(parent, Vector3(0.04, dy, dz), Vector3(dx * 0.5 - 0.02, 0, 0), mat_booth)
	# Top equipment performance tabletop
	_add_box(parent, Vector3(dx - 0.08, 0.04, dz - 0.08), Vector3(0, dy * 0.5 - 0.02, 0), mat_booth)
	# Aluminum corner edge trims
	_add_box(parent, Vector3(dx, 0.02, 0.02), Vector3(0, dy * 0.5, -dz * 0.5 + 0.01), mat_trim)

static func _build_dj_setup(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_case := get_material("flight_case_black")
	var mat_deck := get_material("aluminum_dark")
	var mat_wheel := get_material("chrome_corner")
	var mat_screen := get_material("led_lens")

	# Roadcase tray
	_add_box(parent, Vector3(dx, dy * 0.5, dz), Vector3(0, -dy * 0.25, 0), mat_case)

	# 4 DJ Media Players / Decks across the tray
	var num_players := 4
	var deck_w := (dx - 0.1) / float(num_players)
	for i in range(num_players):
		var ox := -dx * 0.5 + 0.05 + (float(i) + 0.5) * deck_w
		_add_box(parent, Vector3(deck_w * 0.92, 0.06, dz * 0.9), Vector3(ox, 0.03, 0), mat_deck)
		# Jog wheel platter
		_add_cylinder(parent, deck_w * 0.35, deck_w * 0.35, 0.015, Vector3(ox, 0.07, dz * 0.1), mat_wheel)
		# Display waveform screen
		_add_box(parent, Vector3(deck_w * 0.7, 0.01, dz * 0.25), Vector3(ox, 0.065, -dz * 0.25), mat_screen)

static func _build_crowd_figure(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	var mat_cloth := get_material("crowd_clothing")
	var mat_skin := get_material("crowd_skin")

	# Legs / pants
	_add_box(parent, Vector3(dx * 0.8, dy * 0.45, dz * 0.8), Vector3(0, -dy * 0.25, 0), mat_cloth)
	# Torso / hoodie / jacket
	_add_box(parent, Vector3(dx, dy * 0.35, dz), Vector3(0, dy * 0.15, 0), mat_cloth)
	# Head
	_add_cylinder(parent, dx * 0.25, dx * 0.25, dy * 0.18, Vector3(0, dy * 0.42, 0), mat_skin)

static func _build_crowd_multimesh_block(parent: Node3D, dx: float, dy: float, dz: float) -> void:
	# Efficient MultiMeshInstance3D holding 100 spectator figures in 1 single draw call
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 100

	# Low-poly stylized figure mesh
	var figure_mesh := BoxMesh.new()
	figure_mesh.size = Vector3(0.4, 1.75, 0.3)
	figure_mesh.material = get_material("crowd_clothing")
	mm.mesh = figure_mesh

	var idx := 0
	for row in range(10):
		for col in range(10):
			var x := -dx * 0.5 + (float(col) + 0.5) * (dx / 10.0) + (randf() - 0.5) * 0.25
			var z := -dz * 0.5 + (float(row) + 0.5) * (dz / 10.0) + (randf() - 0.5) * 0.25
			var t := Transform3D()
			t = t.rotated(Vector3.UP, randf() * TAU * 0.15 - 0.15)
			t.origin = Vector3(x, 1.75 * 0.5, z)
			mm.set_instance_transform(idx, t)
			idx += 1

	mmi.multimesh = mm
	parent.add_child(mmi)

