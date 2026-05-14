extends PanelContainer

signal add_title()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func title_add_click(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		add_title.emit()
