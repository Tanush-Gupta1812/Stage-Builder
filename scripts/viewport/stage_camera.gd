class_name StageCamera
extends Camera3D

## Professional 3D view camera for Stage-Builder.
## Supports:
##   - Ground-Parallel Walk Move (MMB drag, ground-level W/S/A/D equivalent)
##   - Vertical Elevation (Alt + MMB drag, pure height change)
##   - Orbit (Shift+MMB drag / Alt+LMB / Option+two-finger drag)
##   - Pan (Alt+Shift+LMB / Trackpad two-finger scroll)
##   - Smooth Zoom (Ctrl/Cmd+MMB drag)
##   - Discrete Zoom (Mouse Wheel Up/Down / Trackpad pinch)
##   - WASD Fly Mode (Hold RMB + WASD/QE)
##   - Frame Selection (F) & Quick Views (Top, Front, Side, Perspective).

@export var orbit_sensitivity: float = 0.005
@export var pan_sensitivity: float = 0.004
@export var zoom_sensitivity: float = 1.0
@export var fly_speed: float = 8.0
@export var fly_fast_multiplier: float = 2.5
@export var min_zoom_distance: float = 1.0
@export var max_zoom_distance: float = 150.0

var target_pivot: Vector3 = Vector3(0, 1.0, 0)
var distance: float = 16.0
var pitch: float = -0.5
var yaw: float = 0.0

var invert_middle_drag: bool = false
var is_orbiting: bool = false
var is_panning: bool = false
var is_walking: bool = false
var is_elevating: bool = false
var is_zooming: bool = false
var is_flying: bool = false
var _drag_ground_dist: float = 16.0

func _ready() -> void:
	current = true
	load_camera_settings()
	_update_orbit_transform()

func set_invert_middle_drag(val: bool) -> void:
	invert_middle_drag = val
	save_camera_settings()

func load_camera_settings() -> void:
	var path := "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json_str := file.get_as_text()
	file.close()
	var test_json_conv := JSON.new()
	var parse_err := test_json_conv.parse(json_str)
	if parse_err != OK:
		return
	var data: Variant = test_json_conv.data
	if data is Dictionary and data.has("camera") and data["camera"] is Dictionary:
		var cam_dict: Dictionary = data["camera"]
		if cam_dict.has("invert_middle_drag"):
			invert_middle_drag = bool(cam_dict["invert_middle_drag"])

func save_camera_settings() -> void:
	var path := "user://settings.json"
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var file_r := FileAccess.open(path, FileAccess.READ)
		if file_r:
			var json_str := file_r.get_as_text()
			file_r.close()
			var test_json_conv := JSON.new()
			if test_json_conv.parse(json_str) == OK and test_json_conv.data is Dictionary:
				data = test_json_conv.data
	if not data.has("camera") or not (data["camera"] is Dictionary):
		data["camera"] = {}
	data["camera"]["invert_middle_drag"] = invert_middle_drag
	var file_w := FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()

