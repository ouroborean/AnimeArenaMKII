extends PanelContainer
class_name CharacterDescriptionPanel

static func from_character(character):
	var panel = load("res://ui/character_description_panel.tscn").instantiate()
	panel.add_name(character.character_name)
	panel.add_desc(character.description)
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func add_name(_name):
	$MarginContainer/HBoxContainer/Rows/HeaderRow/AbilityNameLabel.text = _name

func add_desc(_desc):
	$MarginContainer/HBoxContainer/Rows/AbilityDescLabel.text = _desc

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
