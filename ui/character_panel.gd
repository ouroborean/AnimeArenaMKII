extends VBoxContainer
class_name CharacterPanel

var _character: Character
var _enemy


@export var target_container: MarginContainer
static func from_character(character, enemy=false):
	var char_panel = load("res://ui/character_panel.tscn").instantiate()
	char_panel.set_character(character, enemy)
	return char_panel



func set_character(character, enemy):
	_character = character
	_enemy = enemy
	_character.update.connect(update)
	change_frame(_character.action_frame)
	$HBoxContainer/VBoxContainer2/CharacterNameButton.set_character_name(character)
	$HBoxContainer/VBoxContainer2/HPBarComponent.get_values_from_character(character)
	$HBoxContainer/VBoxContainer2/HPBarComponent.link_portrait($HBoxContainer/VBoxContainer2/CharacterNameButton)
	$HBoxContainer/VBoxContainer/MarginContainer/EffectTooltipDisplay.sync_effects(character)
	$HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/MainActionContainer.get_main_actions_from_character(character)
	$HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/ActedStateButton.set_character_link(character)
	if enemy:
		size_flags_horizontal = Control.SIZE_SHRINK_END
		$HBoxContainer/VBoxContainer/PanelContainer.visible = false
		$HBoxContainer/VBoxContainer2/CharacterNameButton.enemy = true
		$HBoxContainer/VBoxContainer2/CharacterNameButton/PanelContainer/MarginContainer/TextureButton.flip_h = true
		var container = $HBoxContainer/VBoxContainer2
		$HBoxContainer.remove_child(container)
		$HBoxContainer.add_child(container)
	

func update():
	print("Updating " + _character.path_name + " through character panel")
	$HBoxContainer/VBoxContainer2/HPBarComponent.update()
	if _character.banished:
		$HBoxContainer/VBoxContainer2/HPBarComponent.modulate = Color.DARK_SLATE_GRAY
	else:
		$HBoxContainer/VBoxContainer2/HPBarComponent.modulate = Color.WHITE
	$HBoxContainer/VBoxContainer2/CharacterNameButton.update(_character)
	$HBoxContainer/VBoxContainer/MarginContainer/EffectTooltipDisplay.update()
	if not _enemy:
		$HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/MainActionContainer.update(_character)
		$HBoxContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/ActedStateButton.update(_character)

func change_frame(frame_name):
	var panel = $HBoxContainer/VBoxContainer/PanelContainer.get("theme_override_styles/panel/texture")
	panel.texture = load("res://assets/cosmetics/game_panels/" + frame_name + ".png")



# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
