extends HBoxContainer


var _player

var action_frames = []
var character_frames = []
var hats = []
var ingame_backgrounds = ["background_ingame_default", "background_charselect_light", "background_charselect_default"]
var charselect_backgrounds = ["background_charselect_default"]
var playercards = ["playercard_color_default"]

signal close_panel()

var char_name_list = [
		"naruto",
		"sasuke",
		"sakura",
		"luffy",
		"zoro",
		"usopp",
		"midoriya",
		"uraraka",
		"bakugo",
		"natsu",
		"lucy",
		"gray",
		"madoka",
		"sayaka",
		"asta",
		"yuno",
		"noelle",
		"maka",
		"soul",
		"blackstar",
		"aang",
		"korra",
		"tatsumi",
		"akame",
		"sheele",
		"tanjiro",
		"nezuko",
		"zenitsu",
		"rengoku",
		"meliodas",
		"diane",
		"king",
		"tsunayoshi",
		"yamamoto",
		"ryohei",
		"xanxus",
		"eren",
		"mikasa",
		"saitama",
		"genos",
		"tatsumaki",
		"shinra",
		"tamaki",
		"gon",
		"killua",
		"kurapika",
		"misaka",
		"kuroko",
		"saber",
		"gilgamesh",
		"jack",
		"semiramis",
		"ryuko",
		"satsuki",
		"nonon",
		"ichigo",
		"ganta",
		"shiro",
		"ken",
		"touka",
		"rimuru",
		"machinedramon",
		"gatomon",
		"gallantmon",
		"byakuya",
		"mash",
		"nimaiya"
	]
var _char_list = []


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

var portraits = [
	"portrait_color_default",
	"portrait_color_red",
	"portrait_color_yellow",
	"portrait_color_orange",
	"portrait_color_cyan",
	"portrait_color_pink",
	"portrait_color_darkblue",
	"portrait_color_lightblue",
	"portrait_color_darkgreen",
	"portrait_color_lightgreen",
	"portrait_color_darkpurple",
	"portrait_color_lightpurple"
]

var game_panels = [
	"gamepanel_color_default",
	"gamepanel_color_gray",
	"gamepanel_color_yellow",
	"gamepanel_color_orange",
	"gamepanel_color_cyan",
	"gamepanel_color_pink",
	"gamepanel_color_darkblue",
	"gamepanel_color_lightblue",
	"gamepanel_color_darkgreen",
	"gamepanel_color_lightgreen",
	"gamepanel_color_darkpurple",
	"gamepanel_color_lightpurple",
]

static func from_player_and_list(player, char_list):
	var menu = load("res://ui/cosmetics_menu.tscn").instantiate()
	menu._char_list = CharacterDatabase.get_characters()
	menu.assign_player(player)
	return menu

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func initialize_characters():
	for char in char_name_list:
		var new_character = ResourceLoader.load("res://character/" + char + ".tscn").instantiate()
		new_character.initialize()
		_char_list.append(new_character)

func assign_player(player):
	_player = player
	get_unlocked_cosmetics(_char_list)
	get_owned_cosmetics(_player.unlocks)
	
	ingest_backgrounds()
	ingest_playercards()
	for i in range(3):
		var cosmetic_set = CharacterCosmeticSet.from_sets(character_frames, action_frames, hats, _player.equipped_character_frames[i], _player.equipped_action_frames[i], _player.equipped_hats[i])
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/BodyMargin/VBoxContainer.add_child(cosmetic_set)
	

func ingest_backgrounds():
	var index = 1
	for background in ingame_backgrounds:
		var cosmetic_info = background.split("_")
		var cosmetic_name = cosmetic_info[2].capitalize()
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/OptionButton.add_item(cosmetic_name, index)
		if _player.equipped_ingame_background == background:
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/OptionButton.selected = index
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/PanelContainer/TextureRect.texture = load("res://assets/backgrounds/" + _player.equipped_ingame_background + ".png")
		index += 1
	index = 1
	for background in ingame_backgrounds:
		var cosmetic_info = background.split("_")
		var cosmetic_name = cosmetic_info[2].capitalize()
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/OptionButton.add_item(cosmetic_name, index)
		if _player.equipped_charselect_background == background:
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/OptionButton.selected = index
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/PanelContainer/TextureRect.texture = load("res://assets/backgrounds/" + _player.equipped_charselect_background + ".png")
		index += 1

