extends HBoxContainer
class_name TitleSelectMenu

var _player
var current_title = ""
var running_title_count = 0
signal close_panel()


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

var lesser_titles = {
	"naruto": ["Outcast", "Orange"],
	"sasuke": ["Uchiha", "Avenger"],
	"sakura": ["Blossom", "Medical"],
	"hinata": ["Admiring", "Heiress"],
	"luffy": ["Rubber", "Stretching"],
	"zoro": ["Sword", "Slash"],
	"usopp": ["Liar", "Smoke"],
	"ace": ["Brother", "Blaze"],
	"midoriya": ["Green", "Smash"],
	"uraraka": ["Float", "Gravity"],
	"bakugo": ["Explosion", "Ambitious"],
	"yuji": ["Finger", "Black"],
	"nobara": ["Hammer", "Needle"],
	"sukuna": ["Cleave", "Malevolent"],
	"natsu": ["Fire", "Flames"],
	"lucy": ["Celestial", "Keys"],
	"gray": ["Ice", "Topless"],
	"madoka": ["Wish", "Eternal"],
	"sayaka": ["Courage", "Blue"],
	"mami": ["Mentor", "Yellow"],
	"asta": ["Bull", "United"],
	"yuno": ["Dawn", "Sylph"],
	"noelle": ["Valkyrie", "Flowing"],
	"maka": ["Meister", "Chop"],
	"soul": ["Scythe", "Hungry"],
	"aang": ["Avatar", "Last"],
	"korra": ["Elements", "Next"],
	"tatsumi": ["Invisible", "Ruthless"],
	"akame": ["Assassin", "Red"],
	"sheele": ["Scissors", "Blinding"],
	"tanjiro": ["Water", "Scent"],
	"nezuko": ["Sister", "Sealed"],
	"zenitsu": ["Thunder", "Flash"],
	"meliodas": ["Wrath", "Counter"],
	"diane": ["Envy", "Giant"],
	"king": ["Sloth", "Fairy"],
	"tsunayoshi": ["Tenth", "Sky"],
	"yamamoto": ["Rain", "Swinging"],
	"ryohei": ["Sun", "Fist"],
	"eren": ["Titan", "Soldier"],
	"mikasa": ["Descendant", "Guardian"],
	"saitama": ["Caped", "Bald"],
	"genos": ["Cyborg", "Disciple"],
	"tatsumaki": ["Tornado", "Psychic"],
	"shinra": ["Hysterical", "Burning"],
	"tamaki": ["Ignition", "Cat-Eared"],
	"gon": ["Janken", "Fishing"],
	"killua": ["Clawed", "Bleeding"],
	"kurapika": ["Chain", "Scarlet"],
	"misaka": ["Railgun", "Electro"],
	"kuroko": ["Judgment", "Teleporting"],
	"saber": ["Knight"],
	"gilgamesh": ["Archer", "Golden"],
	"jack": ["Fog", "Ripper"],
	"ryuko": ["Ashamed", "Rebel"],
	"satsuki": ["President", "Aloof"],
	"nonon": ["Marching", "Music"],
	"ichigo": ["Strawberry", "Fang"],
	"uryuu": ["Quincy", "Kojaku"],
	"ganta": ["Blood", "Woodpecker"],
	"shiro": ["Wretched", "White"],
	"ken": ["Ghoul", "Broken"],
	"touka": ["Kind", "Raging"],
	"rimuru": ["Slime", "Demon"],
	"goku": ["Kame", "Pure-hearted"],
	"vegeta": ["Saiyan", "Prince"],
	"edward": ["Short", "Alchemy"],
	"alphonse": ["Armor"],
	"invincible": ["Superhero"],
	"atomeve": ["Molecular"],
	"omniman": ["Merciless"],
	"semiramis": ["Wise", "Queen"],
	"rengoku": ["Flame-Breathing"],
	"machinedramon": ["Amalgam"],
	"blackstar": ["Ostentatious", "Loud"],
	"xanxus": ["Angry", "Scarred"],
	"squalo": ["Emperor"],
	"gatomon": ["Cat", "Neko"],
	"gallantmon": ["Chivalrous", "Shield"],
	"byakuya": ["6th", "Thousand"],
	"nimaiya": ["Forge", "Zanpakutou"],
	"mash": ["Round", "Table"],
	"nagisa": ["Student", "Classroom"],
	"omnimon": ["Digital", "Transcendent"],
	"koro": ["Teacher", "Tentacles"],
	"hashirama": ["Wood-Style", "First"],
	"toga": ["Loving", "Yandere"],
	"frankenstein": ["Bride", "Monster"],
	"mars": ["Ruby", "War"],
	"myotismon": ["Vampire", "Bat"],
	"gogeta": ["Fused"],
	"rob": ["CP9"],
	"emiya": ["Unlimited"],
	"hawkmon": ["Feather"],
	"gunha": ["Court", "Supremacy"],
	"renamon": ["Cool", "Speed"],
	"jupiter": ["Emerald", "Thunder"],
	"erza": ["S-Rank", "Queen"],
	"tsubaki": ["Shadow", "Weapon"],
	"toph": ["Blind", "Earth"],
	"inosuke": ["Boar", "Belligerent"],
	"muichiro": ["Indifferent", "Mist"],
	"frieren": ["Mage", "Hero", "Mana"],
	"megumin": ["Explosion"],
	"emiyaarcher": ["Archer", "Bone"],
	"megumi": ["Summoner", "Serpent"],
	"shokuho": ["Mental", "Clique"],
	"hisoka": ["Clown"],
	"neferpitou": ["Firstborn"],
	"ban": ["Greed"],
	"saturn": ["Silence"],
	"boruto": ["Rasengan", "Son"],
	"crona": ["Tortured"],
	"inuyasha": ["Half", "Yokai"],
	"marco": ["Resurrection"],
	"gohan": ["Potential"],
	"yugi": ["Pharaoh"],
	"tokoyami": ["Bird", "Shadow"],
	"kid": ["Symmetry"],
	"orihime": ["Flowers"],
	"gojo": ["Infinity"],
	"uzui": ["Score"],
	"tsuyu": ["Frog"],
	"esdeath": ["Sadistic"],
	"mercury": ["Aqua"],
	"jaden": ["Elemental"],
	"jesse": ["Rainbow"],
	"venus": ["Chain"],
	"toudou": ["President"],
	"mine": ["Pinch", "Genius"],
	"lizandpatty": ["Pistols", "Brooklyn"]
}

