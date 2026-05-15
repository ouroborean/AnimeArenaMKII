extends HelpRectWidget
class_name HelpTextWidget

# Text panel widget. In author mode shows a TextEdit for typing; in player
# mode shows a Label. The widget is dragged by the border region (the 8px
# margin around the inner text node). Resize handle lives in the lower-right
# corner just outside the text-node area.

const BG := Color(0.04, 0.04, 0.04, 0.92)
const BORDER := Color(0.85, 0.85, 0.85, 1)
const FONT_COLOR := Color(1, 1, 1, 1)
const INNER_MARGIN := 8.0

var text_node: TextEdit
var label_node: Label

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(260, 110)
	_build_children()

func _build_children() -> void:
	text_node = TextEdit.new()
	text_node.placeholder_text = "Help text..."
	text_node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_node.add_theme_color_override("font_color", FONT_COLOR)
	text_node.add_theme_color_override("font_placeholder_color", Color(0.7, 0.7, 0.7, 0.7))
	# Transparent backgrounds so the widget's own _draw shows through.
	var empty := StyleBoxEmpty.new()
	text_node.add_theme_stylebox_override("normal", empty)
	text_node.add_theme_stylebox_override("focus", empty)
	text_node.add_theme_stylebox_override("read_only", empty)
	text_node.anchor_right = 1.0
	text_node.anchor_bottom = 1.0
	text_node.offset_left = INNER_MARGIN
	text_node.offset_top = INNER_MARGIN
	# Leave room on right/bottom for the resize handle.
	text_node.offset_right = -INNER_MARGIN - HANDLE_SIZE
	text_node.offset_bottom = -INNER_MARGIN - HANDLE_SIZE
	text_node.visible = false
	text_node.text_changed.connect(_on_text_changed)
	add_child(text_node)

	label_node = Label.new()
	label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_node.add_theme_color_override("font_color", FONT_COLOR)
	label_node.anchor_right = 1.0
	label_node.anchor_bottom = 1.0
	label_node.offset_left = INNER_MARGIN
	label_node.offset_top = INNER_MARGIN
	label_node.offset_right = -INNER_MARGIN
	label_node.offset_bottom = -INNER_MARGIN
	add_child(label_node)

	_apply_mode_visibility()

func _on_author_mode_changed() -> void:
	if text_node and label_node:
		_apply_mode_visibility()

func _apply_mode_visibility() -> void:
	text_node.visible = author_mode
	label_node.visible = not author_mode

func _on_text_changed() -> void:
	if label_node and text_node:
		label_node.text = text_node.text
	widget_changed.emit()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG)
	draw_rect(rect, BORDER, false, 1.5)
	_draw_chrome()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["type"] = "text"
	d["text"] = label_node.text if label_node else ""
	return d

func apply_dict(d: Dictionary) -> void:
	super.apply_dict(d)
	var t := str(d.get("text", ""))
	if label_node:
		label_node.text = t
	if text_node:
		text_node.text = t
