extends PanelContainer
class_name PrivateMatchSearchPanel

static func deploy():
	var panel = load("res://ui/private_match_search_panel.tscn").instantiate()
	
	return panel

signal target_confirmed(username)
signal close_panel()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func confirm_clicked():
	var target_username = $MarginContainer/VBoxContainer/MarginContainer2/TextEdit.text
	if target_username == "":
		return
	target_confirmed.emit(target_username)
	queue_free()


func decline_clicked():
	close_panel.emit()
	queue_free()
