extends PanelContainer
class_name TitleBuilderComponent

var _title
var dragged = false
var deployed = false

signal deploy_clicked(title_component)


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

static func from_title(title):
	var title_builder = load("res://ui/title_builder_component.tscn").instantiate()
	title_builder.assign_title(title)
	return title_builder

# Called when the node enters the scene tree for the first time.
func _ready():
	set_process_input(true)
	
func _input(ev):
	if ev is InputEventMouseButton and not ev.pressed:
		print("Mouse button released")



func _get_drag_data(ev_position):
	var preview = TitleBuilderComponent.from_title(_title)
	
	var c = Control.new()
	c.add_child(preview)
	preview.position.x = -ev_position.x
	preview.position.y = -ev_position.y
	preview.z_index = 15
	set_drag_preview(c)
	return self

func assign_title(title):
	_title = title
	$BuilderMargin/Label.text = title

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		play_sound("click")
		if deployed:
			deploy_clicked.emit(self)


func _on_mouse_entered():
	modulate = Color.hex(0xff362aff)
	play_sound("hover")


func _on_mouse_exited():
	modulate = Color.WHITE
