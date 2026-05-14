extends HBoxContainer

signal confirm_class(character_class)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_texture_button_pressed():
	confirm_class.emit("none")
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func on_green_pressed():
	confirm_class.emit("green")
	queue_free()

func on_blue_pressed():
	confirm_class.emit("blue")
	queue_free()

func on_white_pressed():
	confirm_class.emit("white")
	queue_free()

func on_red_pressed():
	confirm_class.emit("red")
	queue_free()
