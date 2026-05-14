extends HelpRectWidget
class_name HelpHighlightWidget

# Highlight cuts a clear hole through the help canvas's HelpDimLayer (which
# subtracts this widget's rect from the dim region). Inside the rect, the
# underlying game UI shows through unaffected. The widget itself only draws
# the yellow outline that marks the highlighted region.

const OUTLINE := Color(1, 0.85, 0.2, 1)
const OUTLINE_WIDTH := 3.0

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(180, 80)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, OUTLINE_WIDTH)
	_draw_chrome()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["type"] = "highlight"
	return d
