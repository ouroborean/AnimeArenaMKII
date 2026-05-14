extends Container


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func tab_selected(tab):
	print("A tab was selected!")
	print(tab)
	for child in get_children():
		if not child == tab:
			child.z_index = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
