extends Node

## Singleton manager for the Command Pattern undo/redo history in Stage-Builder.

signal history_changed(can_undo: bool, can_redo: bool)

@export var max_history: int = 100

var _undo_stack: Array[BaseCommand] = []
var _redo_stack: Array[BaseCommand] = []

func execute_command(cmd: BaseCommand) -> void:
	if cmd == null:
		return
	cmd.execute()
	_undo_stack.append(cmd)
	_redo_stack.clear()

	if _undo_stack.size() > max_history:
		_undo_stack.pop_front()

	history_changed.emit(can_undo(), can_redo())

func undo() -> bool:
	if not can_undo():
		return false

	var cmd: BaseCommand = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	history_changed.emit(can_undo(), can_redo())
	return true

func redo() -> bool:
	if not can_redo():
		return false

	var cmd: BaseCommand = _redo_stack.pop_back()
	cmd.execute()
	_undo_stack.append(cmd)
	history_changed.emit(can_undo(), can_redo())
	return true

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func get_undo_description() -> String:
	if can_undo():
		return _undo_stack.back().get_description()
	return ""

func get_redo_description() -> String:
	if can_redo():
		return _redo_stack.back().get_description()
	return ""

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	history_changed.emit(false, false)
