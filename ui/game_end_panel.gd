extends PanelContainer
class_name GameEndPanel

@export var ending_label: Label
@export var experience_label: Label

signal return_to_char_select()
signal match_stats()
signal save_replay()

var win_panel_offsets = {
	"left": 150.0,
	"right": 0.0,
	"top": 73.0,
	"bottom": 43.0
}

var loss_panel_offsets = {
	"left": 170.0,
	"right": 0.0,
	"top": 43.0,
	"bottom": 16.0
}

var base_victory_amount = 350


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


static func from_end_state(battle, won, player, xp_change = 1):
	var panel = load("res://ui/game_end_panel.tscn").instantiate()
	panel.ingest_end_state(battle, won, player, xp_change)
	return panel

func ingest_end_state(battle, won, player, xp_change):
	var ap_gain = base_victory_amount
	var streak_multiplier = 25
	var streak_max = 8
	if battle.match_type == BattleScene.Match.BOT:
		$MarginContainer/VBoxContainer/MarginContainer/HBoxContainer3/Label.text = "Match Type: Quick"
	else:
		$MarginContainer/VBoxContainer/MarginContainer/HBoxContainer3/Label.text = "Match Type: " + BattleScene.Match.keys()[battle.match_type].capitalize()
	$MarginContainer/VBoxContainer/MarginContainer2/VBoxContainer/TextureRect.texture = Rank.rank_emblem(player.rank.rank)
	$MarginContainer/VBoxContainer/MarginContainer2/VBoxContainer/MarginContainer/Label.text = player.rank.to_str()
	
	var player_streak = player.rank.streak
	if player_streak > streak_max:
		player_streak = streak_max
	
	if battle.match_type == BattleScene.Match.PRIVATE:
		ap_gain = 0
		streak_multiplier = 0
	elif battle.match_type == BattleScene.Match.QUICK or battle.match_type == BattleScene.Match.BOT:
		ap_gain -= 100
		streak_multiplier = 40
	elif battle.match_type == BattleScene.Match.RANKED:
		player_streak = player.rank._ranked_streak
		streak_multiplier = 60
		if player_streak > streak_max:
			player_streak = streak_max
	
	if player_streak < 0:
		player_streak = 0
	ap_gain += streak_multiplier * player_streak
	if won:
		set_win_ui()
		var label_string = "You won!"
		player.gain_ap(ap_gain)
		$MarginContainer/VBoxContainer/HBoxContainer2/MarginContainer2/HBoxContainer2/Label2.text = "You've gained " + str(ap_gain) + " AP"
			
		ending_label.text = label_string
	else:
		ap_gain -= 150
		streak_multiplier = 0
		if ap_gain < 0:
			ap_gain = 0
		set_lose_ui()
		player.gain_ap(ap_gain)
		var label_string = "You lost..."
		$MarginContainer/VBoxContainer/HBoxContainer2/MarginContainer2/HBoxContainer2/Label2.text = "You've gained " + str(ap_gain) + " AP"
		
		ending_label.text = label_string
	battle.save_player()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_win_ui():
	var panel = get("theme_override_styles/panel/texture")
	panel.texture = load("res://assets/ui/win_screen/win label.png")
	panel.expand_margin_left = win_panel_offsets["left"]
	panel.expand_margin_right = win_panel_offsets["right"]
	panel.expand_margin_top = win_panel_offsets["top"]
	panel.expand_margin_bottom = win_panel_offsets["bottom"]
	
func set_lose_ui():
	var panel = get("theme_override_styles/panel/texture")
	panel.texture = load("res://assets/ui/win_screen/loss_screen_panel.png")
	panel.expand_margin_left = loss_panel_offsets["left"]
	panel.expand_margin_right = loss_panel_offsets["right"]
	panel.expand_margin_top = loss_panel_offsets["top"]
	panel.expand_margin_bottom = loss_panel_offsets["bottom"]

func return_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		return_to_char_select.emit()
		queue_free()


var replay_requested := false

func replay_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		if replay_requested:
			return
		replay_requested = true
		$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer2.modulate = Color.hex(0xffffff60)
		save_replay.emit()


func mark_replay_saved():
	$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer2.modulate = Color.GREEN


func stat_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		match_stats.emit()


func return_hover():
	$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.RED


func return_stop_hover():
	$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.WHITE


func replay_hovered():
	$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer2.modulate = Color.RED


func replay_hover_stopped():
	$MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/MarginContainer/VBoxContainer/PanelContainer2.modulate = Color.WHITE
