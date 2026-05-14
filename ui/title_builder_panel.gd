extends PanelContainer

signal title_dropped(title_component)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _drop_data(_position, data):
	print("Happening")
	data.get_parent().remove_child(data)
	$PanelInnerMargin/BuilderHBox.add_child(data)
	title_dropped.emit(data)

func _can_drop_data(at_position, data):
	print("Checking")
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