func _unhandled_input(event: InputEvent) -> void:
	# Mac trackpad pinch-to-zoom
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		distance = clampf(distance / mg.factor, min_zoom_distance, max_zoom_distance)
		_update_orbit_transform()
		get_viewport().set_input_as_handled()
		return

	# Mac trackpad two-finger pan / orbit
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if pg.alt_pressed:
			# Option + two-finger = orbit
			yaw -= pg.delta.x * orbit_sensitivity * 8.0
			pitch = clampf(pitch - pg.delta.y * orbit_sensitivity * 8.0, -1.55, 1.55)
			_update_orbit_transform()
			get_viewport().set_input_as_handled()
			return
		else:
			# Two-finger scroll = pan
			var vp := get_viewport()
			var v_h := maxf(1.0, float(vp.size.y) if vp else 900.0)
			var half_fov := deg_to_rad(fov * 0.5)
			var safe_dist := maxf(0.1, distance)
			var frustum_h := 2.0 * safe_dist * tan(half_fov)
			var units_per_pixel := frustum_h / v_h
			if not is_finite(units_per_pixel) or units_per_pixel <= 0.0:
				units_per_pixel = 0.005 * safe_dist

			var cam_basis := global_transform.basis
			var delta_vec := (cam_basis.x * -pg.delta.x * 20.0 + cam_basis.y * pg.delta.y * 20.0) * units_per_pixel
			if delta_vec.length() > 50.0:
				delta_vec = delta_vec.normalized() * 50.0
			if is_finite(delta_vec.x) and is_finite(delta_vec.y) and is_finite(delta_vec.z):
				target_pivot += delta_vec
				if target_pivot.length() > 100000.0:
					target_pivot = target_pivot.normalized() * 100000.0
				_update_orbit_transform()
			get_viewport().set_input_as_handled()
			return

	# Mouse button events
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Mouse wheel zoom toward cursor
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = clampf(distance * 0.9, min_zoom_distance, max_zoom_distance)
			_update_orbit_transform()
			get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = clampf(distance * 1.1, min_zoom_distance, max_zoom_distance)
			_update_orbit_transform()
			get_viewport().set_input_as_handled()
			return

		var is_ctrl := mb.ctrl_pressed or (OS.get_name() == "macOS" and mb.meta_pressed)

		# Button release clears all drag states
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_LEFT:
				is_orbiting = false
				is_panning = false
				is_walking = false
				is_elevating = false
				is_zooming = false

		# Middle Mouse Button
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				# Record ground intersection distance under cursor
				var ray_orig := project_ray_origin(mb.position)
				var ray_d := project_ray_normal(mb.position)
				if absf(ray_d.y) > 0.0001:
					var t := -ray_orig.y / ray_d.y
					if t > 0.0:
						_drag_ground_dist = clampf(t, 1.0, 500.0)
					else:
						_drag_ground_dist = clampf(distance, 1.0, 500.0)
				else:
					_drag_ground_dist = clampf(distance, 1.0, 500.0)

				if mb.alt_pressed:
					is_elevating = true
					is_walking = false
					is_orbiting = false
					is_zooming = false
					is_panning = false
				elif mb.shift_pressed:
					is_orbiting = true
					is_walking = false
					is_elevating = false
					is_zooming = false
					is_panning = false
				elif is_ctrl:
					is_zooming = true
					is_walking = false
					is_elevating = false
					is_orbiting = false
					is_panning = false
				else:
					is_walking = true
					is_elevating = false
					is_orbiting = false
					is_zooming = false
					is_panning = false

		# Alt/Option + Left Mouse Button
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed:
			if mb.pressed:
				if mb.shift_pressed:
					is_panning = true
					is_orbiting = false
					is_walking = false
					is_elevating = false
					is_zooming = false
				else:
					is_orbiting = true
					is_panning = false
					is_walking = false
					is_elevating = false
					is_zooming = false

		# Fly mode toggle (Hold RMB)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				is_flying = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				is_flying = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Sync pivot with current look position
				target_pivot = global_position + global_transform.basis.z * -distance

	# Mouse motion
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var is_ctrl := mm.ctrl_pressed or (OS.get_name() == "macOS" and mm.meta_pressed)
		var speed_mult := 0.25 if is_ctrl else 1.0

		var vp := get_viewport()
		var v_h := maxf(1.0, float(vp.size.y) if vp else 900.0)
		var half_fov := deg_to_rad(fov * 0.5)
		var safe_dist := maxf(0.1, _drag_ground_dist if (is_walking or is_elevating) else distance)
		var frustum_h := 2.0 * safe_dist * tan(half_fov)
		var units_per_pixel := frustum_h / v_h
		if not is_finite(units_per_pixel) or units_per_pixel <= 0.0:
			units_per_pixel = 0.005 * safe_dist

		if is_flying:
			yaw -= mm.relative.x * orbit_sensitivity
			pitch = clampf(pitch - mm.relative.y * orbit_sensitivity, -1.5, 1.5)
			rotation.y = yaw
			rotation.x = pitch
			get_viewport().set_input_as_handled()
		elif is_orbiting:
			yaw -= mm.relative.x * orbit_sensitivity
			pitch = clampf(pitch - mm.relative.y * orbit_sensitivity, -1.55, 1.55)
			_update_orbit_transform()
			get_viewport().set_input_as_handled()
		elif is_walking:
			var cam_basis := global_transform.basis

			# Flatten forward vector onto ground plane (y = 0)
			var fwd_flat := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z)
			if fwd_flat.length_squared() < 0.0001:
				# When looking straight down/up, project camera up vector flat
				fwd_flat = Vector3(cam_basis.y.x, 0.0, cam_basis.y.z)
			if fwd_flat.length_squared() < 0.0001:
				fwd_flat = Vector3(0, 0, -1)
			else:
				fwd_flat = fwd_flat.normalized()

			# Flatten right vector onto ground plane (y = 0)
			var right_flat := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z)
			if right_flat.length_squared() < 0.0001:
				right_flat = Vector3(1, 0, 0)
			else:
				right_flat = right_flat.normalized()

			# "Grab the ground" feel by default: dragging down moves forward; dragging right slides ground right (camera moves left)
			var dir_sign := 1.0 if not invert_middle_drag else -1.0
			var delta_vec := (-right_flat * mm.relative.x + fwd_flat * mm.relative.y) * dir_sign * units_per_pixel * speed_mult
			if delta_vec.length() > 50.0:
				delta_vec = delta_vec.normalized() * 50.0

			if is_finite(delta_vec.x) and is_finite(delta_vec.z):
				# Strictly modify ONLY X and Z; Y is invariant
				target_pivot.x += delta_vec.x
				target_pivot.z += delta_vec.z
				if target_pivot.length() > 100000.0:
					target_pivot = target_pivot.normalized() * 100000.0
				_update_orbit_transform()
			get_viewport().set_input_as_handled()
		elif is_elevating:
			# Alt + MMB: purely changes height Y (drag up raises, drag down lowers)
			var dy := -mm.relative.y * units_per_pixel * speed_mult
			if absf(dy) > 50.0:
				dy = signf(dy) * 50.0

			if is_finite(dy):
				target_pivot.y += dy
				var rot_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
				var offset_y := (rot_basis * Vector3(0, 0, distance)).y
				if target_pivot.y + offset_y < 0.1:
					target_pivot.y = 0.1 - offset_y
				if target_pivot.length() > 100000.0:
					target_pivot = target_pivot.normalized() * 100000.0
				_update_orbit_transform()
			get_viewport().set_input_as_handled()
		elif is_panning:
			var right := global_transform.basis.x
			var up := global_transform.basis.y
			var delta_vec := (-right * mm.relative.x + up * mm.relative.y) * units_per_pixel * speed_mult
			if delta_vec.length() > 50.0:
				delta_vec = delta_vec.normalized() * 50.0

			if is_finite(delta_vec.x) and is_finite(delta_vec.y) and is_finite(delta_vec.z):
				target_pivot += delta_vec
				var rot_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
				var offset_y := (rot_basis * Vector3(0, 0, distance)).y
				if target_pivot.y + offset_y < 0.1:
					target_pivot.y = 0.1 - offset_y
				if target_pivot.length() > 100000.0:
					target_pivot = target_pivot.normalized() * 100000.0
				_update_orbit_transform()
			get_viewport().set_input_as_handled()
		elif is_zooming:
			var zoom_delta := mm.relative.y * 0.01
			distance = clampf(distance * (1.0 + zoom_delta), min_zoom_distance, max_zoom_distance)
			_update_orbit_transform()
			get_viewport().set_input_as_handled()

	# Key shortcuts for quick views & framing
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_F:
				frame_selection()
			KEY_KP_7:
				set_view_top()
			KEY_KP_1:
				set_view_front()
			KEY_KP_3:
				set_view_side()
			KEY_KP_0:
				set_view_perspective()

