extends MarginContainer
class_name CharacterSelectInfoPanel

signal quick_match_queue(character)
signal ranked_match_queue(character)
signal clear_info()

var _character
var _player
var _portrait_toggled = false
var _skin_toggled = false

@export var action_container: HBoxContainer
@export var character_texture: TextureRect
@export var character_name: Label
@export var description_panel_container: MarginContainer
@export var sound: AudioStreamPlayer
@export var extra_button: PanelContainer
@export var emblem_container: HBoxContainer

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$HBoxContainer/PanelBackground/Sound.stop()
	$HBoxContainer/PanelBackground/Sound.stream = sounds[sound_name]
	$HBoxContainer/PanelBackground/Sound.play()

var description_panel

static func from_character(player, character, usable):
	var panel = load("res://ui/character_select_info_panel.tscn").instantiate()
	panel._player = player
	panel.apply_character_details(character)
	panel.describe_character(character)
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func extra_button_clicked():
	print("Extra button clicked!")
	var extra_interface = _character.get_custom_interface_panel()
	
	if _character.path_name == "toga":
		extra_interface.confirm_disguise.connect(toga_extra_confirmed)
	
	print("Adding extra interface panel!")
	$MenuAffixNode.add_child(extra_interface)

func toga_extra_confirmed(path_name):
	_player.equipped_disguise = path_name

func apply_character_details(character):
	_character = character
	if _character.extra_button_label != "":
		extra_button.visible = true
		extra_button.set_detail(_character.extra_button_label)
	populate_ability_list(_character)
	set_portrait_texture(_character)

func describe_ability(panel):
	if description_panel != null:
		description_panel_container.remove_child(description_panel)
		description_panel.queue_free()
	description_panel = panel
	description_panel_container.add_child(panel)

func describe_character(character):
	var panel = CharSelectCharacterDescription.from_character(character)
	var archetypes = Bounty.flat_bounty_categories(character.path_name)
	for archetype in archetypes:
		var rect = TextureRect.new()
		rect.texture = load("res://assets/bounty/" + archetype + ".png")
		rect.tooltip_text = archetype.capitalize()
		rect.custom_minimum_size = Vector2(23, 23)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem_container.add_child(rect)
	if description_panel != null:
		description_panel_container.remove_child(description_panel)
		description_panel.queue_free()
	description_panel = panel
	description_panel_container.add_child(panel)

func populate_ability_list(character):
	for ability in character.moveset.abilities:
		add_ability(ability)
	if character.path_name in _player.equipped_mastery_skins:
		toggle_skin_on()
	else:
		reset_skin()
	
func add_ability(ability):
	var button = ActionButton.from_action(ability)
	button.offer_panelless.connect(describe_ability)
	button.custom_minimum_size = Vector2(65, 65)
	action_container.add_child(button)

func set_portrait_texture(character):
	if character.path_name in _player.equipped_mastery_profiles:
		toggle_profile_on()
	else:
		reset_profile()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass




func close_button_clicked():
	play_sound("click")
	clear_info.emit()


func _on_texture_button_mouse_entered():
	play_sound("hover")
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)




func _on_texture_button_mouse_exited():
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color.WHITE


func alt_prof_pressed():
	
	reset_skin()
	if _portrait_toggled:
		reset_profile()
	else:
		toggle_profile_on()

func toggle_profile_on():
	_portrait_toggled = true
	var panel = $HBoxContainer/PanelBackground/Rows/UpperMargin/VBoxContainer/UpperRow/MainInfo/VBoxContainer/PanelContainer.get("theme_override_styles/panel")
	panel.bg_color = Color.DARK_GREEN
	if _character.mastery_portrait != null:
		print("Doing mastery portrait!")
		character_name.text = _character.mastery_name
		character_texture.texture = _character.mastery_portrait
		if MasteryConfig.can_equip_mastery_portrait(_player.get_mastery_score_from_character(_character)):
			_player.equip_mastery_profile(_character.path_name)

func reset_profile():
	_portrait_toggled = false
	var panel2 = $HBoxContainer/PanelBackground/Rows/UpperMargin/VBoxContainer/UpperRow/MainInfo/VBoxContainer/PanelContainer.get("theme_override_styles/panel")
	panel2.bg_color = Color.hex(0x181818ff)
	character_name.text = _character.character_name
	character_texture.texture = _character.portrait_texture
	_player.remove_mastery_profile(_character.path_name)

func toggle_skin_on():
	_skin_toggled = true
	var panel = $HBoxContainer/PanelBackground/Rows/UpperMargin/VBoxContainer/UpperRow/MainInfo/VBoxContainer/PanelContainer2.get("theme_override_styles/panel")
	panel.bg_color = Color.DARK_GREEN
	if _character.mastery_portrait != null:
		print("Doing mastery portrait!")
		character_name.text = _character.mastery_name
		character_texture.texture = _character.mastery_portrait
		var mastery_level = _player.get_mastery_score_from_character(_character)
		if MasteryConfig.can_equip_mastery_portrait(mastery_level):
			_player.equip_mastery_profile(_character.path_name)
		if MasteryConfig.can_equip_mastery_skin(mastery_level):
			_player.equip_mastery_skin(_character.path_name)
		for skill_button in action_container.get_children():
			if not skill_button.showing_mastery:
				skill_button.toggle_mastery()

func reset_skin():
	_skin_toggled = false
	var panel2 = $HBoxContainer/PanelBackground/Rows/UpperMargin/VBoxContainer/UpperRow/MainInfo/VBoxContainer/PanelContainer2.get("theme_override_styles/panel")
	panel2.bg_color = Color.hex(0x181818ff)
	for skill_button in action_container.get_children():
		if skill_button.showing_mastery:
			skill_button.toggle_mastery()
	character_name.text = _character.character_name
	character_texture.texture = _character.portrait_texture
	_player.remove_mastery_profile(_character.path_name)
	_player.remove_mastery_skin(_character.path_name)


func alt_skin_pressed():
	reset_profile()
	if _skin_toggled:
		reset_skin()
	else:
		toggle_skin_on()
