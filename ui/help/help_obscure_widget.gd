extends HelpRectWidget
class_name HelpObscureWidget

# The full-opacity black fill for an obscure region is painted by the help
# canvas's HelpDimLayer (it reads this widget's rect). This widget therefore
# renders nothing of its own except author-mode chrome.

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(220, 90)

func _draw() -> void:
	_draw_chrome()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["type"] = "obscure"
	return d