func ingest_playercards():
	var index = 1
	for playercard in playercards:
		var cosmetic_info = playercard.split("_")
		var cosmetic_name = cosmetic_info[2].capitalize()
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer2/OptionButton.add_item(cosmetic_name, index)
		if _player.equipped_player_card == playercard:
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer2/OptionButton.selected = index
			$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer2/PanelContainer/TextureRect.texture = load("res://assets/cosmetics/playercards/" + _player.equipped_player_card + ".png")
		index += 1

func get_owned_cosmetics(cosmetics_list):
	for cosmetic in cosmetics_list:
		if "unlock" in cosmetic:
			continue
		var sections = cosmetic.split("_")
		var cosmetic_type = sections[0]
		if cosmetic_type == "gamepanel":
			action_frames.append(cosmetic)
		elif cosmetic_type == "portrait":
			character_frames.append(cosmetic)
		elif cosmetic_type == "hat":
			hats.append(cosmetic)
		elif cosmetic_type == "background":
			if sections[1] == "charselect":
				charselect_backgrounds.append(cosmetic)
			elif sections[1] == "ingame":
				ingame_backgrounds.append(cosmetic)
		elif cosmetic_type == "playercard":
			playercards.append(cosmetic)
		

func get_unlocked_cosmetics(char_list):
	for character in char_list:
		var level = _player.get_mastery_score_from_character(character)
		var unlocks = MasteryConfig.get_unlocked_cosmetics_for_character(level, character.path_name)
		if unlocks["action_frame"]:
			action_frames.append(MasteryConfig.get_cosmetic_id("action_frame", character.path_name))
		if unlocks["elite_action_frame"]:
			action_frames.append(MasteryConfig.get_cosmetic_id("elite_action_frame", character.path_name))
		if unlocks["hat"]:
			hats.append(MasteryConfig.get_cosmetic_id("hat", character.path_name))
		if unlocks["playercard"]:
			playercards.append(MasteryConfig.get_cosmetic_id("playercard", character.path_name))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_option_button_item_selected(index):
	pass # Replace with function body.

func settle_chosen_cosmetics():
	_player.equipped_action_frames = []
	_player.equipped_character_frames = []
	_player.equipped_hats = []
	
	
	for cosmetic_set in $CosmeticsMenu/MarginContainer/ScrollContainer/Rows/BodyMargin/VBoxContainer.get_children():
		var chosen_set = cosmetic_set.report_chosen()
		
		_player.equipped_action_frames.append(chosen_set[1])
		_player.equipped_character_frames.append(chosen_set[0])
		_player.equipped_hats.append(chosen_set[2])
	
	
	


func _on_texture_button_pressed():
	settle_chosen_cosmetics()
	play_sound("click")
	close_panel.emit()


func _on_texture_button_mouse_entered():
	$MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")
	


func _on_texture_button_mouse_exited():
	$MarginContainer/TextureButton.modulate = Color.WHITE


func ingame_background_option_changed(index):
	play_sound("click")
	if index != 0:
		_player.equipped_ingame_background = ingame_backgrounds[index - 1]
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/PanelContainer/TextureRect.texture = load("res://assets/backgrounds/" + _player.equipped_ingame_background + ".png")


func charselect_background_option_changed(index):
	play_sound("click")
	if index != 0:
		_player.equipped_charselect_background = ingame_backgrounds[index - 1]
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/PanelContainer/TextureRect.texture = load("res://assets/backgrounds/" + _player.equipped_charselect_background + ".png")


func playercard_option_selected(index):
	play_sound("click")
	if index != 0:
		_player.equipped_player_card = playercards[index - 1]
		$CosmeticsMenu/MarginContainer/ScrollContainer/Rows/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer2/PanelContainer/TextureRect.texture = load("res://assets/cosmetics/playercards/" + _player.equipped_player_card + ".png")
