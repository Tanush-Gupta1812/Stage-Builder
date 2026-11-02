extends Node

## Automatic UI Scaling orchestrator for Stage-Builder.
## Acts as the single source of truth for UI scaling across high-resolution displays
## (Windows 100%-200%+ display scaling, 1080p to 4K, and macOS Retina 1x/2x displays)
## using Godot's native content_scale_factor with stretch mode "disabled".
## Features built-in FIT-TO-WINDOW protection preventing layout overflow or cropping.

signal scale_changed(new_scale: float)

const MIN_LAYOUT_WIDTH: float = 1100.0
const MIN_LAYOUT_HEIGHT: float = 680.0
const MIN_SCALE: float = 0.75
const MAX_SCALE: float = 3.0

var current_scale: float = 1.0
var requested_scale: float = 1.0
var manual_override: bool = false
var _last_screen_id: int = -1
var _last_phys_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	var win := get_window()
	if win:
		win.dpi_changed.connect(_on_dpi_changed)
		win.size_changed.connect(_on_size_changed)

	recompute_scale()

func _on_dpi_changed() -> void:
	recompute_scale()

func _on_size_changed() -> void:
	var win := get_window()
	if win and (win.size != _last_phys_size or win.current_screen != _last_screen_id):
		recompute_scale()

func set_scale(target_scale: float) -> void:
	manual_override = true
	requested_scale = clampf(target_scale, MIN_SCALE, MAX_SCALE)
	recompute_scale()

func clear_override() -> void:
	manual_override = false
	recompute_scale()

func recompute_scale() -> void:
	var win := get_window()
	if win == null:
		return

	var screen_id := win.current_screen
	if screen_id < 0:
		if DisplayServer.get_screen_count() > 0:
			screen_id = DisplayServer.get_primary_screen()
		else:
			screen_id = 0

	_last_screen_id = screen_id
	_last_phys_size = win.size

	var screen_size := Vector2i(1920, 1080)
	var os_scale := 1.0
	var dpi := 96

	if DisplayServer.get_screen_count() > 0 and screen_id < DisplayServer.get_screen_count():
		screen_size = DisplayServer.screen_get_size(screen_id)
		os_scale = DisplayServer.screen_get_scale(screen_id)
		dpi = DisplayServer.screen_get_dpi(screen_id)

	if not manual_override:
		requested_scale = calculate_auto_scale(os_scale, dpi, screen_size)

	# Apply FIT-TO-WINDOW protection: logical window size must never be smaller than 1100 x 680
	var effective_scale := compute_fit_scale(requested_scale, win.size)

	var prev_scale := current_scale
	current_scale = effective_scale

	if not is_equal_approx(win.content_scale_factor, effective_scale):
		win.content_scale_factor = effective_scale

	# Set window physical min_size so OS window manager enforces minimum layout
	win.min_size = Vector2i(int(MIN_LAYOUT_WIDTH * effective_scale), int(MIN_LAYOUT_HEIGHT * effective_scale))

	_log_scale_diagnostic(screen_size, os_scale, dpi, win, effective_scale)

	if not is_equal_approx(prev_scale, effective_scale):
		scale_changed.emit(current_scale)

## Auto-scale decision tree:
## 1. OS-reported scale (screen_get_scale()) when hidpi is on.
## 2. Fallback if ~1.0: dpi / 96.0
## 3. Fallback if both ~1.0: 1.5 at >= 2160 height (4K), 1.25 at >= 1440 height (QHD), else 1.0.
## 4. Round to nearest 0.25, clamp 1.0-3.0.
## Note: On macOS Retina, screen_get_scale() reports 2.0; does not double-multiply.
static func calculate_auto_scale(os_scale: float, dpi: int, screen_size: Vector2i) -> float:
	var candidate := os_scale

	# Fallback if OS scale is ~1.0: try physical DPI / 96
	if candidate <= 1.01 and dpi > 0:
		var dpi_ratio := float(dpi) / 96.0
		if dpi_ratio > 1.15:
			candidate = dpi_ratio

	# Fallback if both still ~1.0: resolution tiers
	if candidate <= 1.01:
		if screen_size.y >= 2160:
			candidate = 1.5
		elif screen_size.y >= 1440:
			candidate = 1.25
		else:
			candidate = 1.0

	candidate = clampf(candidate, 1.0, MAX_SCALE)
	return roundf(candidate * 4.0) / 4.0

## Backward compatibility alias
static func calculate_scale(os_scale: float, dpi: int, screen_size: Vector2i) -> float:
	return calculate_auto_scale(os_scale, dpi, screen_size)

## FIT-TO-WINDOW protection:
## Logical window size = physical_size / scale.
## Logical size must be >= 1100 x 680.
## If desired_scale makes logical size smaller than 1100 x 680,
## reduce scale (down to MIN_SCALE = 0.75) until it fits.
static func compute_fit_scale(desired_scale: float, win_phys_size: Vector2i) -> float:
	if win_phys_size.x <= 0 or win_phys_size.y <= 0:
		return clampf(desired_scale, MIN_SCALE, MAX_SCALE)

	var max_scale_x := float(win_phys_size.x) / MIN_LAYOUT_WIDTH
	var max_scale_y := float(win_phys_size.y) / MIN_LAYOUT_HEIGHT
	var max_allowed := minf(max_scale_x, max_scale_y)

	# Floor to 0.25 increment so logical size strictly >= 1100x680
	var max_stepped := floorf(max_allowed * 4.0 + 0.001) / 4.0

	var effective := desired_scale
	if effective > max_stepped:
		effective = max_stepped

	effective = clampf(effective, MIN_SCALE, MAX_SCALE)
	return roundf(effective * 4.0) / 4.0

func _log_scale_diagnostic(screen_size: Vector2i, os_scale: float, dpi: int, win: Window, effective_scale: float) -> void:
	var stretch_mode_str := "disabled"
	match win.content_scale_mode:
		Window.CONTENT_SCALE_MODE_DISABLED: stretch_mode_str = "disabled"
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS: stretch_mode_str = "canvas_items"
		Window.CONTENT_SCALE_MODE_VIEWPORT: stretch_mode_str = "viewport"

	print("[UIScale Diagnostic] Screen size: %s | screen_get_scale(): %.2f | screen_get_dpi(): %d | window size (phys): %s | stretch mode: %s | base size: %s | content_scale_factor: %.2f | final effective scale: %.2f" % [
		str(screen_size), os_scale, dpi, str(win.size), stretch_mode_str, str(win.content_scale_size), win.content_scale_factor, effective_scale
	])
