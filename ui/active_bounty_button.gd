extends PanelContainer
class_name ActiveBountyButton

static func from_details(path_name):
	var bounty_button = load("res://ui/active_bounty_button.tscn").instantiate()
	bounty_button.ingest_details(path_name)
	return bounty_button

signal active_bounty_clicked(path_name)
var _path_name

# Called when the node enters the scene tree for the first time.
func _ready():
	mouse_entered.connect(func ():
		modulate = Color(1.0, 1.0, 1.0, 0.514)
	)
	mouse_exited.connect(func ():
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func ingest_details(path_name):
	_path_name = path_name
	var raw_path = path_name.trim_suffix(Bounty.MASTERY_SUFFIX)
	var character_instance = Character.from_character_name(raw_path)
	$MarginContainer/TextureRect.texture = character_instance.portrait_texture

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		active_bounty_clicked.emit(_path_name)
