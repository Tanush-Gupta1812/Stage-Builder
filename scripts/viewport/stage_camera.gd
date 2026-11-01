class_name StageCamera
extends Camera3D

## Professional 3D view camera for Stage-Builder.
## Supports Orbit (MMB / Alt+LMB), Pan (Shift+MMB / Trackpad), Zoom (Wheel / Pinch),
## WASD Fly Mode (Hold RMB), Frame Selection (F), and Quick Views (Top, Front, Side, Perspective).

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

var is_orbiting: bool = false
var is_panning: bool = false
var is_flying: bool = false

func _ready() -> void:
	current = true
	_update_orbit_transform()

func _unhandled_input(event: InputEvent) -> void:
	# Mac trackpad pinch-to-zoom
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		distance = clampf(distance / mg.factor, min_zoom_distance, max_zoom_distance)
		_update_orbit_transform()
		get_viewport().set_input_as_handled()
		return

	# Mac trackpad two-finger pan
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		var factor := distance * 0.002
		var cam_basis := global_transform.basis
		target_pivot += (cam_basis.x * -pg.delta.x + cam_basis.y * pg.delta.y) * factor
		_update_orbit_transform()
		get_viewport().set_input_as_handled()
		return

	# Mouse button events
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
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

		# Middle mouse or Alt+LMB for Orbit / Pan
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed):
			if mb.pressed:
				if mb.shift_pressed:
					is_panning = true
				else:
					is_orbiting = true
			else:
				is_orbiting = false
				is_panning = false

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
		elif is_panning:
			var factor := distance * pan_sensitivity
			var right := global_transform.basis.x
			var up := global_transform.basis.y
			target_pivot += (-right * mm.relative.x + up * mm.relative.y) * factor
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
	var rot_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var offset := rot_basis * Vector3(0, 0, distance)
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

