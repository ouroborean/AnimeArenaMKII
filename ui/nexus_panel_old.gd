extends Control


var _player
var requested_universe

static func new_nexus_panel(player):
	var panel = load("res://ui/nexus_panel.tscn").instantiate()
	panel.assign_player(player)
	panel.startup()
	
	return panel

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

signal request_universe_buckets(panel, universe)
signal close_panel()
signal change_panel(panel)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func startup():
	for i in range(len(CharacterConcept.Universe.keys())):
		var universe = CharacterConcept.Universe[CharacterConcept.Universe.keys()[i]]
		var node = NexusUniverseNode.from_universe(universe)
		node.requested_universe.connect(universe_node_clicked)
		$HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer/ScrollContainer/VBoxContainer.add_child(node)

func assign_player(player):
	_player = player
	$HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/Label2.text = str(int(_player.ap))
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func accept_buckets(buckets):
	print("Nexus panel got buckets back from bucket handler!")
	var new_panel = NexusUniverseCharacterPanel.new_universe_character_panel(_player, requested_universe)
	new_panel.accept_buckets(buckets)
	change_panel.emit(new_panel)

func assign_leaderboard(leading_character_sets):
	
	for child in $HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer.get_children():
		child.queue_free()
	
	for character_set in leading_character_sets:
		var character = character_set[0]
		var ap = character_set[1]
		var node = NexusLeaderboardListNode.from_character_and_ap(character, ap)
		$HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer.add_child(node)

func universe_node_clicked(universe):
	print("Requested character concepts from " + CharacterConcept.Universe.keys()[universe].capitalize())
	requested_universe = universe
	request_universe_buckets.emit(self, universe)

func close_clicked():
	play_sound("click")
	close_panel.emit()


func _on_cancel_button_mouse_entered():
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_cancel_button_mouse_exited():
	$HBoxContainer/MarginContainer/TextureButton.modulate = Color.WHITE
