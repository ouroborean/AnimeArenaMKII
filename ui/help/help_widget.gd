extends Control
class_name HelpWidget

# Base class for every widget rendered inside the help canvas.
# Subclasses implement to_dict / apply_dict for save-load, and own _draw + drag.

signal widget_selected(widget)
signal widget_changed()

var author_mode := false
var selected := false

func set_author_mode(mode: bool) -> void:
	author_mode = mode
	mouse_filter = Control.MOUSE_FILTER_STOP if mode else Control.MOUSE_FILTER_IGNORE
	_on_author_mode_changed()
	queue_redraw()

func _on_author_mode_changed() -> void:
	pass

func set_selected_state(s: bool) -> void:
	if selected == s:
		return
	selected = s
	queue_redraw()

func to_dict() -> Dictionary:
	return {}

func apply_dict(_d: Dictionary) -> void:
	pass
