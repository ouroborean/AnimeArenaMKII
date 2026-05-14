extends HBoxContainer
class_name MasteryInfoMenu

var _player
var _initial
var _char_list

signal close_panel()


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

static func from_player_and_list(player, char_list):
	var menu = load("res://ui/mastery_info_menu.tscn").instantiate()
	menu.assign_player(player)
	menu._char_list = char_list
	menu.initialize_character_list()
	menu.change_character_display(menu._initial, false)
	return menu

func _ready():
	pass


func ingest_info(character):
	for child in $MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/MarginContainer.get_children():
		$MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/MarginContainer.remove_child(child)
	var character_button = CharacterButton.from_character(character)
	character_button.custom_minimum_size = Vector2(75, 75)

	$MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/MarginContainer.add_child(character_button)
	$MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/VBoxContainer/Label.text = character.character_name

func initialize_character_list():
	for character in _char_list:
		if _initial == null:
			_initial = character
		var button = CharacterButton.from_character(character, false)
		button.button_clicked.connect(change_character_display)
		$MasteryInfoMenu/VBoxContainer/CharacterSliderRow/ScrollContainer/MarginContainer/HBoxContainer.add_child(button)

func assign_player(player):
	_player = player


func change_character_display(character, _locked):
	ingest_info(character)
	var level = _player.character_progress.get_level(character.path_name)
	var xp = _player.character_progress.get_xp(character.path_name)
	var fraction = _player.character_progress.get_progress_fraction(character.path_name)
	var next_level_xp = MasteryConfig.xp_at_next_level(xp)
	replace_progress(fraction, xp, next_level_xp, level)
	update_level_label(level, xp)
	update_unlock_list(character.path_name, level, character.portrait_texture)

func replace_progress(fraction: float, current_xp: int, next_level_xp: int, level: int):
	var bar_container = $MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/VBoxContainer/MarginContainer
	for child in bar_container.get_children():
		bar_container.remove_child(child)
	var bar = MasteryProgressBar.from_character_progress(fraction, current_xp, next_level_xp, level)
	bar_container.add_child(bar)

func update_level_label(level: int, xp: int):
	var label = $MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/HBoxContainer/VBoxContainer/Label2
	if level >= MasteryConfig.MAX_LEVEL:
		label.text = " Level " + str(level) + " (MAX) — " + str(xp) + " XP total"
	else:
		label.text = " Level " + str(level) + " — " + str(xp) + " XP total"

func update_unlock_list(character_path: String, current_level: int, portrait: Texture2D = null):
	var list_container = $MasteryInfoMenu/VBoxContainer/BodyRow/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
	for child in list_container.get_children():
		list_container.remove_child(child)
	# Add section heading
	var heading = Label.new()
	heading.text = ""
	var heading_settings = LabelSettings.new()
	heading_settings.font_size = 14
	heading_settings.font_color = Color(0.7, 0.7, 0.7)
	heading.label_settings = heading_settings
	list_container.add_child(heading)
	for unlock_type in MasteryConfig.UNLOCK_THRESHOLDS:
		var required = MasteryConfig.UNLOCK_THRESHOLDS[unlock_type]
		var row = MasteryListRow.from_unlock(unlock_type, required, current_level, character_path, portrait)
		list_container.add_child(row)


func _process(delta):
	pass


func close_button_clicked():
	close_panel.emit()


func _on_texture_button_mouse_entered():
	$MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")


func _on_texture_button_mouse_exited():
	$MarginContainer/TextureButton.modulate = Color.WHITE
