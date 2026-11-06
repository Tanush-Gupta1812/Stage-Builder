extends Node

## Persistent offscreen 3D Thumbnail Renderer and Cache for Stage-Builder.
## Registered as Autoload singleton 'ThumbnailRenderer' in project.godot.
## Holds a dedicated SubViewport (own_world_3d = true, transparent_bg = true, size 256x256),
## Camera3D, DirectionalLight3D, and WorldEnvironment with ambient lighting against a neutral background.
## Supports async job queues, persistent disk caching, variant keys, and contact sheet generation.

signal thumbnail_ready(asset_id: String, variant: String, texture: Texture2D)
signal progress_changed(completed: int, total: int)

const THUMBNAIL_DIR: String = "user://thumbnails"
const GENERATOR_VERSION: String = "v3"
const BASE_THUMB_SIZE: Vector2i = Vector2i(256, 256)

static var instance: Node = null
static var _memory_cache: Dictionary = {} # "asset_id:variant" -> ImageTexture

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _container: Node3D = null
var _dir_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null

var _queue: Array[Dictionary] = [] # Array of { "asset": Dictionary, "variant": String }
var _is_processing: bool = false
var _total_queued_count: int = 0
var _completed_count: int = 0

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	instance = self
	_ensure_dir()
	_setup_renderer()

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(THUMBNAIL_DIR):
		DirAccess.make_dir_recursive_absolute(THUMBNAIL_DIR)

