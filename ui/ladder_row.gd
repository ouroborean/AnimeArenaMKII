extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_details(username, rating, record, clan_name, rank):
	$HBoxContainer/RankLabel.text = str(rank)
	$HBoxContainer/NameLabel.text = username + "   (" + clan_name + ")"
	$HBoxContainer/StatLabel.text = str(str(int(rating)) + " (" + str(int(record[0])) + "W-" + str(int(record[1])) + "L)")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
