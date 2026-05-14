extends VBoxContainer
class_name HPBar

var _max: float = 100
var _current: float = 100
var _new_hp: float = 100

var green = Color.hex(0x22b14c)
var yellow = Color.hex(0xedba2f)
var red = Color.hex(0xed2f2f)

@export var bar: ProgressBar
@export var label: Label

var _character
var _portrait_button: CharacterNameButton

static func from_character(character):
	var hpbar = load("res://ui/hp_bar_component.tscn").instantiate()
	hpbar.get_values_from_character(character)
	
	return hpbar
	
func link_portrait(portrait: CharacterNameButton):
	_portrait_button = portrait

func change_current(new_current):
	if _portrait_button:
		if new_current < _new_hp:
			_portrait_button.play_damage_flash()
		elif new_current > _new_hp:
			_portrait_button.play_heal_flash()
	_new_hp = new_current

func change_max(new_max):
	_max = new_max
	update()

func get_values_from_character(character):
	_character = character
	var hp_component = character.health
	hp_component.health_changed.connect(change_current)
	hp_component.max_changed.connect(change_max)
	change_max(character.get_modified_max_hp())
	change_current(hp_component.hp)

func update():
	if _character.hp_hidden():
		return
	change_color()
	bar.value = int((_current / _max) * 100)
	var label_value = int(_current)
	label.text = str(label_value) + " / " + str(int(_max))

func change_color():
	
	var panel = $PanelContainer.get("theme_override_styles/panel")
	var health_bar_fill = $HealthBar.get("theme_override_styles/fill")
	
	if _current > 75:
		health_bar_fill.bg_color = Color(.133, .694, .298)
		panel.border_color = Color(.133, .694, .298)
	elif _current > 35:
		health_bar_fill.bg_color = Color(.929, .729, .184)
		panel.border_color = Color(.929, .729, .184)
	else:
		health_bar_fill.bg_color = Color(.929, .184, .184)
		panel.border_color = Color(.929, .184, .184)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if _new_hp == _current:
		return
	if _new_hp < _current:
		_current -= 0.75
		if _current < _new_hp:
			_current = _new_hp
		update()
	elif _new_hp > _current:
		_current += 0.75
		if _current > _new_hp:
			_current = _new_hp
		update()
