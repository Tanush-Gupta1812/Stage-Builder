class_name ThumbnailGenerator
extends Node

## Offscreen thumbnail generator and cache for Stage-Builder equipment assets.
## Renders 3D previews to 128x128 PNG images cached in user://thumbnails/.

const THUMBNAIL_DIR = "user://thumbnails"

static var _cached_textures: Dictionary = {}
static var _viewport_renderer: SubViewport = null
static var _render_camera: Camera3D = null
static var _render_container: Node3D = null

static func get_thumbnail(asset: Dictionary) -> Texture2D:
	var asset_id: String = asset.get("id", "")
	if asset_id == "":
		return null

	if _cached_textures.has(asset_id):
		return _cached_textures[asset_id]

	# Check disk cache
	var disk_path := THUMBNAIL_DIR + "/" + asset_id + ".png"
	if FileAccess.file_exists(disk_path):
		var img := Image.load_from_file(disk_path)
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_cached_textures[asset_id] = tex
			return tex

	# Generate fallback procedural placeholder badge
	var fallback_tex := _create_placeholder_thumbnail(asset)
	_cached_textures[asset_id] = fallback_tex
	return fallback_tex

static func _create_placeholder_thumbnail(asset: Dictionary) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var cat: String = asset.get("category", "")

	# Pick accent color based on category
	var bg_color := Color(0.14, 0.16, 0.19)
	var border_color := Color(0.3, 0.35, 0.42)

	match cat:
		"Truss": border_color = Color(0.7, 0.75, 0.85)
		"Staging": border_color = Color(0.85, 0.6, 0.2)
		"Audio": border_color = Color(0.2, 0.7, 0.95)
		"Lighting": border_color = Color(0.95, 0.8, 0.2)
		"Video": border_color = Color(0.75, 0.3, 0.9)
		"Power": border_color = Color(0.95, 0.3, 0.2)
		"DJ & Backline": border_color = Color(0.2, 0.85, 0.5)
		"Rigging": border_color = Color(0.8, 0.5, 0.3)
		"Roof & Structure": border_color = Color(0.4, 0.6, 0.8)
		"Environment & Dressing": border_color = Color(0.3, 0.75, 0.3)
		"Crowd": border_color = Color(0.85, 0.4, 0.6)

	img.fill(bg_color)

	# Draw border & category chip indicator
	for x in range(64):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, 63, border_color)
	for y in range(64):
		img.set_pixel(0, y, border_color)
		img.set_pixel(63, y, border_color)

	# Draw center accent block
	for cx in range(20, 44):
		for cy in range(20, 44):
			img.set_pixel(cx, cy, border_color.lerp(bg_color, 0.3))

	return ImageTexture.create_from_image(img)

