extends Control
class_name NexusUniverseCharacterPanel

var selected_bucket_display
var player

signal close_panel()
signal change_panel(panel)
signal contribute_amount(character_path_name, amount)
signal return_to_nexus()

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

var image_dict = {
	CharacterConcept.Universe.NARUTO: load("res://assets/ui/Anime_View/narutobackground.png"),
	CharacterConcept.Universe.BLEACH: load("res://assets/ui/Anime_View/bleachbackground.png"),
	CharacterConcept.Universe.ONE_PIECE: load("res://assets/ui/Anime_View/onepiecebackground.png"),
	CharacterConcept.Universe.MY_HERO_ACADEMIA: load("res://assets/ui/Anime_View/myherobackground.png"),
	CharacterConcept.Universe.BLACK_CLOVER: load("res://assets/ui/Anime_View/blackcloverbackground.png"),
	CharacterConcept.Universe.MADOKA_MAGICA: load("res://assets/ui/Anime_View/madokabackground.png"),
	CharacterConcept.Universe.FAIRY_TAIL: load("res://assets/ui/Anime_View/fairytailbackground.png"),
	CharacterConcept.Universe.SOUL_EATER: load("res://assets/ui/Anime_View/souleaterbackground.png"),
	CharacterConcept.Universe.AVATAR: load("res://assets/ui/Anime_View/avatarbackground.png"),
	CharacterConcept.Universe.AKAME_GA_KILL: load("res://assets/ui/Anime_View/akamebackground.png"),
	CharacterConcept.Universe.DEMON_SLAYER: load("res://assets/ui/Anime_View/demonslayerbackground.png"),
	CharacterConcept.Universe.SEVEN_DEADLY_SINS: load("res://assets/ui/Anime_View/seven_deadly_sins.png"),
	CharacterConcept.Universe.KATEKYO_HITMAN_REBORN: load("res://assets/ui/Anime_View/hitmanrebornbackground.png"),
	CharacterConcept.Universe.ATTACK_ON_TITAN: load("res://assets/ui/Anime_View/attackontitanbackground.png"),
	CharacterConcept.Universe.ONE_PUNCH_MAN: load("res://assets/ui/Anime_View/onepunchmanbackground.png"),
	CharacterConcept.Universe.FIRE_FORCE: load("res://assets/ui/Anime_View/fireforcebackground.png"),
	CharacterConcept.Universe.HUNTER_X_HUNTER: load("res://assets/ui/Anime_View/hunterxhunterbackground.png"),
	CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN: load("res://assets/ui/Anime_View/railgunbackground.png"),
	CharacterConcept.Universe.FATE: load("res://assets/ui/Anime_View/fatebackground.png"),
	CharacterConcept.Universe.KILL_LA_KILL: load("res://assets/ui/Anime_View/killalakillabackground.png"),
	CharacterConcept.Universe.DEADMAN_WONDERLAND: load("res://assets/ui/Anime_View/deadmanbackground.png"),
	CharacterConcept.Universe.TOKYO_GHOUL: load("res://assets/ui/Anime_View/tokyoghoulbackground.png"),
	CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME: load("res://assets/ui/Anime_View/slimebackground.png"),
	CharacterConcept.Universe.JUJUTSU_KAISEN: load("res://assets/ui/Anime_View/jjkbackground.png"),
	CharacterConcept.Universe.DIGIMON: load("res://assets/ui/Anime_View/digimonbackground.png"),
	CharacterConcept.Universe.SAILOR_MOON: load("res://assets/ui/Anime_View/sailor_moon.png"),
	CharacterConcept.Universe.INVINCIBLE: load("res://assets/ui/Anime_View/inviniciblebackground.png"),
	CharacterConcept.Universe.DRAGON_BALL: load("res://assets/ui/Anime_View/dragon_ball.png"),
	CharacterConcept.Universe.MASHLE: load("res://assets/ui/Anime_View/mashle.png"),
	CharacterConcept.Universe.SOLO_LEVELING: load("res://assets/ui/Anime_View/solo_leveling.png"),
	CharacterConcept.Universe.FRIEREN: load("res://assets/ui/Anime_View/frieren.png"),
	CharacterConcept.Universe.EMINENCE_IN_SHADOW: load("res://assets/ui/Anime_View/eminence.png"),
	CharacterConcept.Universe.CHAINSAW_MAN: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.AO_NO_EXORCIST: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.YUGIOH: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.INUYASHA: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.ASSASSINATION_CLASSROOM: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.KONOSUBA: load("res://assets/ui/Anime_View/placeholderbackground.png"),
	CharacterConcept.Universe.SERAPH_OF_THE_END: load("res://assets/ui/Anime_View/placeholderbackground.png")
}

static func new_universe_character_panel(p_player, universe):
	var panel = load("res://ui/nexus_universe_character_panel.tscn").instantiate()
	panel.add_player_details(p_player)
	panel.add_details_from_universe(universe)
	return panel

func accept_buckets(buckets):
	print("Setting buckets for Universe Panel!")
	for bucket in buckets:
		var bucket_display = CharacterBucketDisplay.from_character_bucket(bucket)
		bucket_display.bucket_clicked.connect(display_contribution_button)
		$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer2/ScrollContainer/MarginContainer/GridContainer.add_child(bucket_display)

func update_all_bucket_displays():
	print("Updating bucket displays in Universe Character Panel!")
	for bucket_display in $NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer2/ScrollContainer/MarginContainer/GridContainer.get_children():
		bucket_display.get_details_from_bucket(bucket_display._bucket)
		
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func add_details_from_universe(universe):
	$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Label.text = CharacterConcept.Universe.keys()[universe].capitalize() + " Characters"
	var new_texture = StyleBoxTexture.new()
	new_texture.texture = image_dict[universe]
	$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer.add_theme_stylebox_override("panel", new_texture)

func add_player_details(p_player):
	player = p_player
	$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Label2.text = "AP: " + str(int(player.ap))

func display_contribution_button(bucket_display):
	play_sound("click")
	print("Clicked on a character bucket for character " + str(bucket_display._bucket.character_concept.character_name))
	selected_bucket_display = bucket_display
	$HBoxContainer.assign_character(bucket_display._bucket.character_concept.character_name, bucket_display._bucket.ap)
	$HBoxContainer.visible = true
	
func receive_contribution(amount):
	print("Received contribution attempt of " + str(amount))
	if amount < 0:
		return
	if player.ap >= amount:
		contribute_amount.emit(selected_bucket_display._bucket.character_concept.path_name, amount)
		add_player_details(player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func close_contribution_panel():
	play_sound("click")
	selected_bucket_display = null
	$HBoxContainer.visible = false

func close_clicked():
	play_sound("click")
	close_panel.emit()

func back_button_pressed():
	play_sound("click")
	return_to_nexus.emit()
	close_panel.emit()

func _on_back_button_mouse_entered():
	$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_back_button_mouse_exited():
	$NexusUniverseCharacterPanel/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/TextureButton.modulate = Color.WHITE
	
func _on_close_button_mouse_entered():
	$NexusUniverseCharacterPanel/MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_close_button_mouse_exited():
	$NexusUniverseCharacterPanel/MarginContainer/TextureButton.modulate = Color.WHITE
