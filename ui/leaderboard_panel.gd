extends HBoxContainer
class_name LeaderboardPanel

signal request_ladder(panel)
signal change_panel(panel)
signal close_panel()

enum Tab { RATING, MOST_WINS, WIN_STREAK, CLANS, CHARACTER }

var current_tab: Tab = Tab.MOST_WINS
var ladder_data = null
var _example_players: Array = []
var _char_list = []
var _selected_character = null
var _character_grid_initialized = false
var _character_mastery_cache: Dictionary = {} # { character_path_name: Array of player mastery dicts }
var _use_example_data = false

var accent_color = Color(0.698039, 0.219608, 0.231373, 1)
var tab_inactive_color = Color(0.15, 0.15, 0.15, 1)

@onready var row_list = $PanelBG/ContentMargin/MainVBox/ScrollContainer/RowList
@onready var scroll_container = $PanelBG/ContentMargin/MainVBox/ScrollContainer
@onready var header_row = $PanelBG/ContentMargin/MainVBox/HeaderRow
@onready var header_sep = $PanelBG/ContentMargin/MainVBox/HSeparator2
@onready var character_grid = $PanelBG/ContentMargin/MainVBox/CharacterGrid
@onready var grid_flow = $PanelBG/ContentMargin/MainVBox/CharacterGrid/GridFlow
@onready var header_labels = [
	$PanelBG/ContentMargin/MainVBox/HeaderRow/Col0,
	$PanelBG/ContentMargin/MainVBox/HeaderRow/Col1,
	$PanelBG/ContentMargin/MainVBox/HeaderRow/Col2,
	$PanelBG/ContentMargin/MainVBox/HeaderRow/Col3,
	$PanelBG/ContentMargin/MainVBox/HeaderRow/Col4,
]
@onready var tab_buttons = {
	Tab.RATING: $PanelBG/ContentMargin/MainVBox/TabBar/TabRating,
	Tab.MOST_WINS: $PanelBG/ContentMargin/MainVBox/TabBar/TabWins,
	Tab.WIN_STREAK: $PanelBG/ContentMargin/MainVBox/TabBar/TabStreak,
	Tab.CLANS: $PanelBG/ContentMargin/MainVBox/TabBar/TabClans,
	Tab.CHARACTER: $PanelBG/ContentMargin/MainVBox/TabBar/TabCharacter,
}

var body_font = preload("res://assets/LATO-BLACK.TTF")
var bold_font = preload("res://assets/ROBOTO-BOLD.TTF")
var title_font = preload("res://assets/BASEMENTGROTESQUE-BLACK_V1.202.OTF")


func _ready():
	_update_tab_visuals()
	_update_headers()
	if _use_example_data:
		ladder_data = _generate_example_data()
	_populate_current_tab()


func set_char_list(char_list: Array):
	_char_list = char_list


func _generate_example_data() -> Dictionary:
	var player_names = [
		["Cheshire", "Shadow Cats"],
		["NarutoFan99", "Leaf Village"],
		["SasukeMain", "Leaf Village"],
		["GokuBlack", "Saiyan Elite"],
		["ZeroTwo_002", "Darlings"],
		["LeviBoss", "Scout Regiment"],
		["AllMightFan", "Hero Academy"],
		["Itachi_Uchiha", "Akatsuki"],
		["SpikeSpiegel", "Bebop Crew"],
		["Rem_Is_Best", "Clanless"],
		["ErenYeager", "Scout Regiment"],
		["LuffyD", "Straw Hats"],
		["MikasaA", "Scout Regiment"],
		["Vegeta_Prince", "Saiyan Elite"],
		["TojouKirby", "Clanless"],
		["HisokaJoker", "Phantom Troupe"],
		["SaitamaOPM", "Hero Academy"],
		["Deku_Smash", "Hero Academy"],
		["KilluaZ", "Phantom Troupe"],
		["TanjiroKamado", "Demon Slayers"],
	]

	var player_data = []
	for i in player_names.size():
		var name_clan = player_names[i]
		var wins = randi_range(5, 200)
		var losses = randi_range(2, 80)
		var streak = randi_range(-6, 15)
		var rating = randi_range(400, 2000)
		player_data.append({
			"username": name_clan[0],
			"clan_name": name_clan[1],
			"wins": wins,
			"losses": losses,
			"streak": streak,
			"rating": rating,
		})
	_example_players = player_data

	var clan_data = [
		{"clan_name": "Scout Regiment", "wins": 320, "losses": 150, "level": 8, "members": 3},
		{"clan_name": "Saiyan Elite", "wins": 250, "losses": 100, "level": 7, "members": 2},
		{"clan_name": "Hero Academy", "wins": 210, "losses": 130, "level": 6, "members": 3},
		{"clan_name": "Leaf Village", "wins": 180, "losses": 90, "level": 5, "members": 2},
		{"clan_name": "Phantom Troupe", "wins": 140, "losses": 80, "level": 4, "members": 2},
		{"clan_name": "Straw Hats", "wins": 100, "losses": 60, "level": 3, "members": 1},
		{"clan_name": "Demon Slayers", "wins": 90, "losses": 50, "level": 3, "members": 1},
		{"clan_name": "Darlings", "wins": 60, "losses": 40, "level": 2, "members": 1},
		{"clan_name": "Bebop Crew", "wins": 45, "losses": 30, "level": 2, "members": 1},
		{"clan_name": "Shadow Cats", "wins": 30, "losses": 10, "level": 1, "members": 1},
	]

	return {
		"by_rating": _example_top("rating", player_data),
		"by_wins": _example_top("wins", player_data),
		"by_streak": _example_top("streak", player_data),
		"clan_data": clan_data,
	}


