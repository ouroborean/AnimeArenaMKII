extends HelpWidget
class_name HelpArrowWidget

# Arrow widget. Has two endpoints stored in canvas-local coords. The widget's
# rect is auto-sized to the endpoints' bounding box (plus a hit-test padding)
# so input only fires near the arrow itself.

const HANDLE_RADIUS := 8.0
const HIT_RADIUS := 14.0
const COLOR := Color(1, 0.85, 0.2, 1)
const SHAFT_WIDTH := 4.0
const HEAD_LENGTH := 18.0
const HEAD_WIDTH := 14.0

var from_point: Vector2 = Vector2(40, 40)
var to_point: Vector2 = Vector2(180, 100)

var drag_mode := ""  # "from", "to", "shaft", or ""
var drag_start_mouse := Vector2.ZERO
var drag_start_from := Vector2.ZERO
var drag_start_to := Vector2.ZERO

func _ready() -> void:
	_update_layout()

func _update_layout() -> void:
	var min_p := Vector2(min(from_point.x, to_point.x), min(from_point.y, to_point.y))
	var max_p := Vector2(max(from_point.x, to_point.x), max(from_point.y, to_point.y))
	var pad := Vector2(HIT_RADIUS, HIT_RADIUS)
	position = min_p - pad
	size = (max_p - min_p) + pad * 2.0
	queue_redraw()

func _hit_test(local_pos: Vector2) -> String:
	var f := from_point - position
	var t := to_point - position
	if local_pos.distance_to(f) <= HIT_RADIUS:
		return "from"
	if local_pos.distance_to(t) <= HIT_RADIUS:
		return "to"
	if _dist_to_segment(local_pos, f, t) <= HIT_RADIUS * 0.5:
		return "shaft"
	return ""

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var len_sq := ab.length_squared()
	if len_sq > 0.0:
		t = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

func _gui_input(event: InputEvent) -> void:
	if not author_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := _hit_test(event.position)
		if hit == "":
			return
		set_selected_state(true)
		widget_selected.emit(self)
		drag_mode = hit
		drag_start_mouse = get_viewport().get_mouse_position()
		drag_start_from = from_point
		drag_start_to = to_point
		accept_event()

func _process(_dt: float) -> void:
	if drag_mode == "":
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		drag_mode = ""
		widget_changed.emit()
		return
	var delta := get_viewport().get_mouse_position() - drag_start_mouse
	match drag_mode:
		"from":
			from_point = drag_start_from + delta
		"to":
			to_point = drag_start_to + delta
		"shaft":
			from_point = drag_start_from + delta
			to_point = drag_start_to + delta
	_update_layout()

func _draw() -> void:
	var f := from_point - position
	var t := to_point - position
	draw_line(f, t, COLOR, SHAFT_WIDTH, true)
	var dir := (t - f).normalized()
	if dir != Vector2.ZERO:
		var perp := Vector2(-dir.y, dir.x)
		var base := t - dir * HEAD_LENGTH
		var p1 := base + perp * (HEAD_WIDTH * 0.5)
		var p2 := base - perp * (HEAD_WIDTH * 0.5)
		draw_polygon(PackedVector2Array([t, p1, p2]), PackedColorArray([COLOR]))
	if author_mode:
		var hcol := Color(1, 0.6, 0.1, 1) if selected else Color(1, 1, 1, 0.7)
		draw_circle(f, HANDLE_RADIUS, hcol)
		draw_circle(t, HANDLE_RADIUS, hcol)

func to_dict() -> Dictionary:
	return {
		"type": "arrow",
		"from": [from_point.x, from_point.y],
		"to": [to_point.x, to_point.y]
	}

func apply_dict(d: Dictionary) -> void:
	if d.has("from") and d["from"] is Array and d["from"].size() == 2:
		from_point = Vector2(d["from"][0], d["from"][1])
	if d.has("to") and d["to"] is Array and d["to"].size() == 2:
		to_point = Vector2(d["to"][0], d["to"][1])
	_update_layout()
