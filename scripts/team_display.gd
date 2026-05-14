extends Control
class_name TeamDisplay

@export var rows: VBoxContainer
@export var wtf: int


static func from_team(team, enemy=false):
	var team_display = load("res://components/team_display.tscn").instantiate()
	
	for character in team:
		var char_panel = CharacterPanel.from_character(character, enemy)
		team_display.rows.add_child(char_panel)
	if enemy:
		team_display.size_flags_horizontal = SIZE_SHRINK_END
		team_display.set("theme_override_constants/margin_top", -5)
		team_display.rows.set("theme_override_constants/separation", 27)
	return team_display

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