func _example_top(sort_key: String, rows: Array) -> Dictionary:
	var filtered = []
	for row in rows:
		if row[sort_key] <= 0:
			continue
		filtered.append(row)
	filtered.sort_custom(func(a, b): return a[sort_key] > b[sort_key])
	return {"top": filtered, "me": null}


func _generate_character_mastery_data(character_path: String) -> Array:
	var example_players = _example_players
	var mastery_data = []
	for player in example_players:
		var xp = randi_range(0, 6000)
		var level = MasteryConfig.xp_to_level(xp)
		if level == 0:
			continue
		mastery_data.append({
			"username": player.get("username", "???"),
			"clan_name": player.get("clan_name", "Clanless"),
			"xp": xp,
			"level": level,
		})
	mastery_data.sort_custom(func(a, b): return a["xp"] > b["xp"])
	return mastery_data


func _switch_tab(tab: Tab):
	if tab == current_tab:
		return
	_selected_character = null
	current_tab = tab
	_update_tab_visuals()
	_update_headers()
	_populate_current_tab()


func _update_tab_visuals():
	for tab in tab_buttons:
		var btn = tab_buttons[tab]
		var style = StyleBoxFlat.new()
		if tab == current_tab:
			style.bg_color = accent_color
		else:
			style.bg_color = tab_inactive_color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("pressed", style)
		var hover_style = style.duplicate()
		if tab != current_tab:
			hover_style.bg_color = Color(0.25, 0.18, 0.19, 1)
		btn.add_theme_stylebox_override("hover", hover_style)


func _update_headers():
	var show_leaderboard_view = current_tab != Tab.CHARACTER or _selected_character != null
	header_row.visible = show_leaderboard_view
	header_sep.visible = show_leaderboard_view
	scroll_container.visible = show_leaderboard_view
	character_grid.visible = current_tab == Tab.CHARACTER and _selected_character == null

	if not show_leaderboard_view:
		return

	var headers = []
	match current_tab:
		Tab.RATING:
			headers = ["#", "Player", "Clan", "Rating", "Record"]
		Tab.MOST_WINS:
			headers = ["#", "Player", "Clan", "Total Wins", "Record"]
		Tab.WIN_STREAK:
			headers = ["#", "Player", "Clan", "Streak", "Record"]
		Tab.CLANS:
			headers = ["#", "Clan", "Members", "Level", "Record"]
		Tab.CHARACTER:
			headers = ["#", "Player", "Clan", "Mastery XP", "Level"]
	for i in headers.size():
		header_labels[i].text = headers[i]


# --- Server data receiver functions ---
# Call these from the server to populate leaderboards with real data.

