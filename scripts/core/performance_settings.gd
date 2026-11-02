class_name PerformanceSettingsManager
extends Node

## Manages display frame rate caps, VSync modes, and unfocused power saving for Stage-Builder.
## Persists settings to user://settings.json.
##
## Platform Behavior:
## - Windows: VSync synchronizes to the monitor refresh rate; disabling VSync allows true uncapped FPS.
## - macOS: The macOS system compositor (Metal) enforces display sync; 'Unlimited' may still be
##   constrained by the screen's hardware refresh rate (e.g. 60Hz or 120Hz ProMotion).

signal settings_changed

enum FPSMode {
	VSYNC = 0,
	CUSTOM_LIMIT = 1,
	UNLIMITED = 2
}

const SETTINGS_FILE = "user://settings.json"
const MIN_FPS = 15
const MAX_FPS = 1000
const DEFAULT_CUSTOM_LIMIT = 60
const UNFOCUSED_FPS_LIMIT = 30

var fps_mode: FPSMode = FPSMode.VSYNC
var custom_fps_limit: int = DEFAULT_CUSTOM_LIMIT
var limit_fps_unfocused: bool = true
var current_vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED

var is_window_focused: bool = true
var is_window_minimized: bool = false

func _ready() -> void:
	load_settings()
	apply_settings()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_set_focus_state(false)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_set_focus_state(true)

func _process(_delta: float) -> void:
	# Detect minimize state across desktop windowing systems
	if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		var mode := DisplayServer.window_get_mode()
		var minimized := (mode == DisplayServer.WINDOW_MODE_MINIMIZED)
		if minimized != is_window_minimized:
			is_window_minimized = minimized
			_update_active_fps_cap()

func _set_focus_state(focused: bool) -> void:
	if is_window_focused == focused:
		return
	is_window_focused = focused
	_update_active_fps_cap()

func _update_active_fps_cap() -> void:
	if limit_fps_unfocused and (not is_window_focused or is_window_minimized):
		Engine.max_fps = UNFOCUSED_FPS_LIMIT
	else:
		match fps_mode:
			FPSMode.VSYNC:
				Engine.max_fps = 0
			FPSMode.CUSTOM_LIMIT:
				Engine.max_fps = custom_fps_limit
			FPSMode.UNLIMITED:
				Engine.max_fps = 0

func apply_settings() -> void:
	match fps_mode:
		FPSMode.VSYNC:
			current_vsync_mode = DisplayServer.VSYNC_ENABLED
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		FPSMode.CUSTOM_LIMIT:
			current_vsync_mode = DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		FPSMode.UNLIMITED:
			current_vsync_mode = DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_update_active_fps_cap()
	settings_changed.emit()

func get_vsync_mode() -> DisplayServer.VSyncMode:
	if DisplayServer.get_name() != "headless":
		return DisplayServer.window_get_vsync_mode()
	return current_vsync_mode

func set_fps_mode(mode: FPSMode) -> void:
	fps_mode = mode
	apply_settings()
	save_settings()

func set_custom_limit(limit: int) -> void:
	custom_fps_limit = clampi(limit, MIN_FPS, MAX_FPS)
	if fps_mode == FPSMode.CUSTOM_LIMIT:
		apply_settings()
	save_settings()

func set_limit_fps_unfocused(enabled: bool) -> void:
	limit_fps_unfocused = enabled
	_update_active_fps_cap()
	save_settings()

func get_fps_mode_string() -> String:
	match fps_mode:
		FPSMode.VSYNC:
			return "VSync"
		FPSMode.CUSTOM_LIMIT:
			return "Limit %d" % custom_fps_limit
		FPSMode.UNLIMITED:
			return "Unlimited"
	return "VSync"

func load_settings(path: String = SETTINGS_FILE) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	var perf: Dictionary = data.get("performance", {})
	if perf.is_empty():
		return false

	var mode_val: int = perf.get("fps_mode", int(FPSMode.VSYNC))
	if mode_val >= 0 and mode_val <= 2:
		fps_mode = mode_val as FPSMode
	else:
		fps_mode = FPSMode.VSYNC

	var custom_val: int = perf.get("custom_fps_limit", DEFAULT_CUSTOM_LIMIT)
	custom_fps_limit = clampi(custom_val, MIN_FPS, MAX_FPS)

	limit_fps_unfocused = perf.get("limit_fps_unfocused", true)
	return true

func save_settings(path: String = SETTINGS_FILE) -> bool:
	var existing_data := {}
	if FileAccess.file_exists(path):
		var read_file := FileAccess.open(path, FileAccess.READ)
		if read_file:
			var json := JSON.new()
			if json.parse(read_file.get_as_text()) == OK and json.data is Dictionary:
				existing_data = json.data

	existing_data["performance"] = {
		"fps_mode": int(fps_mode),
		"custom_fps_limit": custom_fps_limit,
		"limit_fps_unfocused": limit_fps_unfocused
	}

	var write_file := FileAccess.open(path, FileAccess.WRITE)
	if not write_file:
		push_error("Failed to open settings file for write: " + path)
		return false
	write_file.store_string(JSON.stringify(existing_data, "  "))
	return true
