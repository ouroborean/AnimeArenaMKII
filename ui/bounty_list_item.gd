extends PanelContainer
class_name BountyListItem

signal character_clicked(path_name)

var path_name

static func from_character(character):
	var item = load("res://ui/bounty_list_item.tscn").instantiate()
	item.ingest_details(character)
	return item

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_details(character):
	path_name = character.path_name
	$BountyListItem/HBoxContainer/TextureRect.texture = character.portrait_texture
	$BountyListItem/HBoxContainer/Label.text = character.character_name

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_mouse_entered():
	modulate = Color(1.0, 1.0, 1.0, 0.478)


func _on_mouse_exited():
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		character_clicked.emit(path_name)