# Accepts the main ladder data dictionary from the server.
# Expected format (server pre-sorts each metric and slices to the top N;
# `me` is null when the requesting player is already in `top`, otherwise
# carries their full rank + row so the client can show a "you" entry):
# {
#   "by_rating": {"top": [PlayerRow, ...], "me": null | {"rank": int, "row": PlayerRow}},
#   "by_wins":   {"top": [PlayerRow, ...], "me": null | {"rank": int, "row": PlayerRow}},
#   "by_streak": {"top": [PlayerRow, ...], "me": null | {"rank": int, "row": PlayerRow}},
#   "clan_data": [ClanRow, ...]
# }
# PlayerRow: {"username": String, "wins": int, "losses": int, "rating": int, "streak": int, "ranked_streak": int, "clan_name": String}
# ClanRow:   {"clan_name": String, "wins": int, "losses": int, "level": int, "members": int}
func accept_ladder_data(data):
	_use_example_data = false
	ladder_data = data
	_populate_current_tab()

# Accepts mastery leaderboard data for a specific character.
# Expected format:
# [
#   {"username": String, "clan_name": String, "xp": int, "level": int},
#   ...
# ]
# Data should be pre-sorted by xp descending from the server.
func accept_character_mastery_data(character_path: String, data: Array):
	_character_mastery_cache[character_path] = data
	if _selected_character != null and _selected_character.path_name == character_path:
		_populate_current_tab()


func _populate_current_tab():
	for child in row_list.get_children():
		child.queue_free()

	if ladder_data == null:
		return
	
	match current_tab:
		Tab.RATING:
			_populate_player_tab("rating")
		Tab.MOST_WINS:
			_populate_player_tab("wins")
		Tab.WIN_STREAK:
			_populate_player_tab("streak")
		Tab.CLANS:
			_populate_clan_tab()
		Tab.CHARACTER:
			if _selected_character != null:
				_populate_character_mastery_tab()
			else:
				_show_character_grid()


func _show_character_grid():
	if _character_grid_initialized:
		return
	_character_grid_initialized = true
	for character in _char_list:
		var button = CharacterButton.from_character(character, false)
		button.button_clicked.connect(_on_character_selected)
		grid_flow.add_child(button)


func _on_character_selected(character, _locked):
	_selected_character = character
	_update_headers()
	_populate_current_tab()


func _populate_character_mastery_tab():
	var char_path = _selected_character.path_name
	var mastery_data = []
	if char_path in _character_mastery_cache:
		mastery_data = _character_mastery_cache[char_path]
	elif _use_example_data:
		mastery_data = _generate_character_mastery_data(char_path)

	# Add a back button row at the top
	var back_row = HBoxContainer.new()
	var back_btn = Button.new()
	back_btn.text = "< Back to Characters"
	back_btn.add_theme_font_override("font", bold_font)
	back_btn.add_theme_font_size_override("font_size", 13)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = tab_inactive_color
	back_style.corner_radius_top_left = 4
	back_style.corner_radius_top_right = 4
	back_style.corner_radius_bottom_left = 4
	back_style.corner_radius_bottom_right = 4
	back_style.content_margin_left = 8
	back_style.content_margin_right = 8
	back_style.content_margin_top = 4
	back_style.content_margin_bottom = 4
	back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover = back_style.duplicate()
	back_hover.bg_color = Color(0.25, 0.18, 0.19, 1)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	back_btn.pressed.connect(func():
		_selected_character = null
		_update_headers()
		_populate_current_tab()
	)
	back_row.add_child(back_btn)

	var char_label = Label.new()
	char_label.text = "   " + _selected_character.character_name + " Mastery"
	char_label.add_theme_font_override("font", title_font)
	char_label.add_theme_font_size_override("font_size", 16)
	char_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_row.add_child(char_label)

	row_list.add_child(back_row)

	# Add separator
	var sep = HSeparator.new()
	row_list.add_child(sep)

	if mastery_data.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No players have mastery XP for this character yet."
		empty_label.add_theme_font_override("font", body_font)
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		row_list.add_child(empty_label)
		return

	var count = 1
	for data_set in mastery_data:
		var row = _create_row(
			count,
			data_set.get("username", "???"),
			data_set.get("clan_name", "Clanless"),
			str(int(data_set.get("xp", 0))) + " XP",
			"Lv. " + str(int(data_set.get("level", 0)))
		)
		row_list.add_child(row)
		count += 1


