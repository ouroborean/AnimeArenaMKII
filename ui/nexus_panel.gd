extends HBoxContainer
class_name NexusPanel

var _player
var requested_universe
var _pending_leaderboard = null
var _home_leaderboard = null # Array of [character, ap] pairs
var _active_buckets: Dictionary = {} # { character_path_name: bucket }
var _selected_character_path = ""
var _in_home_view = true

signal request_universe_buckets(panel, universe)
signal close_panel()
signal change_panel(panel)
signal contribute_amount(character_path_name, amount)

@onready var ap_label = $PanelBG/ContentMargin/MainVBox/HeaderRow/HeaderBox/APLabel
@onready var universe_list = $PanelBG/ContentMargin/MainVBox/BodyContent/UniverseColumn/UniverseScroll/UniverseList
@onready var leaderboard_list = $PanelBG/ContentMargin/MainVBox/BodyContent/LeaderboardColumn/LeaderboardScroll/LeaderboardList
@onready var leaderboard_header = $PanelBG/ContentMargin/MainVBox/BodyContent/LeaderboardColumn/LeaderboardHeaderRow/LeaderboardHeader
@onready var back_button = $PanelBG/ContentMargin/MainVBox/BodyContent/LeaderboardColumn/LeaderboardHeaderRow/BackButton
@onready var contribution_panel = $PopupLayer/ContributionPanel

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()


static func new_nexus_panel(player):
	var panel = load("res://ui/nexus_panel.tscn").instantiate()
	panel._player = player
	return panel


func _ready():
	_build_universe_list()
	_update_ap_display()
	if _pending_leaderboard != null:
		assign_leaderboard(_pending_leaderboard)
		_pending_leaderboard = null


func _build_universe_list():
	var keys = CharacterConcept.Universe.keys()
	keys.sort()
	print(keys)
	for i in range(len(CharacterConcept.Universe.keys())):
		var universe = CharacterConcept.Universe[keys[i]]
		var node = NexusUniverseNode.from_universe(universe)
		node.requested_universe.connect(universe_node_clicked)
		universe_list.add_child(node)


func assign_player(player):
	_player = player
	if ap_label:
		_update_ap_display()


func _update_ap_display():
	if _player and ap_label:
		ap_label.text = str(int(_player.ap))


func accept_buckets(buckets):
	_in_home_view = false
	_active_buckets.clear()
	_clear_leaderboard()
	var universe_name = CharacterConcept.Universe.keys()[requested_universe].capitalize()
	leaderboard_header.text = universe_name + " Characters"
	if back_button:
		back_button.visible = true

	for bucket in buckets:
		_active_buckets[bucket.character_concept.path_name] = bucket

	_refresh_universe_entries()


func _make_entry_clickable(node: Control, character, ap: int):
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.gui_input.connect(_on_entry_clicked.bind(character, ap))


func _on_entry_clicked(event: InputEvent, character, ap: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		_selected_character_path = character.path_name
		contribution_panel.assign_character(character.character_name, ap)
		contribution_panel.visible = true


func _on_contribute_amount(amount):
	if amount <= 0:
		return
	if _player and _player.ap >= amount and _selected_character_path != "":
		contribute_amount.emit(_selected_character_path, amount)
		print("Contributing amount: " + str(amount))
		# Optimistically update local state so UI reflects the change immediately
		if _in_home_view:
			_apply_home_contribution(_selected_character_path, amount)
			_show_home_leaderboard()
		else:
			if _selected_character_path in _active_buckets:
				_active_buckets[_selected_character_path].ap += amount
			_refresh_universe_entries()
		_update_ap_display()
	else:
		print("Panel contribution failed due to failcases")


func _on_close_contribution():
	play_sound("click")
	_selected_character_path = ""
	contribution_panel.visible = false


func _apply_home_contribution(path_name: String, amount: int):
	if _home_leaderboard == null:
		return
	for pair in _home_leaderboard:
		if pair[0].path_name == path_name:
			pair[1] = int(pair[1]) + amount
			break
	_home_leaderboard.sort_custom(func(a, b): return a[1] > b[1])


func _refresh_universe_entries():
	_clear_leaderboard()
	var buckets = []
	for path_name in _active_buckets:
		var bucket = _active_buckets[path_name]
		var node = NexusLeaderboardListNode.from_character_and_ap(bucket.character_concept, bucket.ap)
		_make_entry_clickable(node, bucket.character_concept, bucket.ap)
		buckets.append(node)
	buckets.sort_custom(func(a, b): 
		return a.character_name.naturalnocasecmp_to(b.character_name) < 0
	)
	for node in buckets:
		leaderboard_list.add_child(node)


# Called by bucket_handler after the server confirms a contribution update.
func update_all_bucket_displays():
	print("Nexus panel updating bucket displays after server response!")
	if _active_buckets.is_empty():
		return
	_refresh_universe_entries()


func assign_leaderboard(leading_character_sets):
	if not leaderboard_list:
		_pending_leaderboard = leading_character_sets
		return

	# Copy as mutable [character, ap] pairs so we can update AP in place
	_home_leaderboard = []
	for set in leading_character_sets:
		_home_leaderboard.append([set[0], int(set[1])])
	_show_home_leaderboard()


func _show_home_leaderboard():
	_in_home_view = true
	_active_buckets.clear()
	_clear_leaderboard()
	leaderboard_header.text = "Top Characters"
	if back_button:
		back_button.visible = false

	if _home_leaderboard == null:
		return

	for pair in _home_leaderboard:
		var character = pair[0]
		var ap = pair[1]
		var node = NexusLeaderboardListNode.from_character_and_ap(character, ap)
		_make_entry_clickable(node, character, ap)
		leaderboard_list.add_child(node)


func _clear_leaderboard():
	for child in leaderboard_list.get_children():
		child.queue_free()


func _on_back_button_pressed():
	play_sound("click")
	_show_home_leaderboard()


func universe_node_clicked(universe):
	print("Requested character concepts from " + CharacterConcept.Universe.keys()[universe].capitalize())
	requested_universe = universe
	request_universe_buckets.emit(self, universe)


func close_clicked():
	play_sound("click")
	close_panel.emit()


func _on_cancel_button_mouse_entered():
	$CloseMargin/CloseButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_cancel_button_mouse_exited():
	$CloseMargin/CloseButton.modulate = Color.WHITE
