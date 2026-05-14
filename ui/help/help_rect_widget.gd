extends HelpWidget
class_name HelpRectWidget

# Intermediate base for rectangular widgets (obscure / highlight / text).
# Handles drag + bottom-right resize handle in author mode. Drag uses a poll
# in _process so the widget keeps moving even when the cursor leaves its rect.

const HANDLE_SIZE := 12.0
const MIN_SIZE := Vector2(40, 40)

var dragging := false
var resizing := false
var drag_start_mouse := Vector2.ZERO
var drag_start_pos := Vector2.ZERO
var drag_start_size := Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if not author_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			set_selected_state(true)
			widget_selected.emit(self)
			drag_start_mouse = get_viewport().get_mouse_position()
			drag_start_pos = position
			drag_start_size = size
			if _in_resize_handle(event.position):
				resizing = true
			else:
				dragging = true
			accept_event()

func _process(_dt: float) -> void:
	if not (dragging or resizing):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		resizing = false
		widget_changed.emit()
		return
	var current := get_viewport().get_mouse_position()
	var delta := current - drag_start_mouse
	if dragging:
		position = drag_start_pos + delta
	elif resizing:
		var new_size := drag_start_size + delta
		size = Vector2(max(new_size.x, MIN_SIZE.x), max(new_size.y, MIN_SIZE.y))
		_on_size_changed()
		queue_redraw()

# Override in subclasses that need to react to resize.
func _on_size_changed() -> void:
	pass

func _in_resize_handle(local_pos: Vector2) -> bool:
	var r := Rect2(size - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE, HANDLE_SIZE))
	return r.has_point(local_pos)

func _draw_chrome() -> void:
	if not author_mode:
		return
	var border := Color(1, 0.6, 0.1, 1) if selected else Color(1, 1, 1, 0.5)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)
	draw_rect(Rect2(size - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE, HANDLE_SIZE)), border)

func to_dict() -> Dictionary:
	return {
		"rect": [position.x, position.y, size.x, size.y]
	}

func apply_dict(d: Dictionary) -> void:
	if d.has("rect") and d["rect"] is Array and d["rect"].size() == 4:
		var r = d["rect"]
		position = Vector2(r[0], r[1])
		size = Vector2(r[2], r[3])
		_on_size_changed()
