class_name PlatformUtils
extends Node

## Platform and OS utility functions for Stage-Builder.
## Provides cross-platform shortcut strings, modifier key detection, and trackpad support.

static func is_macos() -> bool:
	return OS.has_feature("macos")

static func is_windows() -> bool:
	return OS.has_feature("windows")

static func get_modifier_name() -> String:
	return "Cmd" if is_macos() else "Ctrl"

static func is_primary_modifier_pressed(event: InputEvent) -> bool:
	if not (event is InputEventWithModifiers):
		return false
	var ev := event as InputEventWithModifiers
	if is_macos():
		return ev.meta_pressed
	else:
		return ev.ctrl_pressed

static func format_shortcut(key_name: String, shift: bool = false, alt: bool = false) -> String:
	var mod := get_modifier_name()
	var parts: Array[String] = []
	if mod != "":
		parts.append(mod)
	if alt:
		parts.append("Option" if is_macos() else "Alt")
	if shift:
		parts.append("Shift")
	parts.append(key_name)
	return " + ".join(parts)

