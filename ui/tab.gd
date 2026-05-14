extends VBoxContainer

signal tab_selected(tab)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_panel_tab_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		tab_selected.emit(self)
		z_index = 3
