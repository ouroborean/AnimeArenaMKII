extends Control
class_name CharacterButton
signal button_clicked(char, locked)

var locked = false

static func from_character(char, enemy=false) -> CharacterButton:
	var button = load("res://ui/character_button.tscn").instantiate()
	button.assign_character(char, enemy)
	return button

var character

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"character_click": load("res://assets/sounds/champ_select.mp3"),
	"soft_click": load("res://assets/sounds/soft_click.mp3"),
	"hard_click": load("res://assets/sounds/hard_clatter.mp3"),
	"pop": load("res://assets/sounds/pop.mp3"),
	"soft_clatter": load('res://assets/sounds/soft_clatter.mp3'),
	
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func assign_character(char, enemy):
	character = char
	
	$MarginContainer/TextureRect.texture = character.portrait_texture
	if enemy:
		$MarginContainer/TextureRect.flip_h = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func tooltip_mode():
	$MarginContainer/TextureRect.expand_mode = $MarginContainer/TextureRect.EXPAND_FIT_HEIGHT



func set_locked():
	locked = true
	modulate = Color.hex(0x696969ff)

func set_unlocked():
	locked = false
	modulate = Color.WHITE

func set_selected():
	pass
	
func set_unselected():
	pass

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		button_clicked.emit(character, locked)
		set_selected()


func _on_mouse_entered():
	var panel = get("theme_override_styles/panel")
	panel.bg_color = Color.RED


func _on_mouse_exited():
	var panel = get("theme_override_styles/panel")
	panel.bg_color = Color.WHITE


func _on_texture_rect_mouse_entered():
	play_sound("soft_click")


func _on_texture_button_pressed():
	pass # Replace with function body.