func _setup_renderer() -> void:
	if DisplayServer.get_name() == "headless":
		print("ThumbnailRenderer: Headless mode detected - offscreen 3D hardware rasterizer unavailable. Using styled category glyph icons.")
		return

	var dpi_scale := 1.0
	if DisplayServer.get_screen_count() > 0:
		dpi_scale = maxf(1.0, DisplayServer.screen_get_scale())
	var render_size := Vector2i(int(BASE_THUMB_SIZE.x * dpi_scale), int(BASE_THUMB_SIZE.y * dpi_scale))

	_viewport = SubViewport.new()
	_viewport.name = "ThumbnailSubViewport"
	_viewport.size = render_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.50, 0.54)
	env.ambient_light_energy = 1.0

	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	_viewport.add_child(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.rotation_degrees = Vector3(-45, 40, 0)
	_dir_light.light_energy = 1.15
	_viewport.add_child(_dir_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.rotation_degrees = Vector3(25, -140, 0)
	_fill_light.light_energy = 0.55
	_viewport.add_child(_fill_light)

	_camera = Camera3D.new()
	_camera.fov = 35.0
	_viewport.add_child(_camera)

	_container = Node3D.new()
	_container.name = "ThumbnailAssetContainer"
	_viewport.add_child(_container)

	add_child(_viewport)

static func get_cache_key(asset_id: String, variant: String = "") -> String:
	return asset_id + ":" + variant

static func get_disk_path(asset_id: String, variant: String = "") -> String:
	var safe_var := variant if variant != "" else "default"
	return THUMBNAIL_DIR + "/" + asset_id + "_" + safe_var + "_" + GENERATOR_VERSION + ".png"

static func get_thumbnail(asset: Dictionary, variant: String = "") -> Texture2D:
	var asset_id: String = asset.get("id", "")
	if asset_id == "":
		return null

	if variant == "":
		variant = asset.get("default_variant", "")

	var key := get_cache_key(asset_id, variant)
	if _memory_cache.has(key):
		return _memory_cache[key]

	# Check persistent disk cache
	var disk_file := get_disk_path(asset_id, variant)
	if FileAccess.file_exists(disk_file):
		var img := Image.load_from_file(disk_file)
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_memory_cache[key] = tex
			return tex

	# Enqueue 3D render job if renderer is active
	if instance:
		instance.queue_render(asset, variant)

	# Return fallback category icon immediately while rendering
	var fallback_tex := _create_fallback_icon(asset)
	_memory_cache[key] = fallback_tex
	return fallback_tex

func queue_render(asset: Dictionary, variant: String = "", prioritize: bool = false) -> void:
	if DisplayServer.get_name() == "headless" or _viewport == null:
		return

	var asset_id: String = asset.get("id", "")
	for item in _queue:
		if item.asset.get("id", "") == asset_id and item.variant == variant:
			return

	var job := { "asset": asset, "variant": variant }
	if prioritize:
		_queue.push_front(job)
	else:
		_queue.append(job)

	_total_queued_count = max(_total_queued_count, _completed_count + _queue.size())
	progress_changed.emit(_completed_count, _total_queued_count)

	if not _is_processing:
		_process_queue()

func regenerate_all() -> void:
	# Invalidate memory and disk cache
	_memory_cache.clear()
	var da := DirAccess.open(THUMBNAIL_DIR)
	if da:
		da.list_dir_begin()
		var f := da.get_next()
		while f != "":
			if not da.current_is_dir() and f.ends_with(".png"):
				da.remove(f)
			f = da.get_next()
		da.list_dir_end()

	var all_assets: Array = CatalogManager.get_all_assets()
	_queue.clear()
	_completed_count = 0
	_total_queued_count = all_assets.size()

	for a in all_assets:
		var var_id: String = a.get("default_variant", "")
		_queue.append({ "asset": a, "variant": var_id })

	progress_changed.emit(_completed_count, _total_queued_count)
	if not _is_processing:
		_process_queue()

func _process_queue() -> void:
	if _is_processing or _queue.is_empty() or _viewport == null:
		return
	_is_processing = true

	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		await _render_job(job)
		_completed_count += 1
		progress_changed.emit(_completed_count, _total_queued_count)

	_is_processing = false
	if _completed_count >= _total_queued_count:
		_completed_count = 0
		_total_queued_count = 0
		progress_changed.emit(0, 0)

func _render_job(job: Dictionary) -> void:
	var asset: Dictionary = job.asset
	var variant: String = job.variant
	var asset_id: String = asset.get("id", "")
	if asset_id == "":
		return

	# Clear previous model
	for child in _container.get_children():
		_container.remove_child(child)
		child.queue_free()

	var model := CatalogManager.instantiate_asset(asset_id, variant)
	if not model:
		return
	_container.add_child(model)

	# Compute exact world-space AABB across all visual geometry
	var combined_aabb := _compute_hierarchy_aabb(model)
	if combined_aabb.size.length() < 0.001:
		combined_aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)

	var center := combined_aabb.get_center()
	var radius := combined_aabb.size.length() * 0.5
	radius = maxf(radius, 0.3)

	# Position camera at 3/4 isometric viewpoint
	var fov_rad := deg_to_rad(_camera.fov)
	var dist := (radius / sin(fov_rad * 0.5)) * 1.15
	var cam_dir := Vector3(1.0, 0.75, 1.0).normalized()
	_camera.global_position = center + (cam_dir * dist)
	_camera.look_at(center, Vector3.UP)

	# Render cycle: UPDATE_ALWAYS during draw, await frame_post_draw TWICE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var tex_data := _viewport.get_texture()
	if tex_data:
		var raw_img := tex_data.get_image()
		if raw_img and not raw_img.is_empty():
			# Composite over neutral studio gradient background
			var comp_img := _composite_with_background(raw_img)
			var disk_file := get_disk_path(asset_id, variant)
			comp_img.save_png(disk_file)

			var final_tex := ImageTexture.create_from_image(comp_img)
			var key := get_cache_key(asset_id, variant)
			_memory_cache[key] = final_tex
			thumbnail_ready.emit(asset_id, variant, final_tex)

	# Cleanup model
	if is_instance_valid(model):
		_container.remove_child(model)
		model.queue_free()

func _compute_hierarchy_aabb(node: Node3D) -> AABB:
	var total_aabb := AABB()
	var first := true

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is VisualInstance3D and (cur is MeshInstance3D or cur is MultiMeshInstance3D):
			var vi := cur as VisualInstance3D
			var inst_aabb := vi.get_aabb()
			var global_aabb: AABB = vi.global_transform * inst_aabb
			if first:
				total_aabb = global_aabb
				first = false
			else:
				total_aabb = total_aabb.merge(global_aabb)

		for child in cur.get_children():
			stack.push_back(child)

	if first and node.has_method("get_world_aabb"):
		total_aabb = node.get_world_aabb()
	return total_aabb

func _composite_with_background(fg_img: Image) -> Image:
	var w := fg_img.get_width()
	var h := fg_img.get_height()
	var result := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var bg_top := Color(0.20, 0.22, 0.26)
	var bg_bottom := Color(0.12, 0.13, 0.16)

	for y in range(h):
		var t := float(y) / float(h)
		var row_color := bg_top.lerp(bg_bottom, t)
		for x in range(w):
			var fg_pixel: Color = fg_img.get_pixel(x, y)
			var a := fg_pixel.a
			if a >= 0.99:
				result.set_pixel(x, y, Color(fg_pixel.r, fg_pixel.g, fg_pixel.b, 1.0))
			elif a <= 0.01:
				result.set_pixel(x, y, row_color)
			else:
				var blended: Color = row_color.lerp(fg_pixel, a)
				blended.a = 1.0
				result.set_pixel(x, y, blended)
	return result

static func _create_fallback_icon(asset: Dictionary) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var cat: String = asset.get("category", "")

	var bg_color := Color(0.14, 0.15, 0.18)
	var border_color := Color(0.32, 0.35, 0.42)
	var accent_color := Color(0.4, 0.7, 1.0)

	match cat:
		"Truss":
			accent_color = Color(0.75, 0.8, 0.9)
			border_color = Color(0.5, 0.55, 0.65)
		"Roof & Structure":
			accent_color = Color(0.45, 0.68, 0.88)
			border_color = Color(0.35, 0.5, 0.65)
		"Rigging":
			accent_color = Color(0.85, 0.55, 0.35)
			border_color = Color(0.65, 0.4, 0.25)
		"Staging":
			accent_color = Color(0.9, 0.65, 0.25)
			border_color = Color(0.7, 0.5, 0.2)
		"Audio":
			accent_color = Color(0.25, 0.75, 0.98)
			border_color = Color(0.2, 0.55, 0.75)
		"Lighting":
			accent_color = Color(0.98, 0.82, 0.25)
			border_color = Color(0.75, 0.6, 0.2)
		"Video":
			accent_color = Color(0.8, 0.35, 0.95)
			border_color = Color(0.6, 0.25, 0.75)
		"Power":
			accent_color = Color(0.95, 0.32, 0.25)
			border_color = Color(0.75, 0.25, 0.2)
		"DJ & Backline":
			accent_color = Color(0.25, 0.88, 0.55)
			border_color = Color(0.2, 0.65, 0.4)
		"Environment & Dressing":
			accent_color = Color(0.35, 0.8, 0.35)
			border_color = Color(0.25, 0.6, 0.25)
		"Crowd":
			accent_color = Color(0.9, 0.45, 0.65)
			border_color = Color(0.7, 0.3, 0.5)

	img.fill(bg_color)

	# Rounded border outline
	for x in range(128):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, 1, border_color)
		img.set_pixel(x, 126, border_color)
		img.set_pixel(x, 127, border_color)
	for y in range(128):
		img.set_pixel(0, y, border_color)
		img.set_pixel(1, y, border_color)
		img.set_pixel(126, y, border_color)
		img.set_pixel(127, y, border_color)

	# Center geometric category icon glyph
	for cx in range(36, 92):
		for cy in range(36, 92):
			var dist_x := absf(float(cx) - 63.5)
			var dist_y := absf(float(cy) - 63.5)
			if dist_x < 24.0 and dist_y < 24.0:
				if dist_x > 20.0 or dist_y > 20.0 or (dist_x < 4.0 and dist_y < 4.0):
					img.set_pixel(cx, cy, accent_color)
				else:
					img.set_pixel(cx, cy, accent_color.lerp(bg_color, 0.6))

	return ImageTexture.create_from_image(img)