func _populate_player_tab(sort_key: String):
	var data_key = ""
	match sort_key:
		"rating":
			data_key = "by_rating"
		"wins":
			data_key = "by_wins"
		"streak":
			data_key = "by_streak"
	if data_key == "" or not data_key in ladder_data:
		return

	var tab_data = ladder_data[data_key]
	var top = tab_data.get("top", [])
	var me = tab_data.get("me", null)

	var count = 1
	for data_set in top:
		var row = _create_row(count, data_set.get("username", "???"), data_set.get("clan_name", "Clanless"), _get_stat_value(data_set, sort_key), str(int(data_set.get("wins", 0))) + "W-" + str(int(data_set.get("losses", 0))) + "L")
		row_list.add_child(row)
		count += 1

	if me != null:
		row_list.add_child(HSeparator.new())
		var me_row = me["row"]
		var me_rank = int(me["rank"])
		var row = _create_row(me_rank, me_row.get("username", "???") + " (You)", me_row.get("clan_name", "Clanless"), _get_stat_value(me_row, sort_key), str(int(me_row.get("wins", 0))) + "W-" + str(int(me_row.get("losses", 0))) + "L")
		row_list.add_child(row)


func _populate_clan_tab():
	var sorted_data = ladder_data["clan_data"].duplicate()
	sorted_data.sort_custom(func(a, b): return a.get("level", 0) > b.get("level", 0))

	var count = 1
	for data_set in sorted_data:
		var row = _create_row(count, data_set.get("clan_name", "???"), str(int(data_set.get("members", 0))), str(int(data_set.get("level", 0))), str(int(data_set.get("wins", 0))) + "W-" + str(int(data_set.get("losses", 0))) + "L")
		row_list.add_child(row)
		count += 1


func _get_stat_value(data: Dictionary, sort_key: String) -> String:
	match sort_key:
		"rating":
			return str(int(data.get("rating", 0)))
		"wins":
			return str(int(data.get("wins", 0)))
		"streak":
			var streak_val = int(data.get("streak", 0))
			if streak_val > 0:
				return "+" + str(streak_val)
			elif streak_val < 0:
				return str(abs(streak_val)) + "L"
			else:
				return "0"
	return ""


func _create_row(rank: int, col1: String, col2: String, col3: String, col4: String) -> HBoxContainer:
	var row = HBoxContainer.new()

	var rank_label = Label.new()
	rank_label.text = str(rank)
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_label.size_flags_stretch_ratio = 0.3
	rank_label.add_theme_font_override("font", body_font)
	rank_label.add_theme_font_size_override("font_size", 14)
	if rank <= 3:
		rank_label.add_theme_font_override("font", title_font)
		rank_label.add_theme_color_override("font_color", accent_color)
		rank_label.add_theme_font_size_override("font_size", 13)
	row.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = col1
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = 1.5
	name_label.add_theme_font_override("font", title_font)
	name_label.add_theme_font_size_override("font_size", 13)
	row.add_child(name_label)

	var col2_label = Label.new()
	col2_label.text = col2
	col2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_label.size_flags_stretch_ratio = 1.0
	col2_label.add_theme_font_override("font", body_font)
	col2_label.add_theme_font_size_override("font_size", 14)
	row.add_child(col2_label)

	var stat_label = Label.new()
	stat_label.text = col3
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_label.size_flags_stretch_ratio = 0.8
	stat_label.add_theme_font_override("font", bold_font)
	stat_label.add_theme_font_size_override("font_size", 14)
	row.add_child(stat_label)

	var record_label = Label.new()
	record_label.text = col4
	record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_label.size_flags_stretch_ratio = 0.8
	record_label.add_theme_font_override("font", body_font)
	record_label.add_theme_font_size_override("font_size", 14)
	row.add_child(record_label)

	return row


func request_ladder_information():
	request_ladder.emit(self)


# --- Tab button handlers ---
func _on_tab_rating():
	_switch_tab(Tab.RATING)

func _on_tab_wins():
	_switch_tab(Tab.MOST_WINS)

func _on_tab_streak():
	_switch_tab(Tab.WIN_STREAK)

func _on_tab_clans():
	_switch_tab(Tab.CLANS)

func _on_tab_character():
	_switch_tab(Tab.CHARACTER)


# --- Close button handlers ---
func _on_close_mouse_entered():
	$CloseMargin/CloseButton.modulate = Color.hex(0xffffff80)

func _on_close_mouse_exited():
	$CloseMargin/CloseButton.modulate = Color.WHITE

func _on_close_pressed():
	close_panel.emit()
