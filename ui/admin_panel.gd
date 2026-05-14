extends PanelContainer
class_name AdminPanel

enum Action {
	PlayerLookup,
	PlayerModify,
	CloseNexus
}


signal send_admin_action_request(action_type, args)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func receive_player_lookup(data):
	var wins = data['wins']
	var losses = data['losses']
	var rp = data['rp']
	var rank = data['rank']
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