static func generate_contact_sheet(output_path: String = "docs/thumbnail_sheet.png") -> bool:
	var all_assets: Array = CatalogManager.get_all_assets()
	if all_assets.is_empty():
		return false

	var cols := 12
	var rows := int(ceilf(float(all_assets.size()) / float(cols)))
	var cell_w := 96
	var cell_h := 96
	var sheet_w := cols * cell_w
	var sheet_h := rows * cell_h

	var sheet_img := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet_img.fill(Color(0.10, 0.11, 0.13))

	for i in range(all_assets.size()):
		var asset: Dictionary = all_assets[i]
		var col := i % cols
		var row := i / cols
		var thumb := get_thumbnail(asset)
		if thumb:
			var img: Image = thumb.get_image()
			if img:
				var res_img := img.duplicate()
				res_img.resize(cell_w - 4, cell_h - 4, Image.INTERPOLATE_LANCZOS)
				sheet_img.blit_rect(
					res_img,
					Rect2i(Vector2i.ZERO, Vector2i(cell_w - 4, cell_h - 4)),
					Vector2i(col * cell_w + 2, row * cell_h + 2)
				)

	var err := sheet_img.save_png(output_path)
	if err == OK:
		print("ThumbnailRenderer: Contact sheet compiled at: " + output_path)
		return true
	else:
		push_error("ThumbnailRenderer: Failed to save contact sheet to: " + output_path)
		return false
