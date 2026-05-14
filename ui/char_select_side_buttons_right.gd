extends VBoxContainer

signal clan_button_clicked()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func on_clan_button_clicked():
	print("Clan button clicked")
	clan_button_clicked.emit()


func _on_texture_button_2_mouse_entered():
	$TextureButton2.modulate = Color.hex(0xffffff80)


func _on_texture_button_2_mouse_exited():
	$TextureButton2.modulate = Color.WHITE
