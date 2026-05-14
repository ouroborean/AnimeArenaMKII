extends HBoxContainer

signal close_panel()
signal confirm_disguise(character_name)



var disguise_name = "toga"

# Called when the node enters the scene tree for the first time.
func _ready():
	var all_chars = CharacterDatabase.get_characters()
	populate_from_char_list(all_chars)

func populate_from_char_list(char_list):
	
	for character in char_list:
		var button = CharacterButton.from_character(character)
		button.button_clicked.connect(character_clicked)
		$Control/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/GridContainer.add_child(button)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func character_clicked(character, locked):
	disguise_name = character.path_name
	$Control/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/CharacterButton.assign_character(character, false)

func _on_texture_button_pressed():
	queue_free()


func confirm_clicked():
	confirm_disguise.emit(disguise_name)
	queue_free()


func _on_texture_button_mouse_entered():
	$Control/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/TextureButton.modulate = Color.hex(0xffffff88)

func _on_texture_button_mouse_exited():
	$Control/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/TextureButton.modulate = Color.WHITE