var greater_titles = {
	"naruto": ["Kyuubi"],
	"sasuke": ["Uchiha"],
	"sakura": ["Kunoichi"],
	"hinata": ["Hyuuga"],
	"luffy": ["Straw-Hat"],
	"zoro": ["Three-Sword"],
	"usopp": ["Sniper"],
	"ace": ["Ace"],
	"midoriya": ["Number 1"],
	"uraraka": ["Meteor"],
	"bakugo": ["Rival"],
	"yuji": ["Vessel"],
	"nobara": ["Resonance"],
	"sukuna": ["Strongest"],
	"natsu": ["Dragonslayer"],
	"lucy": ["Spirit"],
	"gray": ["Frozen"],
	"madoka": ["Destiny"],
	"sayaka": ["Despair"],
	"mami": ["Rifle"],
	"asta": ["Clover"],
	"yuno": ["Zephyr"],
	"noelle": ["Saint"],
	"maka": ["Courage"],
	"soul": ["Death"],
	"aang": ["Elemental"],
	"korra": ["Energy"],
	"tatsumi": ["Incursio"],
	"akame": ["Killer"],
	"sheele": ["Severed"],
	"tanjiro": ["Torrential"],
	"nezuko": ["Rampaging"],
	"zenitsu": ["Speed"],
	"meliodas": ["Sin"],
	"diane": ["Dancing"],
	"king": ["King"],
	"tsunayoshi": ["Boss"],
	"yamamoto": ["Soothing"],
	"ryohei": ["Extreme"],
	"squalo": ["Shark"],
	"eren": ["Tearing"],
	"mikasa": ["Scion"],
	"saitama": ["One"],
	"genos": ["Incineration"],
	"tatsumaki": ["Terror"],
	"shinra": ["Spinning"],
	"tamaki": ["Unlucky"],
	"gon": ["Potential"],
	"killua": ["Deadly"],
	"kurapika": ["Vengeance"],
	"misaka": ["Lightning"],
	"kuroko": ["Partner"],
	"saber": ["Excalibur"],
	"gilgamesh": ["Treasures"],
	"jack": ["Orphan"],
	"ryuko": ["Exposed"],
	"satsuki": ["Council"],
	"nonon": ["Conductor"],
	"ichigo": ["Hollow"],
	"uryuu": ["Final"],
	"ganta": ["Gun"],
	"shiro": ["Lullaby"],
	"ken": ["Unravelling"],
	"touka": ["Crystal"],
	"rimuru": ["Tempest"],
	"goku": ["Earth"],
	"vegeta": ["Proud"],
	"edward": ["Fullmetal"],
	"alphonse": ["Armored"],
	"invincible": ["Invincible"],
	"atomeve": ["Atomic"],
	"omniman": ["Viltrumite"],
	"semiramis": ["Poison"],
	"rengoku": ["Hashira"],
	"machinedramon": ["Machines"],
	"blackstar": ["Star"],
	"xanxus": ["Wrath"],
	"gatomon": ["Ophanim"],
	"gallantmon": ["Gallant"],
	"byakuya": ["Scatter"],
	"nimaiya": ["#1"],
	"mash": ["Protector"],
	"nagisa": ["Teacher"],
	"omnimon": ["Destiny"],
	"koro": ["Sensei"],
	"hashirama": ["God"],
	"toga": ["Wife"],
	"frankenstein": ["Galvanic"],
	"mars": ["Mars"],
	"myotismon": ["Venom"],
	"gogeta": ["SS4"],
	"rob": ["Leopard"],
	"emiya": ["Blade", "Works"],
	"hawkmon": ["Aquiline"],
	"gunha": ["Guts", "Gem"],
	"renamon": ["Diamond"],
	"jupiter": ["Jupiter"],
	"erza": ["Titania", "Queen"],
	"tsubaki": ["Uncanny"],
	"toph": ["Metal", "-bending"],
	"inosuke": ["Serrated", "Fanged"],
	"muichiro": ["Hashira"],
	"frieren": ["Unaware", "Flower"],
	"megumin": ["Crimson", "Demon"],
	"emiyaarcher": ["My", "Sword"],
	"megumi": ["Ten", "Shadows"],
	"shokuhou": ["Queen", "Tokiwadai"],
	"hisoka": ["Bungee", "Gum"],
	"neferpitou": ["Puppeteer", "Strings"],
	"ban": ["Undead"],
	"saturn": ["Death", "Rebirth"],
	"boruto": ["Karma"],
	"crona": ["Ragnarok"],
	"inuyasha": ["Fang"],
	"marco": ["Phoenix"],
	"gohan": ["Son", "Surpass"],
	"yugi": ["King", "Games"],
	"tokoyami": ["Yami", "Revelry"],
	"kid": ["Death"],
	"orihime": ["Shield", "Heavenly"],
	"gojo" : ["Red", "Blue", "Purple"],
	"uzui": ["Sound"],
	"tsuyu": ["Tongue"],
	"esdeath": ["Mahapadma"],
	"mercury": ["Mirage"],
	"jaden": ["Hero"],
	"jesse": ["Crystal"],
	"venus": ["Love"],
	"toudou": ["Raikiri"],
	"mine": ["Sniper"],
	"lizandpatty": ["Twin"]
}

