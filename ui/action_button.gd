extends PanelContainer
class_name ActionButton

var _action: Ability
var showing_mastery = false

@export var label: Label
@export var button: TextureButton

var important: bool

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()
	
signal ability_clicked(ability)
signal offer_panel(node)
signal offer_panelless(node)

static func from_action(action, in_game_desc=false):
	var button = load("res://ui/action_button.tscn").instantiate()
	button.set_action(action, false, in_game_desc)
	return button
	
static func from_display(ability):
	var button = load("res://ui/action_button.tscn").instantiate()
	button.set_display(ability)
	return button

func set_display(action):
	$MarginContainer/TextureButton.texture = load(action)

func set_action(action, force=false, in_game_desc=false):
	var image = action.return_image_with_mastery(action.user, force)
	$MarginContainer/TextureButton.texture = image
	important = in_game_desc
	_action = action
	if important and action.important:
		$PanelContainer.visible = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func set_unusable():
	$MarginContainer/TextureButton.modulate = Color.hex(0x303030ff)
	$MarginContainer/TextureButton/TextureRect.visible = true

func set_usable():
	$MarginContainer/TextureButton.modulate = Color.WHITE
	$MarginContainer/TextureButton/TextureRect.visible = false

func update(entity, action):
	set_action(action)
	if entity.battle.waiting_for_turn:
		modulate = Color.hex(0xffffff77)
	else:
		modulate = Color.WHITE
	if _action.cooldown_remaining > 0:
		$MarginContainer/CooldownLabel.text = str(int(_action.cooldown_remaining))
		$MarginContainer/CooldownLabel.visible = true
	else:
		$MarginContainer/CooldownLabel.visible = false
	if _action.usable(entity):
		set_usable()
	else:
		set_unusable()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#func _make_custom_tooltip(_text = "plurbus"):
#	return get_panel()

func toggle_mastery():
	showing_mastery = not showing_mastery
	if showing_mastery and _action.mastery_image != null:
		$MarginContainer/TextureButton.texture = _action.mastery_image
	else:
		$MarginContainer/TextureButton.texture = _action.image

func get_panel():
	return AbilityDescriptionPanel.from_description(_action.user, _action)

func get_panelless():
	return CharSelectAbilityDescription.from_description(_action.user, _action, showing_mastery)

func send_panel():
	offer_panel.emit(get_panel())

func send_panelless():
	offer_panelless.emit(get_panelless())

func set_hovered():
	pass

func stop_hovered():
	pass


func _on_texture_button_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		ability_clicked.emit(_action)
		play_sound("click")
		send_panel()
		send_panelless()


func _on_mouse_entered():
	var panel = get("theme_override_styles/panel")
	panel.bg_color = Color.hex(0xba000083)
	play_sound("hover")
	



func _on_mouse_exited():
	var panel = get("theme_override_styles/panel")
	panel.bg_color = Color.hex(0xffffff83)
