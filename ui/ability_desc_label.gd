extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_base_label(string):
	text = string

func set_sub_label(string):
	var label_sett = load("res://ui/char_desc_sub_label.tres")
	label_settings = label_sett
	text = string

func set_color_label(string, color):
	var label_sett = load("res://ui/char_desc_sub_label.tres").duplicate()
	label_sett.font_color = color
	label_settings = label_sett
	text = string

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
