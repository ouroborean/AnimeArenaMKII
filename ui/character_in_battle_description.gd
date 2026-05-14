extends PanelContainer
class_name CharacterInBattleDescription

signal request_panel(user, action)

var _character

static func from_character(char):
	var desc = load("res://ui/character_in_battle_description.tscn").instantiate()
	desc.ingest_character(char)
	
	return desc

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_character(char):
	_character = char
	if char.enemy:
		for disguise in char.effects.get_effects_by_type(EffectType.Type.DISGUISE):
			var disguise_char = Character.from_character_name(disguise.mag)
			disguise_char.initialize(true)
			_character = disguise_char
	
	$VBoxContainer/MarginContainer2/Label.text = _character.character_name
	var profile_button = CharacterButton.from_character(_character)
	$VBoxContainer/MarginContainer/ScrollContainer/MarginContainer/HBoxContainer.add_child(profile_button)
	var ability_buttons = []
	for ability in _character.moveset.abilities:
		var ability_button = ActionButton.from_action(ability, true)
		ability_button.ability_clicked.connect(make_panel_request)
		$VBoxContainer/MarginContainer/ScrollContainer/MarginContainer/HBoxContainer.add_child(ability_button)
	var archetypes = Bounty.flat_bounty_categories(_character.path_name)
	for archetype in archetypes:
		var rect = TextureRect.new()
		rect.texture = load("res://assets/bounty/" + archetype + ".png")
		rect.tooltip_text = archetype.capitalize()
		rect.custom_minimum_size = Vector2(23, 23)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		$MarginContainer/HBoxContainer.add_child(rect)

func make_panel_request(ability):
	request_panel.emit(_character, ability)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
