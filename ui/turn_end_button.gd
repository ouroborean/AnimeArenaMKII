extends PanelContainer

signal turn_end_clicked()
var waiting = false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_texture_button_button_down():
	if not waiting:
		print("Turn End Button Pressed")
		#play_sound("click")
		turn_end_clicked.emit()

func set_waiting():
	$MarginContainer/Label.text = "Waiting..."
	waiting = true

func stop_waiting():
	$MarginContainer/Label.text = "End Turn"
	waiting = false

func set_hovered():
	modulate = Color.hex(0xffffff88)
	play_sound("hover")

func stop_hovered():
	modulate = Color.WHITE
