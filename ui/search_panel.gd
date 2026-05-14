extends PanelContainer



signal cancel_search()



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func match_found():
	queue_free()

func cancel_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Cancelling Search!")
		cancel_search.emit()
		queue_free()
