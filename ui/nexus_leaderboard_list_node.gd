extends HBoxContainer
class_name NexusLeaderboardListNode

var character_name

static func from_character_and_ap(character, ap):
	var node = load("res://ui/nexus_leaderboard_list_node.tscn").instantiate()
	node.ingest_character(character)
	node.ingest_ap(ap)
	return node


func ingest_character(character):
	$Portrait.texture = character.portrait_texture
	character_name = character.character_name
	$EntryPanel/EntryRow/NameLabel.text = character.character_name


func ingest_ap(ap):
	$EntryPanel/EntryRow/APPanel/APLabel.text = str(int(ap)) + " AP"
