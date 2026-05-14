extends Control

signal button_clicked()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		button_clicked.emit()


func _on_mouse_entered():
	modulate = Color.hex(0xff2d21ff)


func _on_mouse_exited():
	modulate = Color.WHITE