func _process(delta: float) -> void:
	if not is_flying:
		return

	var move_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S): move_vec.z += 1.0
	if Input.is_key_pressed(KEY_A): move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D): move_vec.x += 1.0
	if Input.is_key_pressed(KEY_E): move_vec.y += 1.0
	if Input.is_key_pressed(KEY_Q): move_vec.y -= 1.0

	if move_vec != Vector3.ZERO:
		var speed := fly_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fly_fast_multiplier

		var move_dir := (global_transform.basis.x * move_vec.x + global_transform.basis.y * move_vec.y + global_transform.basis.z * move_vec.z).normalized()
		global_position += move_dir * speed * delta

func _update_orbit_transform() -> void:
	if not is_finite(distance) or distance <= 0.0:
		distance = 16.0
	if not (is_finite(target_pivot.x) and is_finite(target_pivot.y) and is_finite(target_pivot.z)):
		target_pivot = Vector3(0, 1.0, 0)
	if not (is_finite(pitch) and is_finite(yaw)):
		pitch = -0.5
		yaw = 0.0
	pitch = clampf(pitch, -1.55, 1.55)

	var rot_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var offset := rot_basis * Vector3(0, 0, distance)
	if target_pivot.y + offset.y < 0.1:
		target_pivot.y = 0.1 - offset.y
	global_position = target_pivot + offset
	look_at(target_pivot, Vector3.UP)

func frame_selection() -> void:
	if AppState.selected_objects.is_empty():
		target_pivot = Vector3(0, 1.0, 0)
	else:
		var center := Vector3.ZERO
		for obj in AppState.selected_objects:
			if is_instance_valid(obj):
				center += obj.global_position
		target_pivot = center / float(AppState.selected_objects.size())

	distance = clampf(distance, 5.0, 30.0)
	_update_orbit_transform()

func set_view_top() -> void:
	pitch = -1.55
	yaw = 0.0
	_update_orbit_transform()

func set_view_front() -> void:
	pitch = 0.0
	yaw = 0.0
	_update_orbit_transform()

func set_view_side() -> void:
	pitch = 0.0
	yaw = PI * 0.5
	_update_orbit_transform()

func set_view_perspective() -> void:
	pitch = -0.52
	yaw = -0.65
	_update_orbit_transform()
