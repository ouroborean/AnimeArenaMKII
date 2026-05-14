extends Control
class_name NexusUniverseNode

var _universe

signal requested_universe(universe)


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

static func from_universe(universe):
	var node = load("res://ui/nexus_universe_node.tscn").instantiate()
	node.ingest_universe(universe)
	node.deploy()
	return node
	
func ingest_universe(universe):
	_universe = universe

func deploy():
	$UniverseLabel.text = CharacterConcept.Universe.keys()[_universe].capitalize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		requested_universe.emit(_universe)


func _on_mouse_entered():
	modulate = Color.DARK_RED
	play_sound("hover")



func _on_mouse_exited():
	modulate = Color.WHITE