static func from_player(player, char_list):
	var menu = load("res://ui/title_select_menu.tscn").instantiate()
	menu.ingest_player(player, char_list)
	
	return menu

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func accept_new_title_component(title):
	if running_title_count >= 5:
		return_title(title)
		return
	running_title_count += 1
	title.deploy_clicked.connect(return_title)
	title.deployed = true
	if current_title != "":
		current_title += " " + title._title
	else:
		current_title = title._title
	_player.title = current_title
	update_title_label()

func update_title_label():
	$Control/FullMargin/VBoxContainer/HeaderMargin/VBoxContainer/HeaderRow/HBoxContainer/TitleDisplayLabel.text = current_title.lstrip(" ")

func ingest_player(player, char_list):
	_player = player
	current_title = _player.title
	update_title_label()
	for title in _player.title_data + get_unlocked_titles(char_list):
		var title_button = TitleBuilderComponent.from_title(title)
		$Control/FullMargin/VBoxContainer/TitleStorageMargin/TileStoragePanel/ScrollContainer/TileStorageInnerMargin/GridContainer.add_child(title_button)
	reserve_used_titles()

func get_unlocked_titles(char_list):
	var unlocked_titles = []
	for character in char_list:
		var level = _player.get_mastery_score_from_character(character)
		if level >= MasteryConfig.UNLOCK_THRESHOLDS["lesser_title"] and character.path_name in lesser_titles:
			unlocked_titles += lesser_titles[character.path_name]
		if level >= MasteryConfig.UNLOCK_THRESHOLDS["greater_title"] and character.path_name in greater_titles:
			unlocked_titles += greater_titles[character.path_name]
	return unlocked_titles

