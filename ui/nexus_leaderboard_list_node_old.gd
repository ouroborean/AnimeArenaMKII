extends HBoxContainer


static func from_character_and_ap(character, ap):
	var node = load("res://ui/nexus_leaderboard_list_node.tscn").instantiate()
	
	node.ingest_character(character)
	node.ingest_ap(ap)
	
	return node

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_character(character):
	$TextureRect.texture = character.portrait_texture
	$PanelContainer/HBoxContainer/MarginContainer/Label.text = character.character_name

func ingest_ap(ap):
	$PanelContainer/HBoxContainer/PanelContainer/MarginContainer/Label.text = str(int(ap)) + " AP"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
