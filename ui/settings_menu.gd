extends HBoxContainer
class_name SettingsMenu

signal close_panel()

var _player

static func from_player(player):
	var panel = load("res://ui/settings_menu.tscn").instantiate()
	panel.ingest_player(player)
	
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_player(player):
	_player = player
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/QueueDelaySlider.value = _player.bot_queue_delay
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/QueueDelayLabel.text = str(_player.bot_queue_delay) + " seconds"
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/TurnDelaySlider.value = _player.bot_turn_delay
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/TurnDelayLabel.text = str(_player.bot_turn_delay) + " seconds"
	$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/EnemyCosmeticsButton.button_pressed = _player.cosmetics_on
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer3/EnemyCosmeticsButton.button_pressed = _player.muted

func close_button_clicked():
	_player.bot_queue_delay = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/QueueDelaySlider.value
	_player.bot_turn_delay = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/TurnDelaySlider.value
	_player.cosmetics_on = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/EnemyCosmeticsButton.button_pressed
	close_panel.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_queue_delay_slider_value_changed(value):
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/QueueDelayLabel.text = str(value) + " seconds"
	_player.bot_queue_delay = value


func _on_turn_delay_slider_value_changed(value):
	$PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/TurnDelayLabel.text = str(value) + " seconds"
	_player.bot_turn_delay = value

func _on_enemy_cosmetics_button_toggled(button_pressed):
	_player.cosmetics_on = button_pressed


func on_mute_toggled(button_pressed):
	if button_pressed:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -100)
		_player.muted = true
	else:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -20)
		_player.muted = false


func on_mark_toggled(toggled_on):
	if toggled_on:
		_player.mark_significant = true
		GlobalPlayerSettings.threat_assist = true
	else:
		_player.mark_significant = false
		GlobalPlayerSettings.threat_assist = false
