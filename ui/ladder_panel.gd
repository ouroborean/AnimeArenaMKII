extends HBoxContainer
class_name LadderPanel


signal request_ladder(panel)
signal change_panel(panel)
signal close_panel()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func request_ladder_information():
	request_ladder.emit(self)

func accept_ladder_data(data):
	#Data will be a list of dictionaries of ladder relevant statistics
	var count = 1
	for data_set in data["player_data"]:
		var record = Vector2(data_set['wins'], data_set['losses'])
		var rating = data_set['rating']
		var clan_name = data_set['clan_name']
		var username = data_set['username']
		var row = load("res://ui/ladder_row.tscn").instantiate()
		$Control/MarginContainer3/VBoxContainer/MarginContainer2/VBoxContainer/ScrollContainer/VBoxContainer.add_child(row)
		row.ingest_details(username, rating, record, clan_name, count)
		count += 1
	count = 1
	for data_set in data["clan_data"]:
		var record = Vector2(data_set['wins'], data_set['losses'])
		var rating = str(data_set['level'])
		var clan_name = str(data_set['members'])
		var username = data_set['clan_name']
		var row = load("res://ui/ladder_row.tscn").instantiate()
		$Control/MarginContainer3/VBoxContainer/MarginContainer2/VBoxContainer/ScrollContainer2/VBoxContainer.add_child(row)
		row.ingest_details(username, rating, record, clan_name, count)
		count += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_texture_button_mouse_entered():
	$MarginContainer4/TextureButton.modulate = Color.hex(0xffffff80)


func _on_texture_button_mouse_exited():
	$MarginContainer4/TextureButton.modulate = Color.WHITE


func _on_texture_button_pressed():
	close_panel.emit()
