extends Control
class_name MatchFoundPanel
signal draft_start()

static func from_players(player, enemy):
	var panel = load("res://ui/match_found_panel.tscn").instantiate()
	panel.assign_player(player)
	panel.assign_enemy(enemy)
	
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	$Timer.start()

func assign_player(player):
	$MarginContainer/HBoxContainer/PlayerTeamColumn/PlayerNameLabel.text = player._name.show()
	$MarginContainer/HBoxContainer/PlayerTeamColumn.add_child(PlayerPanel.from_player(player))
	$MarginContainer/HBoxContainer/PlayerTeamColumn.add_child(CharacterButton.from_character(player.team.characters[0]))

func assign_enemy(enemy):
	$MarginContainer/HBoxContainer/EnemyTeamColumn/EnemyNameLabel.text = enemy._name.show()
	$MarginContainer/HBoxContainer/EnemyTeamColumn.add_child(PlayerPanel.from_player(enemy))
	$MarginContainer/HBoxContainer/EnemyTeamColumn.add_child(CharacterButton.from_character(enemy.team.characters[0], true))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$MarginContainer/HBoxContainer/CentralInfoColumn/ProgressBar.value = $Timer.time_left




func _on_timer_timeout():
	draft_start.emit()
	queue_free()
