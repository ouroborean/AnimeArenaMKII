extends PanelContainer

signal extra_clicked()
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

static func from_detail(detail):
	var button = load("res://ui/alpha_inforce_button.tscn").instantiate()
	
	button.set_detail(detail)
	
	return button

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		extra_clicked.emit()

func set_detail(detail):
	$MarginContainer/Label.text = detail

func _on_mouse_entered():
	modulate = Color.hex(0xffffffcc)


func _on_mouse_exited():
	modulate = Color.WHITE
