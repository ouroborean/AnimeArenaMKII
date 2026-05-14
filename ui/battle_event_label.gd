extends Label
class_name BattleEventLabel

static func from_message(msg):
	var label = load("res://ui/battle_event_label.tscn").instantiate()
	
	label.text = msg
	
	return label

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
