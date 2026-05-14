extends PanelContainer
class_name GameMenuButton

signal button_clicked(package)

var button_payload

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func on_click():
	button_clicked.emit(button_payload)