func reserve_used_titles():
	var titles = current_title.split(" ")
	var ordered_titles = [null, null, null, null, null]
	for child in $Control/FullMargin/VBoxContainer/TitleStorageMargin/TileStoragePanel/ScrollContainer/TileStorageInnerMargin/GridContainer.get_children():
		if child._title in titles:
			ordered_titles[titles.find(child._title)] = child
			child.deploy_clicked.connect(return_title)
			child.deployed = true
			$Control/FullMargin/VBoxContainer/TitleStorageMargin/TileStoragePanel/ScrollContainer/TileStorageInnerMargin/GridContainer.remove_child(child)
	for child in ordered_titles:
		if not child == null:
			running_title_count += 1
			$Control/FullMargin/VBoxContainer/TitleBuilderMargin/PanelContainer/PanelInnerMargin/BuilderHBox.add_child(child)

func return_title(title_component):
	running_title_count -= 1
	if current_title.contains(" " + title_component._title):
		current_title = current_title.replace(" " + title_component._title, "")
	elif current_title.contains(title_component._title + " "):
		current_title = current_title.replace(title_component._title + " ", "")
	else:
		current_title = current_title.replace(title_component._title, "")
	_player.title = current_title
	title_component.deploy_clicked.disconnect(return_title)
	title_component.modulate = Color.WHITE
	title_component.get_parent().remove_child(title_component)
	$Control/FullMargin/VBoxContainer/TitleStorageMargin/TileStoragePanel/ScrollContainer/TileStorageInnerMargin/GridContainer.add_child(title_component)
	update_title_label()

func add_title():
	var slot = load("res://ui/title_builder_slot.tscn").instantiate()
	$Control/FullMargin/VBoxContainer/TitleBuilderMargin/PanelContainer/PanelInnerMargin/BuilderHBox.add_child(slot)
	$Control/FullMargin/VBoxContainer/TitleBuilderMargin/PanelContainer/PanelInnerMargin/BuilderHBox.move_child(slot, 0)


func close_button_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		close_panel.emit()


func close_button_pressed():
	close_panel.emit()
	play_sound("click")


func _on_texture_button_mouse_entered():
	$MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")


func _on_texture_button_mouse_exited():
	$MarginContainer/TextureButton.modulate = Color.WHITE
	
