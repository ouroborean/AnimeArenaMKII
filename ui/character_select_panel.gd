extends PanelContainer
class_name CharacterSelectPanel

signal reset_selected()
signal show_panel(character)
var color_filter = {}
var beginner_filtered = false
var buttons = {}
var page_number = 1
var filter_universes = []
@export var option_button: OptionButton
@export var category_option_button: OptionButton

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()
	
var character_list = []



static func from_character_list(characters, player):
	var panel = load("res://ui/character_select_panel.tscn").instantiate()
	print("Instantiated character select panel")
	for character in characters:
		panel.accept_character(character, player)
		print("Accepted " + character.path_name)
	print("Beginning button creation")
	panel.populate_container()
	
	return panel

func filter_by_color(colors):
	color_filter = colors
	populate_container()

func filter_by_beginner(on):
	beginner_filtered = on
	populate_container()

func apply_filters():
	var needed_colors = []
	
	for color in color_filter:
		if color_filter[color]:
			needed_colors.append(color)
	
	var passing_characters = []
	for character in character_list:
		if beginner_filtered:
			if not character.beginner:
				continue
		if option_button.get_selected_id() != 0:
			var universe_string = option_button.get_item_text(option_button.get_selected_id()).replace(" ", "_").to_upper()
			if not universe_string == "ANY":
				var concept = CharacterConcept.Universe[universe_string]
				if concept != character.universe:
					continue
		if category_option_button.get_selected_id() != 0:
			var category = category_option_button.get_item_text(category_option_button.get_selected_id()).to_lower()
			if not category in Bounty.flat_bounty_categories(character.path_name):
				continue
		if needed_colors != []:
			var valid = true
			for color in needed_colors:
				if not color in character.character_colors:
					valid = false
					break
			if not valid:
				continue
		passing_characters.append(character.path_name)
	
	
	
	return passing_characters
	

func accept_character(character, player):
	var button = CharacterButton.from_character(character)
	character_list.append(character)
	button.custom_minimum_size = Vector2(50, 50)
	buttons[character.path_name] = button
	if character.unlocked(player):
		button.set_unlocked()
	else:
		button.set_locked()
	button.button_clicked.connect(character_clicked)
	reset_selected.connect(button.set_unselected)

func update_buttons_locked_state(player):
	for button_key in buttons.keys():
		if buttons[button_key].character.unlocked(player):
			buttons[button_key].set_unlocked()
		for character in player.team.characters:
			if character.path_name == buttons[button_key].character.path_name:
				buttons[button_key].set_locked()

func populate_container():
	
	for child in $MarginContainer/HBoxContainer/GridContainer.get_children():
		$MarginContainer/HBoxContainer/GridContainer.remove_child(child)
	
	var characters = apply_filters()
	var char_min = (page_number - 1) * 21
	var char_max = page_number * 21
	var button_slice = characters.slice(char_min, char_max)
	for char_name in button_slice:
		$MarginContainer/HBoxContainer/GridContainer.add_child(buttons[char_name])
	print("Added buttons to container")

func character_clicked(character, locked):
	reset_selected.emit()
	show_panel.emit(character, locked)


# Called when the node enters the scene tree for the first time.
func _ready():
	var concepts = []
	for concept in CharacterConcept.Universe:
		concepts.append(concept.replace("_", " ").capitalize())
	concepts.sort()
	for concept in concepts:
		option_button.add_item(concept.replace("_", " ").capitalize())
	
	var categories = []
	for category in Bounty.get_archetype_list():
		categories.append(category.capitalize())
	categories.sort()
	for category in categories:
		category_option_button.add_item(category)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_right_button_button_down():
	if not page_number * 21 >= len(apply_filters()):
		page_number += 1
	else:
		page_number = 1
	populate_container()
	play_sound("click")


func _on_left_button_button_down():
	print("Got button click")
	if not page_number == 1:
		page_number -= 1
	else:
		page_number = ((len(apply_filters()) - 1) / 21) + 1
	populate_container()
	play_sound("click")


func _on_left_button_mouse_entered():
	play_sound("hover")


func _on_right_button_mouse_entered():
	play_sound("hover")


func _on_option_button_item_selected(index):
	populate_container()


func _on_category_option_button_item_selected(index):
	populate_container()
