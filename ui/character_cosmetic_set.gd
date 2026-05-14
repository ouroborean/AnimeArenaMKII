extends MarginContainer
class_name CharacterCosmeticSet

var _character_frames
var _action_frames
var _hats
var chosen_character = "portrait_color_default"
var chosen_action = "gamepanel_color_default"
var chosen_hat = "none"
var initial_char_index = 0
var initial_action_index = 0
var initial_hat_index = 0

@onready var frame_option = $HBoxContainer/LeftBox/FrameOption
@onready var hat_option = $HBoxContainer/LeftBox/HatOption
@onready var skill_option = $HBoxContainer/RightBox/SkillPanelOption
@onready var portrait_texture = $HBoxContainer/LeftBox/PortraitTexture
@onready var hat_overlay = $HBoxContainer/LeftBox/PortraitTexture/HatOverlay
@onready var skill_texture = $HBoxContainer/RightBox/SkillPanelTexture

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

static func from_sets(character_frame_set, action_frame_set, hat_set, _player_char_choice, _player_action_choice, _player_hat_choice):
	var cosm_set = load("res://ui/character_cosmetic_set.tscn").instantiate()
	cosm_set._pending_assign = [character_frame_set, action_frame_set, hat_set, _player_char_choice, _player_action_choice, _player_hat_choice]
	return cosm_set

var _pending_assign = null

func _ready():
	if _pending_assign != null:
		var args = _pending_assign
		_pending_assign = null
		assign_options(args[0], args[1], args[2], args[3], args[4], args[5])

func assign_options(character_frames, action_frames, hats, _player_char_choice, _player_action_choice, _player_hat_choice):
	var index = 1
	_character_frames = character_frames
	_action_frames = action_frames
	_hats = hats
	for key in character_frames:
		frame_option.add_item(peel_family(key).capitalize(), index)
		if key == _player_char_choice:
			initial_char_index = index
		index += 1
	index = 1
	for key in action_frames:
		skill_option.add_item(peel_family(key).capitalize(), index)
		if key == _player_action_choice:
			initial_action_index = index
		index += 1
	index = 1
	for key in hats:
		hat_option.add_item(peel_family(key).capitalize(), index)
		if key == _player_hat_choice:
			initial_hat_index = index
		index += 1

	frame_option.selected = initial_char_index
	character_frame_option_selected(initial_char_index)
	skill_option.selected = initial_action_index
	action_frame_option_selected(initial_action_index)
	hat_option.selected = initial_hat_index
	hat_selected(initial_hat_index)


func peel_family(key):
	if key.split("_")[2] == "elite":
		return "Elite" + key.split("_")[3].capitalize()
	return key.split("_")[2]


func report_chosen():
	return [chosen_character, chosen_action, chosen_hat]

func character_frame_option_selected(index):
	play_sound("click")
	if index != 0:
		chosen_character = _character_frames[index - 1]
	else:
		chosen_character = "portrait_color_default"
	portrait_texture.texture = load("res://assets/cosmetics/character_frames/" + chosen_character + ".png")


func action_frame_option_selected(index):
	play_sound("click")
	if index != 0:
		chosen_action = _action_frames[index - 1]
	else:
		chosen_action = "gamepanel_color_default"
	skill_texture.texture = load("res://assets/cosmetics/game_panels/" + chosen_action + ".png")


func hat_selected(index):
	play_sound("click")
	if index != 0:
		chosen_hat = _hats[index - 1]
		hat_overlay.texture = load("res://assets/cosmetics/character_baubles/" + chosen_hat + ".png")
		hat_overlay.visible = true
	else:
		chosen_hat = "none"
		hat_overlay.visible = false


func _on_option_button_mouse_entered():
	play_sound("hover")


func _on_option_button_2_mouse_entered():
	play_sound("hover")
