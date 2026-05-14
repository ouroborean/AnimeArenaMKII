extends PanelContainer


signal filter_by_colors(colors)
signal filter_by_beginner(toggle)
signal randomize_team()

var filters = {
	0: false,
	1: false,
	2: false,
	3: false,
}

var beginner_toggle = false
var random_animating = false
var color_buttons = []

# Called when the node enters the scene tree for the first time.
func _ready():
	color_buttons = [
		$MarginContainer/VBoxContainer/VBoxContainer2/TextureRect,
		$MarginContainer/VBoxContainer/VBoxContainer2/TextureRect2,
		$MarginContainer/VBoxContainer/VBoxContainer2/TextureRect3,
		$MarginContainer/VBoxContainer/VBoxContainer2/TextureRect4
	]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update_filters():
	for i in range(4):
		if filters[i]:
			color_buttons[i].custom_minimum_size = Vector2(16, 16)
		else:
			color_buttons[i].custom_minimum_size = Vector2(10, 10)
	if beginner_toggle:
		$MarginContainer/VBoxContainer/VBoxContainer/PanelContainer.get("theme_override_styles/panel").bg_color = Color.AQUAMARINE
	else:
		$MarginContainer/VBoxContainer/VBoxContainer/PanelContainer.get("theme_override_styles/panel").bg_color = Color.MAROON
	

func green_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		filters[0] = not filters[0]
		update_filters()
		filter_by_colors.emit(filters)


func blue_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		filters[1] = not filters[1]
		update_filters()
		filter_by_colors.emit(filters)


func white_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		filters[2] = not filters[2]
		update_filters()
		filter_by_colors.emit(filters)


func red_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		filters[3] = not filters[3]
		update_filters()
		filter_by_colors.emit(filters)


func beginner_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		randomize_team.emit()
		if not random_animating:
			random_animating = true
			var rect = $MarginContainer/VBoxContainer/VBoxContainer/PanelContainer/MarginContainer/TextureRect
			var tween = create_tween()
			tween.tween_property(rect, "position", Vector2(rect.position.x, rect.position.y + 5), 0.03)
			tween.tween_property(rect, "position", Vector2(rect.position.x, rect.position.y), 0.03)
			tween.tween_callback(func (): random_animating = false)
			
