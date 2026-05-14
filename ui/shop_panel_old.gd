extends Control


signal close_panel()

signal make_purchase(ap, unlock_name)

var _player
var purchasing = false
var confirmation_panel
var current_display_type

var shop_items = {
	"gamepanel": shop_game_panels,
	"portrait": shop_portraits
}

var shop_game_panels = [
	["gamepanel_color_cyan", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_cyan.png"), "Action Panel - Cyan", 800],
	["gamepanel_color_pink", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_pink.png"), "Action Panel - Pink", 800],
	["gamepanel_color_yellow", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_yellow.png"), "Action Panel - Yellow", 800],
	["gamepanel_color_orange", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_orange.png"), "Action Panel - Orange", 800],
	["gamepanel_color_gray", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_gray.png"), "Action Panel - Gray", 800],
	["gamepanel_color_lightgreen", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_lightgreen.png"), "Action Panel - Light Green", 800],
	["gamepanel_color_lightblue", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_lightblue.png"), "Action Panel - Light Blue", 800],
	["gamepanel_color_lightpurple", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_lightpurple.png"), "Action Panel - Light Purple", 800],
	["gamepanel_color_darkgreen", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_darkgreen.png"), "Action Panel - Dark Green", 800],
	["gamepanel_color_darkblue", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_darkblue.png"), "Action Panel - Dark Blue", 800],
	["gamepanel_color_darkpurple", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_darkpurple.png"), "Action Panel - Dark Purple", 800],
	["gamepanel_color_digivice", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_digivice.png"), "Action Panel - Digivice", 1000],
	["gamepanel_color_fire", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_fire.png"), "Action Panel - Fire", 1000],
	["gamepanel_color_lightning", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_lightning.png"), "Action Panel - Lightning", 1000],
	["gamepanel_color_ocean", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_color_ocean.png"), "Action Panel - Ocean", 1000],
	["gamepanel_treasure_emerald", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_emerald.png"), "Action Panel - Emerald", 1000],
	["gamepanel_treasure_emeraldonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_emeraldonyx.png"), "Action Panel - Emerald (Onyx)", 1000],
	["gamepanel_treasure_amethyst", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_amethyst.png"), "Action Panel - Amethyst", 1000],
	["gamepanel_treasure_amethystonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_amethystonyx.png"), "Action Panel - Amethyst (Onyx)", 1000],
	["gamepanel_treasure_diamond", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_diamond.png"), "Action Panel - Diamond", 1000],
	["gamepanel_treasure_diamondonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_diamondonyx.png"), "Action Panel - Diamond (Onyx)", 1000],
	["gamepanel_treasure_ruby", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_ruby.png"), "Action Panel - Ruby", 1000],
	["gamepanel_treasure_rubyonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_rubyonyx.png"), "Action Panel - Ruby (Onyx)", 1000],
	["gamepanel_treasure_sapphire", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_sapphire.png"), "Action Panel - Sapphire", 1000],
	["gamepanel_treasure_sapphireonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_sapphireonyx.png"), "Action Panel - Sapphire (Onyx)", 1000],
	["gamepanel_treasure_topaz", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_topaz.png"), "Action Panel - Topaz", 1000],
	["gamepanel_treasure_topazonyx", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_topazonyx.png"), "Action Panel - Topaz (Onyx)", 1000],
	["gamepanel_treasure_silver", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_silver.png"), "Action Panel - Silver", 1000],
	["gamepanel_treasure_gold", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_gold.png"), "Action Panel - Gold", 1000],
	["gamepanel_treasure_platinum", "gamepanel", load("res://assets/cosmetics/game_panels/gamepanel_treasure_platinum.png"), "Action Panel - Platinum", 1000],
]

var shop_portraits = [
	["portrait_color_red", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_red.png"), "Portrait Frame - Red", 1000],
	["portrait_color_cyan", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_cyan.png"), "Portrait Frame - Cyan", 1000],
	["portrait_color_pink", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_pink.png"), "Portrait Frame - Pink", 1000],
	["portrait_color_yellow", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_yellow.png"), "Portrait Frame - Yellow", 1000],
	["portrait_color_orange", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_orange.png"), "Portrait Frame - Orange", 1000],
	["portrait_color_lightgreen", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_lightgreen.png"), "Portrait Frame - Light Green", 1000],
	["portrait_color_lightblue", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_lightblue.png"), "Portrait Frame - Light Blue", 1000],
	["portrait_color_lightpurple", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_lightpurple.png"), "Portrait Frame - Light Purple", 1000],
	["portrait_color_darkgreen", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_darkgreen.png"), "Portrait Frame - Dark Green", 1000],
	["portrait_color_darkblue", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_darkblue.png"), "Portrait Frame - Dark Blue", 1000],
	["portrait_color_darkpurple", "portrait", load("res://assets/cosmetics/character_frames/portrait_color_darkpurple.png"), "Portrait Frame - Dark Purple", 1000],
	["portrait_frame_emerald", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_emerald.png"), "Portrait Frame - Emerald", 1000],
	["portrait_frame_emerald-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_emerald-onyx.png"), "Portrait Frame - Emerald (Onyx)", 1000],
	["portrait_frame_amethyst", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_amethyst.png"), "Portrait Frame - Amethyst", 1000],
	["portrait_frame_amethyst-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_amethyst-onyx.png"), "Portrait Frame - Amethyst (Onyx)", 1000],
	["portrait_frame_diamond", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_diamond.png"), "Portrait Frame - Diamond", 1000],
	["portrait_frame_diamond-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_diamond-onyx.png"), "Portrait Frame - Diamond (Onyx)", 1000],
	["portrait_frame_ruby", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_ruby.png"), "Portrait Frame - Ruby", 1000],
	["portrait_frame_ruby-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_ruby-onyx.png"), "Portrait Frame - Ruby (Onyx)", 1000],
	["portrait_frame_sapphire", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_sapphire.png"), "Portrait Frame - Sapphire", 1000],
	["portrait_frame_sapphire-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_sapphire-onyx.png"), "Portrait Frame - Sapphire (Onyx)", 1000],
	["portrait_frame_topaz", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_topaz.png"), "Portrait Frame - Topaz", 1000],
	["portrait_frame_topaz-onyx", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_topaz-onyx.png"), "Portrait Frame - Topaz (Onyx)", 1000],
	["portrait_frame_silver", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_silver.png"), "Portrait Frame - Silver", 1000],
	["portrait_frame_gold", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_gold.png"), "Portrait Frame - Gold", 1000],
	["portrait_frame_platinum", "portrait", load("res://assets/cosmetics/character_frames/portrait_frame_platinum.png"), "Portrait Frame - Platinum", 1000],
]

var shop_characters = [
		["xanxus_unlock", "character", load("res://assets/images/Xanxus/xanxusprof.png"), "Xanxus", 750],
		["rengoku_unlock", "character", load("res://assets/images/Kyojuro Rengoku/rengokuprof.png"), "Kyojuro Rengoku", 750],
		["machinedramon_unlock", "character", load("res://assets/images/Machinedramon/machinedramonprof.png"), "Machinedramon", 750],
		["semiramis_unlock", "character", load("res://assets/images/Semiramis/semiramisprof.png"), "Semiramis", 750],
		["blackstar_unlock", "character", load("res://assets/images/Black Star/blackstarprof.png"), "Black Star", 750],
		["byakuya_unlock", "character", load('res://assets/images/Byakuya Kuchiki/byakuyaprof.png'), "Byakuya Kuchiki", 750],
		["gatomon_unlock", "character", load('res://assets/images/Gatomon/gatomonprof.png'), "Gatomon", 750],
		["gallantmon_unlock", "character", load('res://assets/images/Gallantmon/gallantmonprof.png'), "Gallantmon", 750],
		["mash_unlock", "character", load('res://assets/images/Mash Kyrielight/mashprof.png'), "Mash Kyrielight", 750],
		["nimaiya_unlock", "character", load('res://assets/images/Nimaiya Oetsu/nimaiyaprof.png'), "Nimaiya Oetsu", 750],
		["toga_unlock", "character", load('res://assets/images/Himiko Toga/togaprof.png'), "Himiko Toga", 750],
		["mars_unlock", "character", load('res://assets/images/Sailor Mars/sailormarsprofolder.png'), "Sailor Mars", 750],
		["frankenstein_unlock", "character", load('res://assets/images/Frankenstein/frankensteinprof.png'), "Frankenstein", 750],
		["ace_unlock", "character", load('res://assets/images/Ace/aceprof.png'), "Ace", 750],
		["hinata_unlock", "character", load('res://assets/images/Hinata Hyuga/hinataprof.png'), "Hinata", 750],
		["megumin_unlock", "character", load("res://assets/images/Megumin/meguminprof.png"), "Megumin", 750],
		["emiyaarcher_unlock", "character", load("res://assets/images/Emiya Archer/emiyaarcherprof.png"), "EMIYA", 750],
		["shokuhou_unlock", "character", load("res://assets/images/Shokuhou Misaki/shokuhouprof.png"), "Shokuhou", 750],
		["hisoka_unlock", "character", load("res://assets/images/Hisoka Morow/hisokaprof.png"), "Hisoka", 750],
		["neferpitou_unlock", "character", load("res://assets/images/Neferpitou/neferpitouprof.png"), "Neferpitou", 750],
		["ban_unlock", "character", load("res://assets/images/Ban/banprof.png"), "Ban", 750],
		["saturn_unlock", "character", load("res://assets/images/Sailor Saturn/saturnprof.png"), "Sailor Saturn", 750],
		["boruto_unlock", "character", load("res://assets/images/Uzumaki Boruto/borutoprof.png"), "Uzumaki Boruto", 750],
		["inuyasha_unlock", "character", load("res://assets/images/Inuyasha/inuyashaprof.png"), "Inuyasha", 750],
		["crona_unlock", "character", load("res://assets/images/Crona/cronaprof.png"), "Crona", 750],
		["marco_unlock", "character", load("res://assets/images/Marco/marcoprof.png"), "Marco", 750],
		["gohan_unlock", "character", load("res://assets/images/Gohan/gohanprof.png"), "Gohan", 750],
		["yugi_unlock", "character", load("res://assets/images/Yugi Mutou/yugiprof.png"), "Yugi", 750],
		["tokoyami_unlock", "character", load("res://assets/images/Fumikage Tokoyami/tokoyamiprof.png"), "Tokoyami", 750],
		["kid_unlock", "character", load("res://assets/images/Death the Kid/kidprof.png"), "Kid", 750],
		["orihime_unlock", "character", load("res://assets/images/Orihime Inoue/orihimeprof.png"), "Orihime", 750],
		["kaiba_unlock", "character", load("res://assets/images/Seto Kaiba/kaibaprof.png"), "Kaiba", 750],
		["shinoa_unlock", "character", load("res://assets/images/Hiragi Shinoa/shinoaprof.png"), "Shinoa", 750],
		["uzui_unlock", "character", load("res://assets/images/Tengen Uzui/uzuiprof.png"), "Tengen", 750],
		["tsuyu_unlock", "character", load("res://assets/images/Tsuyu Asui/tsuyuprof.png"), "Tsuyu", 750],
	]

var shop_backgrounds = [
	["background_ingame_shiro", "background", load("res://assets/backgrounds/background_ingame_shiro.png"), "Shiro - In-Game Background", 750],
	["background_ingame_akame", "background", load("res://assets/backgrounds/background_ingame_akame.png"), "Akame - In-Game Background", 750],
	["background_ingame_jack", "background", load("res://assets/backgrounds/background_ingame_jack.png"), "Jack - In-Game Background", 750],
	["background_ingame_saber", "background", load("res://assets/backgrounds/background_ingame_saber.png"), "Saber Alter - In-Game Background", 750],
	["background_ingame_nezuko", "background", load("res://assets/backgrounds/background_ingame_nezuko.png"), "Nezuko - In-Game Background", 750],
	["background_ingame_gatomon", "background", load("res://assets/backgrounds/background_ingame_gatomon.png"), "Angewomon - In-Game Background", 750],
]

var shop_playercards = [
	["playercard_color_cyan", "playercard", load("res://assets/cosmetics/playercards/playercard_color_cyan.png"), "Player Card - Cyan", 600],
	["playercard_color_darkblue", "playercard", load("res://assets/cosmetics/playercards/playercard_color_darkblue.png"), "Player Card - Dark Blue", 600],
	["playercard_color_darkpurple", "playercard", load("res://assets/cosmetics/playercards/playercard_color_darkpurple.png"), "Player Card - Dark Purple", 600],
	["playercard_color_green", "playercard", load("res://assets/cosmetics/playercards/playercard_color_green.png"), "Player Card - Green", 600],
	["playercard_color_lightblue", "playercard", load("res://assets/cosmetics/playercards/playercard_color_lightblue.png"), "Player Card - Light Blue", 600],
	["playercard_color_lightgreen", "playercard", load("res://assets/cosmetics/playercards/playercard_color_lightgreen.png"), "Player Card - Light Green", 600],
	["playercard_color_lightpurple", "playercard", load("res://assets/cosmetics/playercards/playercard_color_lightpurple.png"), "Player Card - Light Purple", 600],
	["playercard_color_magenta", "playercard", load("res://assets/cosmetics/playercards/playercard_color_magenta.png"), "Player Card - Magenta", 600],
	["playercard_color_orange", "playercard", load("res://assets/cosmetics/playercards/playercard_color_orange.png"), "Player Card - Orange", 600],
	["playercard_color_pink", "playercard", load("res://assets/cosmetics/playercards/playercard_color_pink.png"), "Player Card - Pink", 600],
	["playercard_color_red", "playercard", load("res://assets/cosmetics/playercards/playercard_color_red.png"), "Player Card - Red", 600],
	["playercard_color_yellow", "playercard", load("res://assets/cosmetics/playercards/playercard_color_yellow.png"), "Player Card - Yellow", 600],
	
]

	
#unlock_name, unlock_type, unlock_image, display_name, price
static func new_shop_panel(player):
	var panel = load("res://ui/shop_panel.tscn").instantiate()
	panel.ingest_player(player)
	return panel


# Called when the node enters the scene tree for the first time.
func _ready():
	
	shop_items = {
		"gamepanel": shop_game_panels,
		"portrait": shop_portraits,
		"background": shop_backgrounds,
		"playercard": shop_playercards
	}




func ingest_player(player):
	_player = player
	update_ap_label()
	

func show_buttons_by_type(cosmetic_type):
	current_display_type = cosmetic_type
	var buttons = []
	var grid_columns = 0
	print("Opening list of rewards of type " + cosmetic_type)
	print("Player unlocks at time of opening " + str(_player.unlocks))
	for item in shop_items[cosmetic_type]:
		print("Checking item " + item[0])
		if not item[0] in _player.unlocks:
			var button = load("res://ui/shop_button.tscn").instantiate()
			button.set_details(item[0], item[1], item[2], item[3], item[4])
			button.button_clicked.connect(item_selected)
			buttons.append(button)
	if cosmetic_type == "gamepanel":
		grid_columns = 1
	elif cosmetic_type == "character":
		grid_columns = 5
	elif cosmetic_type == "portrait":
		grid_columns = 3
	elif cosmetic_type == "background":
		grid_columns = 2
	elif cosmetic_type == "playercard":
		grid_columns = 2
		
	add_shop_buttons(buttons, grid_columns)

func update_ap_label():
	$HBoxContainer/PanelContainer/VBoxContainer/MarginContainer/HBoxContainer/Label2.text = str(int(_player.ap))

func item_selected(price, unlock_name, display_name):
	print("Player wants to purchase " + display_name + " (" + unlock_name + ") for " + str(price) + " AP!")
	if _player.ap < price:
		return
	if purchasing:
		return
	var panel = load("res://ui/shop_purchase_confirmation_panel.tscn").instantiate()
	panel.ingest_details(price, _player.ap, display_name, unlock_name)
	panel.close_panel.connect(close_confirmation_panel)
	panel.confirmed_purchase.connect(confirm_purchase)
	purchasing = true
	confirmation_panel = panel
	$HBoxContainer/PanelContainer.add_child(confirmation_panel)

func close_confirmation_panel():
	purchasing = false
	confirmation_panel.queue_free()
	confirmation_panel = null

func confirm_purchase(unlock_name, price):
	print("Player successfully purchased " + unlock_name)
	make_purchase.emit(price, unlock_name)
	update_ap_label()
	show_buttons_by_type(current_display_type)

func add_shop_buttons(buttons, grid_columns):
	for child in $HBoxContainer/PanelContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/GridContainer.get_children():
		child.queue_free()
	$HBoxContainer/PanelContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/GridContainer.columns = grid_columns
	for button in buttons:
		$HBoxContainer/PanelContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/GridContainer.add_child(button)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func close_clicked():
	close_panel.emit()



func skill_panel_pressed():
	show_buttons_by_type("gamepanel")


func char_frame_pressed():
	show_buttons_by_type("portrait")


func char_pressed():
	show_buttons_by_type("character")


func background_pressed():
	show_buttons_by_type("background")


func playercard_pressed():
	show_buttons_by_type("playercard")


func _on_texture_button_mouse_entered():
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color(1.0, 1.0, 1.0, 0.51)


func _on_texture_button_mouse_exited():
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color(1.0, 1.0, 1.0, 1.0)
