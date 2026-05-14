extends Control
class_name CharSelectScene

var TARGET_IP = "localhost"
var TARGET_PORT = 5692
var connected_peer_ids = []
var multiplayer_peer = ENetMultiplayerPeer.new()
var match_waiting = false

var char_list = []
var picking = false
var banning = false
var drafting = false
var queueing = false
var info_panel
var select_panel
var _player
var player_info_panel
var _enemy
var going_first = false
var match_bans = []
var _seed
var selected_character
var menu_up = false
var menu_panel
var page_number = 1
var search_panel
signal character_loading_finished()
signal save_cosmetic_changes(player)
signal request_character_buckets(panel, universe)
signal send_bucket_update(path_name, amount)
signal admin_action(request_type, args)
signal request_ladder_details(panel)
signal reconnect_to_match()
signal request_clan_creation(clan_name, clan_avatar_url, panel)
signal send_clan_info_request(clan_name, return_display)
signal send_clan_search_request(search_string, return_display)
signal send_player_search_request(search_string, return_display)
signal clan_application_received(clan_name, player_name)
signal request_player_application_invite_info(player_name, panel)
signal request_clan_application_invite_info(clan_name, panel)
signal send_cancel_clan_application(clan_name, player_name)
signal clan_invitation_received(clan_name, player_name)
signal send_cancel_clan_invitation(clan_name, player_name)
signal send_clan_offer_accepted(clan_name, player_name)
signal send_kick(clan_name, player_name)
signal send_promotion(clan_name, player_name)
signal send_demotion(clan_name, player_name)
signal send_leave(clan_name, player_name)



var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"character_click": load("res://assets/sounds/champ_select.mp3"),
	"soft_click": load("res://assets/sounds/soft_click.mp3"),
	"hard_click": load("res://assets/sounds/hard_clatter.mp3"),
	"pop": load("res://assets/sounds/pop.mp3"),
	"soft_clatter": load('res://assets/sounds/soft_clatter.mp3'),
	"panel_bop": load("res://assets/sounds/panel_bop.mp3"),
	"short_beep": load("res://assets/sounds/short_beep.mp3")
}

var char_name_list = []
@export var blotter: PanelContainer

signal queue_quick_match(player)
signal queue_ranked_match(player)
signal queue_private_match(player, search_name)
signal ban_hero(character)
signal pick_hero(character)
signal match_found()
signal start_battle(player, enemy, first, seed, match_type, canonical_role)
signal start_battle_reconnect(player, enemy, snapshot, match_type, canonical_role, timer_remaining)
signal start_battle_spectate(p1_player, p2_player, snapshot, match_type, timer_remaining)
signal start_replay(p1_player, p2_player, replay_log)
signal spectate_requested(target_username)
signal select_character()
signal update_player(player)
signal send_queue_cancellation(player)
signal request_avatar_update(player)
signal finalize_avatar_data(player)
signal request_new_version(reroute)
signal request_leaderboard_concepts()

# Called when the node enters the scene tree for the first time.
func _ready():
	char_name_list = CharacterDatabase.char_name_list()

func catch_admin_action(action_type, args):
	admin_action.emit(action_type, args)


func assign_player(player):
	# Remove and free children immediately (not deferred) so that the
	# call_deferred("add_child") calls below never race with stale nodes.
	for child in $RowContainer/SelectRowMargin/SelectRow/HBoxContainer.get_children():
		$RowContainer/SelectRowMargin/SelectRow/HBoxContainer.remove_child(child)
		child.queue_free()
	# Clear programmatically-added children from the right-hand column
	# (player info panel, extra buttons) so they aren't duplicated on re-entry.
	for child in $RowContainer/SelectRowMargin/SelectRow/HBoxContainer2.get_children():
		$RowContainer/SelectRowMargin/SelectRow/HBoxContainer2.remove_child(child)
		child.queue_free()
	# Remove any previously-added replay button from the menu bar.
	var menu_bar = $RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/MarginContainer/HBoxContainer
	for child in menu_bar.get_children():
		if child is Button:
			menu_bar.remove_child(child)
			child.queue_free()

	$TextureRect.texture = load("res://assets/backgrounds/" + player.equipped_charselect_background + ".png")

	print("Cleared children")
	_player = player
	$BotTimer.wait_time = 3.5
	if _player.muted:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -100)
	GlobalPlayerSettings.threat_assist = player.mark_significant
	$UpdateTimer.start()
	print("Started update timer")
	player_info_panel = PlayerInfoPanel2.from_player(_player)
	print("Created Player info panel")
	select_character.connect(player_info_panel.update_team)
	update_player.connect(player_info_panel.update_player)
	print("Created connections for player info panel")
	player_info_panel.avatar_request.connect(receive_avatar_request)
	print("connected team button clicked")
	player_info_panel.team_button_clicked.connect(team_button_clicked)
	
	var filter_panel = load("res://ui/filter_panel.tscn").instantiate()
	filter_panel.filter_by_colors.connect(filter_by_color)
	filter_panel.filter_by_beginner.connect(filter_beginner)
	filter_panel.randomize_team.connect(randomize_player_team)
	$RowContainer/SelectRowMargin/SelectRow/HBoxContainer.call_deferred("add_child", filter_panel)
	print("Added filter panel")
	initialize_character_list_panel()
	print("Initialized character list panel")
	
	await get_tree().create_timer(0.2).timeout
	
	print("trying to add player info panel")
	$RowContainer/SelectRowMargin/SelectRow/HBoxContainer2.call_deferred("add_child", player_info_panel)
	
	print("Player info panel added")
	var extra_buttons_right = load("res://ui/char_select_side_buttons_right.tscn").instantiate()
	$RowContainer/SelectRowMargin/SelectRow/HBoxContainer2.call_deferred("add_child", extra_buttons_right)
	extra_buttons_right.clan_button_clicked.connect(open_clan_panel)
	print("Added extra buttons on the right")

	if not match_waiting:
		settle_remembered_team()
	else:
		match_waiting = false
		print("The client should attempt to reconnect to a forgotten match now!")
		attempt_reconnect()

func randomize_player_team():
	print("Randomize player team")
	var remove_list = []
	for path_name in _player.equipped_characters:
		remove_list.append(path_name)
	for path_name in remove_list:
		_player.remove_character(path_name)
		unlock_character_button(path_name)
	select_character.emit()
	var team = generate_balanced_team(char_list)
	for character in team:
		lock_character_button(character.path_name)
		_player.recruit_character(character)
	select_character.emit()

func filter_by_color(colors):
	select_panel.filter_by_color(colors)

func filter_beginner(on):
	select_panel.filter_by_beginner(on)

func open_clan_panel(refresh_tab=""):
	var panel = load("res://ui/clan_panel.tscn").instantiate()
	#TODO: add ingest details step to get player clan information
	panel.attempt_create_clan.connect(receive_clan_creation_attempt)
	panel.request_clan_search.connect(request_clan_search_info)
	panel.request_clan_info.connect(request_clan_info)
	panel.send_clan_application.connect(send_clan_application)
	panel.send_cancel_clan_application.connect(receive_cancel_clan_application)
	panel.send_player_invitation.connect(receive_clan_invitation)
	panel.send_cancel_player_invitation.connect(receive_cancel_player_invitation)
	panel.send_clan_offer_accept.connect(receive_clan_offer_accepted)
	panel.request_player_search.connect(request_player_search_info)
	panel.refresh_panel.connect(refresh_clan_panel)
	panel.send_kick.connect(receive_kick)
	panel.send_leave.connect(receive_leave)
	panel.send_promotion.connect(receive_promotion)
	panel.send_demotion.connect(receive_demotion)
	panel.set_player(_player)
	open_menu_panel(panel)
	if _player.clan != "Clanless":
		panel.clan_management_mode()
		request_clan_info(_player.clan, panel)
		request_clan_application_invite_info.emit(_player.clan, panel)
	else:
		request_player_application_invite_info.emit(_player.username, panel)
	if refresh_tab != "":
		panel.set_tab_active(refresh_tab)
	else:
		panel.set_tab_active("my_clan")


func receive_kick(clan_name, player_name):
	send_kick.emit(clan_name, player_name)

func receive_promotion(clan_name, player_name):
	send_promotion.emit(clan_name, player_name)

func receive_demotion(clan_name, player_name):
	send_demotion.emit(clan_name, player_name)

func receive_leave(clan_name, player_name):
	print("Character Select Scene sending leave")
	send_leave.emit(clan_name, player_name)


func refresh_clan_panel(target_tab):
	close_menu_panel()
	open_clan_panel(target_tab)

func receive_cancel_clan_application(clan_name, player_name):
	send_cancel_clan_application.emit(clan_name, player_name)

func send_clan_application(clan):
	clan_application_received.emit(clan, _player.username)

func request_clan_search_info(clan_search_string, panel):
	send_clan_search_request.emit(clan_search_string, panel)

func request_player_search_info(player_search_string, panel):
	send_player_search_request.emit(player_search_string, panel)

func receive_clan_creation_attempt(clan_name, clan_avatar_url, panel):
	print(_player.username + " attempting to create new clan: " + clan_name)
	request_clan_creation.emit(clan_name, clan_avatar_url, panel)

func request_clan_info(clan_name, return_display):
	send_clan_info_request.emit(clan_name, return_display)

func receive_clan_invitation(clan_name, player_name):
	clan_invitation_received.emit(clan_name, player_name)

func receive_cancel_player_invitation(clan_name, player_name):
	send_cancel_clan_invitation.emit(clan_name, player_name)

func receive_clan_offer_accepted(clan_name, player_name):
	send_clan_offer_accepted.emit(clan_name, player_name)

func attempt_reconnect():
	reconnect_to_match.emit()

func generate_balanced_team(all_characters: Array = char_list, team_size: int = 3) -> Array:
	var team = []
	var attempts = 0
	var max_attempts = 100 # Prevent infinite loops
	
	while team.size() < team_size and attempts < max_attempts:
		var candidate = all_characters.pick_random()
		
		if candidate in team or not (candidate.unlocked(_player)):
			continue
		var color_exists = false
		for character in team:
			if candidate.character_colors == character.character_colors:
				color_exists = true
				break
		if color_exists:
			continue
		if is_character_compatible(team + [candidate], candidate.character_colors):
			team.append(candidate)
		
		attempts += 1
		
	return team

func is_character_compatible(potential_team: Array, colors) -> bool:
	var color_counts = {0: 0, 1: 0, 2: 0, 3: 0}
	
	for char_data in potential_team:
		for color in char_data.character_colors:
			color_counts[color] += 1
			
	# Validation Logic
	var total_missing_colors = 0
	for color in color_counts:
		# Rule 1: No single color should be shared by too many people (Over-saturation)
		if color_counts[color] > 2 and len(colors) == 1: 
			return false
			
		if color_counts[color] == 0:
			total_missing_colors += 1
	
	# Rule 2: Diversity Check
	# If the team is full (3 members), we should ideally have at least 3 colors covered.
	if potential_team.size() == 3 and total_missing_colors > 1:
		return false
	if potential_team.size() == 2 and total_missing_colors > 2:
		return false
	return true


# Bot drafting uses ColorBalancedDraft (scripts/color_balanced_draft.gd) for
# the picker logic. See make_crazy_bot for the call site. The is_character_compatible
# / generate_balanced_team functions above are unrelated — they're for the
# player's UI team-building flow and operate on Character objects, not
# path_name strings.


func settle_remembered_team():
	var new_settled_char_list = []
	for character in char_list:
		if character.path_name in _player.equipped_characters and len(_player.team.characters) < 3 and not character in _player.team.characters:
			print("Got the character reference to " + character.path_name + " from team memory")
			new_settled_char_list.append(character.path_name)
			lock_character_button(character.path_name)
			_player.recruit_character(character)
			select_character.emit()
	_player.equipped_characters = new_settled_char_list


func initialize_characters(player_to_initialize):
	player_to_initialize.mission_reference = Mission.all_missions()
	player_to_initialize.compare_mission_reference()
	var starters = CharacterDatabase.starter_squads()
	for char in starters:
		var new_character = ResourceLoader.load("res://character/" + char + ".tscn").instantiate()
		new_character.initialize()
		char_list.append(new_character)
	for char in CharacterDatabase.char_name_list():
		if char in starters:
			continue
		var new_character = ResourceLoader.load("res://character/" + char + ".tscn").instantiate()
		new_character.initialize()
		char_list.append(new_character)
	character_loading_finished.emit()

func assign_enemy(enemy):
	_enemy = enemy

func hide_scene():
	visible = false

func show_scene():
	visible = true

func receive_avatar_request():
	request_avatar_update.emit(_player)
	send_avatar_update_request(_player.avatar_url)

func pass_character_bucket_request(panel, universe):
	print("Character select scene passing bucket request along!")
	request_character_buckets.emit(panel, universe)

func pass_bucket_contribution(path_name, amount):
	print(path_name + ": " + str(amount))
	_player.contribute_ap(amount)
	save_cosmetic_changes.emit(_player)
	send_bucket_update.emit(path_name, amount)

func initialize_character_list_panel():
	var panel = CharacterSelectPanel.from_character_list(char_list, _player)
	print("Created character select panel")
	panel.show_panel.connect(show_character_info_panel)
	select_panel = panel
	$RowContainer/SelectRowMargin/SelectRow/HBoxContainer.call_deferred("add_child", panel)
	print("Added character select panel")

func lock_character_button(character_name):
	select_panel.buttons[character_name].set_locked()

func unlock_character_button(character_name):
	select_panel.buttons[character_name].set_unlocked()

func team_button_clicked(character):
	if queueing:
		return
	
	
	if not character.initialized:
		character.initialize(true)
		character.initialized = true
	
	if selected_character != null and character.path_name == selected_character.path_name:
		_player.remove_character(character.path_name)
		unlock_character_button(character.path_name)
		select_character.emit()
		return
	
	selected_character = character
	if info_panel != null:
		remove_child(info_panel)
		info_panel.queue_free()
	
	var panel = CharacterSelectInfoPanel.from_character(_player, character, usable_check(character))
	info_panel = panel
	info_panel.clear_info.connect(clear_info_panel)
	add_child(info_panel)

func clear_info_panel():
	selected_character = null
	if info_panel != null:
		remove_child(info_panel)
		info_panel.queue_free()

func mission_button_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1 and not menu_up:
		print("Clicked mastery button!")
		var mastery_menu = MasteryInfoMenu.from_player_and_list(_player, char_list)
		open_menu_panel(mastery_menu)



func open_menu_panel(panel):
	activate_menu_state()
	if menu_panel != null:
		menu_panel.queue_free()
	menu_panel = panel
	menu_panel.close_panel.connect(close_menu_panel)
	clear_info_panel()
	blotter.add_child(menu_panel)

func change_panel(panel):
	if menu_up:
		print("Attempting to switch menus!")
		menu_panel.queue_free()
		menu_panel = panel
		if menu_panel is NexusUniverseCharacterPanel:
			menu_panel.contribute_amount.connect(pass_bucket_contribution)
			menu_panel.return_to_nexus.connect(nexus_pressed)
		if menu_panel is NexusPanel:
			menu_panel.request_universe_buckets.connect(pass_character_bucket_request)
			menu_panel.contribute_amount.connect(pass_bucket_contribution)
		menu_panel.change_panel.connect(change_panel)
		menu_panel.close_panel.connect(close_menu_panel)
		blotter.add_child(menu_panel)

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

func close_menu_panel():
	play_click_sound()
	save_cosmetic_changes.emit(_player)
	select_panel.update_buttons_locked_state(_player)
	$TextureRect.texture = load("res://assets/backgrounds/" + _player.equipped_charselect_background + ".png")
	$BotTimer.wait_time = 3.5
	if menu_panel != null:
		menu_panel.queue_free()
		
	deactivate_menu_state()

func activate_menu_state():
	menu_up = true
	blotter.visible = true

func deactivate_menu_state():
	menu_up = false
	blotter.visible = false
	player_info_panel.update_player(_player)


func info_button_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1 and not menu_up:
		print("Clicked info button!")
		var title_menu = TitleSelectMenu.from_player(_player, char_list)
		open_menu_panel(title_menu)

func show_character_info_panel(character, locked):
	
	
	if not character.initialized:
		character.initialize(true)
		character.initialized = true
	if selected_character == character and not menu_up:
		play_sound("click")
		if usable_check(character) and not locked:
			#Add the character to the player's team instead, because they're already selected
			lock_character_button(character.path_name)
			_player.recruit_character(character)
			select_character.emit()
		return
	
	play_sound("character_click")
	selected_character = character
	
	if info_panel != null:
		remove_child(info_panel)
		info_panel.queue_free()
	
	var panel = CharacterSelectInfoPanel.from_character(_player, character, usable_check(character))
	info_panel = panel
	info_panel.clear_info.connect(clear_info_panel)
	add_child(info_panel)

func usable_check(character):
	
	if menu_up or queueing:
		return false
	
	if len(_player.team.characters) >= 3:
		return false
	
	if not queueing:
		return true
	
	for char in _player.team.characters:
		if char.path_name == character.path_name:
			return false
	
	if character.path_name in match_bans:
		return false
	
	return true

func make_test_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Shinigami-sama")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/shinigamisama.png")
	var teams = [
		["maka", "sayaka", "grey"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player

func make_team_7_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("CopyNinja")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/copyninja.png")
	player.recruit_character(Character.from_character_name("naruto"), true)
	player.recruit_character(Character.from_character_name("sasuke"), true)
	player.recruit_character(Character.from_character_name("sakura"), true)
	for character in player.team.characters:
		character.bot_character = true
	
	return player

func make_9bi_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("9bi")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/9bi.png")
	var teams = [
		["naruto", "bakugo", "nezuko"],
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player

func make_digi_emperor_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("D1G13MP0R3R")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/digiemperor.png")
	var digimon = [
		"gatomon",
		"myotismon",
		"omnimon",
		"gallantmon",
		"renamon",
		"hawkmon",
		"machinedramon"
	]
	var team = []
	for i in range(3):
		digimon.shuffle()
		team.append(digimon.pop_front())
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player



func make_avenger_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("xXxAvengerxXx")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/avenger.png")
	var teams = [
		["sasuke", "tamaki", "jack"],
		["killua", "sasuke", "madoka"],
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player

func make_shannaro_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Shannaro Enthusiast")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/shannaro.png")
	var teams = [
		["sakura", "zoro", "goku"],
		["sakura", "byakuya", "tatsumi"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_mugiwara_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Mugiwara")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/mugiwara.png")
	var teams = [
		["luffy", "misaka", "gon"],
		["zoro", "luffy", "usopp"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_nuhuhuh_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Nuh uh uh")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/nuhuhuh.png")
	var teams = [
		["mash", "eren", "bakugo"],
		["mash", "shiro", "ryuko"],
		["kuroko", "semiramis", "mash"],
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_shinigami_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Shinigami-sama")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/shinigamisama.png")
	var teams = [
		["maka", "sayaka", "jack"],
		["maka", "soul", "gallantmon"],
		["soul", "nonon", "gilgamesh"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_killer_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("BornKiller420")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/bornkiller.png")
	var teams = [
		["tatsumi", "rimuru", "mikasa"],
		["tatsumi", "gray", "bakugo"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_hikari_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("itsHikari")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/hikari.png")
	var teams = [
		["gatomon", "usopp", "genos"],
		["gatomon", "kuroko", "mash"],
		["gatomon", "edward", "shiro"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_ripper_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Ripper the Ripper")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/ripper.png")
	var teams = [
		["jack", "nagisa", "natsu"],
		["jack", "tanjiro", "luffy"],
		["jack", "machinedramon", "sheele"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_bandcamp_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("BandCamp")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/bandcamp.png")
	var teams = [
		["nonon", "gilgamesh", "edward"],
		["nonon", "yamamoto", "vegeta"],
		["nonon", "nimaiya", "zenitsu"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_7ds_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("7DS Fangirl")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/7dsfangirl.png")
	var teams = [
		["diane", "sheele", "shiro"],
		["king", "tatsumaki", "vegeta"],
		["meliodas", "tanjiro", "kurapika"]
	]
	teams.shuffle()
	var team = teams.pop_front()
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player


func make_kazari_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("NotSorryKazari")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/kazari.png")
	var color_choices = [
		["zoro", "midoriya", "blackstar", "tatsumi", "rengoku", "diane", "yamamoto", "xanxus", "eren", "saitama", "tatsumaki", "shinra", "gon", "killua", "satsuki", "gatomon"],
		["luffy", "bakugo", "natsu", "maka", "sheele", "rengoku", "meliodas", "ryohei", "mikasa", "gilgamesh", "nonon", "ichigo", "ganta", "edward", "alphonse", "vegeta"],
		["gray", "sayaka", "yuno", "noelle", "tanjiro", "zenitsu", "king", "tsunayoshi", "tamaki", "mash", "edward", "goku", "vegeta", "machinedramon", "nagisa"],
		["sakura", "uraraka", "lucy", "madoka", "soul", "nezuko", "misaka", "jack", "semiramis", "nimaiya", "gatomon"],
		["naruto", "usopp", "asta", "aang", "korra", "eren", "shinra", "shiro", "rimuru", "machinedramon"]
	]
	color_choices.shuffle()
	var color_choice = color_choices[0]
	var team = []
	while len(team) < 3:
		color_choice.shuffle()
		if not color_choice[0] in team:
			team.append(color_choice[0])
			color_choices.pop_front()
			color_choice = color_choices[0]
	for character in team:
		var new_char = Character.from_character_name(character)
		new_char.bot_character = true
		player.recruit_character(new_char, true)
	return player

func make_ua_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("TheSleepySensei")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/sleepysensei.png")
	player.recruit_character(Character.from_character_name("midoriya"), true)
	player.recruit_character(Character.from_character_name("uraraka"), true)
	player.recruit_character(Character.from_character_name("bakugo"), true)
	for character in player.team.characters:
		character.bot_character = true
	
	return player

func make_crazy_bot():
	var player = load("res://components/player_component.tscn").instantiate()
	
	var usernames = [
		"ragingp0tato", "v3lvet_v0id", "distortdReality", "7thGhost", "cl0udchaser",
		"neon.drip_99", "prizmatik", "i_forgot_my_pw", "4ever_roam1ng", "glitchy_vibes",
		"s0ggycereal", "0verth1nker", "static.cl1ng", "rad_radish", "blurryfacex",
		"cryptic_n0te", "fossilizedfear", "hidden_gem22", "liq_uid_gold", "m0on_child",
		"niteshade", "pixelperfect88", "quantum_leap", "retro_grad3", "silv3r_lining",
		"tox1c_waste", "urbn_jungle", "velvetUnder", "wild_cardx", "xfactor99",
		"yell0w_mellow", "zephyrbreeze", "alph4_omega", "b3ta_tester", "gamma_ray9",
		"deltaForce", "epsil0n00", "zeta_prime", "eta_carina", "theta_wav3",
		"iotasmal", "kappaKing", "lambd4_09", "mu_mercury", "nuNautilus",
		"xi_xylophone", "0micron8", "pi_rate314", "rhoRider", "sigma_six",
		"tauTraveler", "upsil0n_up", "phiPhenom", "chi_chief22", "psi_p0wer",
		"omega_one", "arcticF0x", "des3rt_rat", "mountn_goat", "river_otter",
		"forestfaiiry", "jungl3_jim", "ocean0racle", "spaceCadet", "time_travlr",
		"worldwatch1", "finalFrontier", "blue_lag0on", "greenThumb", "red_baron89",
		"silv3r_surfer", "megaMind", "ultraV10let", "alphaw0lf", "beta_testr",
		"gammaray", "delta_f0rce", "epsil0n", "zetaPrime", "eta_carinae",
		"thetawav3", "i0ta_small", "kappa_king", "lambda09", "mu_merc",
		"nu_nautilus", "xi_xylo", "0micron", "pirate_life", "rho_rider",
		"sigm4_six", "tau_trav", "upsil0n", "phi_phenom", "chiChief",
		"psiPower", "omega1", "arctic_fox", "des3rt", "mountaingoat", "rasengone_404", "Scarl3t Requip", "mist_hashira_99", "gachi_vandal", "Bankai 0r Bust",
		"dattebay0_vibe", "Titania Scarlet", "muichiro_cloudz", "trashworld_rebel", "Chidori Spark",
		"Erza S", "sharingan_hacker", "DemonSlayr 00", "Jutsu Junkie", "enfer_cleaner",
		"Hidden Leaf", "scarlet_knight_x", "Mist Hashira", "gachiakuta_soul", "Ninetails Chakra",
		"requip_master", "Total Breathin", "sun_breather", "Amo Cleaner", "kage_cl0ne",
		"Flame Alchemist", "void_century_7", "Gum Gum Pist0l", "Super Saiyan 8", "Deku Smash",
		"todoroki_thaw", "Gojo Infinity", "sukuna_fingerz", "Chainsaw Devil", "denji_chainsaw",
		"Power Blood", "makima_control", "Levi Ackermn", "eren_founding", "Ackerman Clan",
		"Zoro 3 Sword", "straw_hat_pirate", "Luffy Gear5", "nami_climatact", "Sanji Cook",
		"chopper_rumble", "Robin Arch", "franky_super", "Brook Soul", "Jinbe Helmsman",
		"otaku_life_9", "Weeb Trash", "kawaii_desu_ne", "Senpai Notice Me", "tsundere_energy",
		"Yandere Love", "kuudere_cool_x", "Dandere Shy", "Shonen Jump", "shojo_dreamer",
		"seinen_edge_1", "Josei Heart", "mecha_pilot_0", "Isekai Garbage", "Slice of Life",
		"harem_king_v", "Reverse Harem", "Sports Anime", "haikyuu_set", "Kuroko Basket",
		"blue_lock_striker", "Egoist 00", "isagi_goal", "Nagi Trap", "bachira_monster",
		"chifuyu_reverie", "Tokyo Revengr", "draken_dragon_7", "Takemichi Time", "hinata_sun",
		"Kageyama Set", "bokuto_owl_8", "Akaashi Set", "oikawa_king", "Iwaizumi Ace",
		"guts_berserker", "Griffith Hawk", "casca_warrior", "Vash Stampede", "knives_mill",
		"spike_spiegel_x", "Faye Valentine", "Jet Black", "edward_wong_7", "Ein Corgi",
		"vicious_synd", "Julia Dream", "Bebop Crew", "swordfish_ii", "Space Cowboy", "alexander the average", "justin7792", "not_that_sarah", "heyitsme_kevin", "Where Is Julia",
		"totallynotamy", "MarkFromAccounting", "brian_the_viking", "Megan Does Things", "callum_02",
		"Is That Chloe", "random_dave_91", "jessicahasnoidea", "Wait Its Marcus", "ethan_is_online",
		"lookitsolivia", "Simply_Sebastian", "Ryan Was Taken", "natalie_99_x", "whos_this_guy",
		"ActuallyItsAaron", "Isabella In Ohio", "chris_lives_here", "lilypad_07", "The Real Thomas",
		"not_noah_again", "samuelthegreat", "Grace Under Fire", "luke_skywalker_99", "emily_writes_code",
		"just_another_ben", "Who Invited Kyle", "sophie.exe", "Daniel_In_Real_Life", "it_is_giving_clara",
		"Zoe On The Go", "matthew_the_human", "oliviaunfiltered", "Hannah From Work", "jordan_b_92",
		"Maybe Its May", "liam_is_lost", "chloe_just_exists", "Basically Bianca", "tyler_the_creator_fan",
		"its_just_jacob", "Olivia Not Libby", "sam_the_man_2026", "lily_pad_vibe", "Andrew_Is_Running",
		"tiffanyblue96", "Not That Brandon"
	]
	
	
	player.set_username(usernames.pick_random())
	player.bot_player = true
	var avatar_roll = randi_range(0, 1)
	if avatar_roll:
		var roll = randi_range(1, 72)
		player.avatar_texture = load("res://assets/avatars/" + str(roll) + ".png")
	else:
		player.avatar_texture = load("res://assets/avatars/toko_toda.png")
	var building_team = []

	# Color-balanced drafting via ColorBalancedDraft. tsubaki/toga remain
	# excluded for live bot teams as before.
	const _BOT_DRAFT_EXCLUDED := ["tsubaki", "toga"]
	while len(building_team) < 3:
		var pick = ColorBalancedDraft.pick_next(building_team, char_name_list, _BOT_DRAFT_EXCLUDED)
		if pick == "":
			# Pool exhausted (shouldn't happen with the full roster). Fall back
			# to uniform random so the bot still ends up with a team.
			var roll = randi_range(0, len(char_name_list) - 1)
			var name = char_name_list[roll]
			if name in building_team or name in _BOT_DRAFT_EXCLUDED:
				continue
			pick = name
		building_team.append(pick)
	for char_name in building_team:
		player.recruit_character(Character.from_character_name(char_name), true)
	for character in player.team.characters:
		character.bot_character = true
	player.rank.wins = randi_range(0, 50)
	player.rank.losses = int( (randf_range(0.2, 1.6) + randi_range(0, 1)) * player.rank.wins) 
	if randi_range(0, 1):
		player.rank.wins += randi_range(30, 75)
		if not randi_range(0, 2):
			player.rank.losses += randi_range(10, 40)
	return player

func make_random_bot():
	var bots = [
		make_crazy_bot,
	]
	bots.shuffle()
	return bots.pop_front().call()

func reset_scene(player):
	update_player.emit(player)
	select_panel.update_buttons_locked_state(player)

func accept_quick_match(opponent, opponent_characters, first, seed, canonical_role: int = 0, bot=false):
	queueing=false
	$UpdateTimer.stop()
	$BotTimer.stop()
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
	print("Accepting quick match in char select!")
	match_found.emit()
	
	going_first = first
	_seed = seed
	var enemy = Player.load_display_player(opponent)
	var new_player_chars = []
	for character in _player.team.characters:
		new_player_chars.append(Character.from_character_name(character.path_name))
	_player.team.characters.clear()
	var counter = 0
	for char in new_player_chars:
		if char.path_name == "toga" and _player.equipped_disguise != "" and _player.equipped_disguise != "toga":
			char.disguise_name = _player.equipped_disguise
		char.portrait_frame = _player.equipped_character_frames[counter]
		char.action_frame = _player.equipped_action_frames[counter]
		char.hat = _player.equipped_hats[counter]
		_apply_mastery_cosmetics(char, _player)
		counter += 1
		_player.recruit_character(char)
	counter = 0
	for char_name in opponent_characters:
		if counter == 3:
			break
		var char = Character.from_character_name(char_name)
		if char.path_name == "toga" and len(opponent_characters) > 3:
			char.disguise_name = opponent_characters[3]
		char.portrait_frame = enemy.equipped_character_frames[counter]
		char.action_frame = enemy.equipped_action_frames[counter]
		char.hat = enemy.equipped_hats[counter]
		_apply_mastery_cosmetics(char, enemy, true)
		counter += 1
		enemy.recruit_character(char, true)
	start_battle.emit(_player, enemy, first, seed, BattleScene.Match.QUICK, canonical_role)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func log_out_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		pass

func ranked_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		queue_ranked()

func quick_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
		var new_player_chars = []
		for character in _player.team.characters:
			new_player_chars.append(Character.from_character_name(character.path_name))
		_player.team.characters.clear()
		var counter = 0
		for char in new_player_chars:
			char.portrait_frame = _player.equipped_character_frames[counter]
			char.action_frame = _player.equipped_action_frames[counter]
			char.hat = _player.equipped_hats[counter]
			_apply_mastery_cosmetics(char, _player)
			counter += 1
			_player.recruit_character(char)

		var enemy = make_random_bot()

		start_battle.emit(_player, enemy, true, randi_range(0, 100000000), BattleScene.Match.BOT, 0)
		#queue_quick()

func receive_private_battle_target(username):
	queue_private(username)
	blotter.visible = false

func cancel_private_search():
	blotter.visible = false

func send_avatar_update_request(url):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", avatar_fetch_completed)
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)

func avatar_fetch_completed(result, response_code, headers, body):
	print("Finished HTTP request in char select")
	receive_avatar_texture(body)

func receive_avatar_texture(body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		_player.avatar_url = ""
		_player.avatar_texture = load("res://assets/avatars/toko_toda.png")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		_player.avatar_texture = texture
		player_info_panel.avatar_texture.texture = texture
		finalize_avatar_data.emit(_player)

func _on_bot_timer_timeout():
	if queueing:
		cancel_queue()
		$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
		var new_player_chars = []
		for character in _player.team.characters:
			new_player_chars.append(Character.from_character_name(character.path_name))
		_player.team.characters.clear()
		var counter = 0
		for char in new_player_chars:
			char.portrait_frame = _player.equipped_character_frames[counter]
			char.action_frame = _player.equipped_action_frames[counter]
			char.hat = _player.equipped_hats[counter]
			_apply_mastery_cosmetics(char, _player)
			counter += 1
			_player.recruit_character(char)

		var enemy = make_random_bot()

		start_battle.emit(_player, enemy, randi_range(0, 1), randi_range(0, 100000000), BattleScene.Match.BOT, 0)

func _on_update_timer_timeout():
	pass
	#request_new_version.emit(false)

func social_button_clicked():
	play_click_sound()
	print("Clicked cosmetics button!")
	var cosmetics_menu = CosmeticsMenu.from_player_and_list(_player, char_list)
	open_menu_panel(cosmetics_menu)

func title_button_clicked():
	print("Clicked info button!")
	play_sound("click")
	var title_menu = TitleSelectMenu.from_player(_player, char_list)
	open_menu_panel(title_menu)

func mastery_button_clicked():
	print("Clicked mastery button!")
	play_sound("click")
	var mastery_menu = MasteryInfoMenu.from_player_and_list(_player, char_list)
	open_menu_panel(mastery_menu)

func cancel_queue():
	play_sound("click")
	queueing = false
	menu_up = false
	$BotTimer.stop()
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
	send_queue_cancellation.emit()

func enemy_avatar_fetch_completed(result, response_code, headers, body):
	_enemy.avatar_fetch_completed(result, response_code, headers, body)

func accept_ranked_match(opponent, opponent_team, first, seed, canonical_role: int = 0):
	$UpdateTimer.stop()
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
	print("Accepting ranked match in char select!")
	match_found.emit()
	queueing=false
	going_first = first
	_seed = seed
	var enemy = Player.load_display_player(opponent)
	
	var new_player_chars = []
	for character in _player.team.characters:
		new_player_chars.append(Character.from_character_name(character.path_name))
	_player.team.characters.clear()
	var counter = 0
	for char in new_player_chars:
		if char.path_name == "toga" and _player.equipped_disguise != "" and _player.equipped_disguise != "toga":
			char.disguise_name = _player.equipped_disguise
		char.portrait_frame = _player.equipped_character_frames[counter]
		char.action_frame = _player.equipped_action_frames[counter]
		char.hat = _player.equipped_hats[counter]
		_apply_mastery_cosmetics(char, _player)

		counter += 1
		_player.recruit_character(char)
	counter = 0
	for char_name in opponent_team:
		if counter == 3:
			break
		var char = Character.from_character_name(char_name)
		if char.path_name == "toga" and len(opponent_team) > 3:
			char.disguise_name = opponent_team[3]

		char.portrait_frame = enemy.equipped_character_frames[counter]
		char.action_frame = enemy.equipped_action_frames[counter]
		char.hat = enemy.equipped_hats[counter]
		_apply_mastery_cosmetics(char, enemy, true)
		counter += 1
		enemy.recruit_character(char, true)
	start_battle.emit(_player, enemy, first, seed, BattleScene.Match.RANKED, canonical_role)

func nexus_pressed():
	play_sound('click')
	print("Clicked nexus button in char select!")
	request_leaderboard_concepts.emit()

func open_nexus_panel(sets):
	var nexus_menu = NexusPanel.new_nexus_panel(_player)
	nexus_menu.change_panel.connect(change_panel)
	nexus_menu.request_universe_buckets.connect(pass_character_bucket_request)
	nexus_menu.contribute_amount.connect(pass_bucket_contribution)
	nexus_menu.assign_leaderboard(sets)
	open_menu_panel(nexus_menu)


func queue_quick():
	if menu_up or queueing:
		print("Can't queue quick")
		print("Menu up: " + str(menu_up))
		print("Queueing: " + str(queueing))
		return
	#request_new_version.emit(false)
	if not queueing and len(_player.team.characters) == 3:
		$BotTimer.wait_time = randi_range(10, _player.bot_queue_delay)
		$BotTimer.start()
		queueing = true
		$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = true
		queue_quick_match.emit(_player)
	else:
		print("Queue failed; Length of player team: " + str(len(_player.team.characters)))

func queue_private(username):
	if menu_up or queueing:
		return
	#request_new_version.emit(false)
	if not queueing and len(_player.team.characters) == 3:
		queueing = true
		$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = true
		queue_private_match.emit(_player, username)

func queue_ranked():
	if menu_up or queueing:
		return
	#request_new_version.emit(false)
	if not queueing and len(_player.team.characters) == 3:
		queueing = true
		$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = true
		queue_ranked_match.emit(_player)

func accept_private_match(opponent, opponent_team, first, seed, canonical_role: int = 0):
	$UpdateTimer.stop()
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel.visible = false
	print("Accepting private match in char select!")
	match_found.emit()
	queueing = false
	going_first = first
	_seed = seed
	var enemy = Player.load_display_player(opponent)
	
	var new_player_chars = []
	for character in _player.team.characters:
		new_player_chars.append(Character.from_character_name(character.path_name))
	_player.team.characters.clear()
	var counter = 0
	for char in new_player_chars:
		if char.path_name == "toga" and _player.equipped_disguise != "" and _player.equipped_disguise != "toga":
			char.disguise_name = _player.equipped_disguise
		char.portrait_frame = _player.equipped_character_frames[counter]
		char.action_frame = _player.equipped_action_frames[counter]
		char.hat = _player.equipped_hats[counter]
		_apply_mastery_cosmetics(char, _player)
		counter += 1
		_player.recruit_character(char)
	counter = 0
	for char_name in opponent_team:
		if counter == 3:
			break
		var char = Character.from_character_name(char_name)
		if char.path_name == "toga" and len(opponent_team) > 3:
			char.disguise_name = opponent_team[3]
		char.portrait_frame = enemy.equipped_character_frames[counter]
		char.action_frame = enemy.equipped_action_frames[counter]
		char.hat = enemy.equipped_hats[counter]
		_apply_mastery_cosmetics(char, enemy, true)
		counter += 1
		enemy.recruit_character(char, true)
	start_battle.emit(_player, enemy, first, seed, BattleScene.Match.PRIVATE, canonical_role)

func private_click():
	var panel = PrivateMatchSearchPanel.deploy()
	panel.target_confirmed.connect(receive_private_battle_target)
	panel.close_panel.connect(cancel_private_search)
	blotter.add_child(panel)
	blotter.visible=true

func practice_click():
	pass

func make_unlockable_purchase(price, unlock_name):
	_player.contribute_ap(price)
	_player.unlocks.append(unlock_name)
	if "unlock" in unlock_name:
		var split_index = unlock_name.find("_")
		unlock_character_button(unlock_name.substr(0, split_index))
	save_cosmetic_changes.emit(_player)

func shop_button_pressed():
	print("Clicked shop button!")
	play_click_sound()
	var shop_menu = load("res://ui/shop_panel.tscn").instantiate()
	shop_menu.ingest_player(_player)
	shop_menu.make_purchase.connect(make_unlockable_purchase)
	open_menu_panel(shop_menu)
	shop_menu.show_buttons_by_type("gamepanel")


func menu_button_hovered():
	play_sound("soft_click")

func second_option_menu_button_hovered():
	play_sound("soft_click")


func search_button_hovered():
	play_sound("soft_click")



func _on_texture_button_3_mouse_entered():
	play_sound("soft_click")

func play_click_sound():
	play_sound("click")

func cancel_search_hover():
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel/TextureButton.modulate = Color.hex(0xffffff88)
	play_sound("soft_click")



func cancel_search_stop_hover():
	$RowContainer/InfoRowMargin/HBoxContainer/VBoxContainer/HBoxContainer/SearchingMargin/SearchPanel/TextureButton.modulate = Color.WHITE
	


func settings_button_clicked():
	print("Clicked settings button!")
	play_sound("click")
	
	var settings_menu = load("res://ui/settings_menu.tscn").instantiate()
	settings_menu.ingest_player(_player)
	open_menu_panel(settings_menu)

func ladder_button_clicked():
	print("Clicked leaderboard button!")
	play_sound("click")
	var leaderboard_panel = load("res://ui/leaderboard_panel.tscn").instantiate()
	leaderboard_panel.set_char_list(char_list)
	open_menu_panel(leaderboard_panel)
	request_ladder_details.emit(leaderboard_panel)
	

func receive_reconnection_package(package):
	var json = JSON.new()
	var parse_result = json.parse(package)
	if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", package, " at line ", json.get_error_line())
			return
	var reconnection_package = json.get_data()
	var r_enemy = Player.load_display_player(reconnection_package['enemy'])
	var player_characters = reconnection_package['player_characters']
	var enemy_characters = reconnection_package['enemy_characters']
	# Phase 8: reconnection package is snapshot-based. The wire snapshot carries
	# the full authoritative state that start_battle_reconnect will pour into a
	# freshly-initialized passive manager — no seed, no history, no turn timer.
	var r_snapshot = reconnection_package['snapshot']
	var r_match_type = reconnection_package['match_type']
	var r_canonical_role = int(reconnection_package.get("canonical_role", 0))
	var r_timer_remaining = float(reconnection_package.get("current_timer", 120.0))
	var new_player_chars = []
	for path_name in player_characters:
		var new_char = Character.from_character_name(path_name)
		new_player_chars.append(new_char)
	var counter = 0
	for char in new_player_chars:
		lock_character_button(char.path_name)
		char.portrait_frame = _player.equipped_character_frames[counter]
		char.action_frame = _player.equipped_action_frames[counter]
		char.hat = _player.equipped_hats[counter]
		_apply_mastery_cosmetics(char, _player)
		counter += 1
		_player.recruit_character(char)
		select_character.emit()

	counter = 0
	for char_name in enemy_characters:
		var char = Character.from_character_name(char_name)
		char.portrait_frame = r_enemy.equipped_character_frames[counter]
		char.action_frame = r_enemy.equipped_action_frames[counter]
		char.hat = r_enemy.equipped_hats[counter]
		_apply_mastery_cosmetics(char, r_enemy, true)
		counter += 1
		r_enemy.recruit_character(char, true)

	start_battle_reconnect.emit(_player, r_enemy, r_snapshot, r_match_type, r_canonical_role, r_timer_remaining)


func spectate_player(target_username: String):
	spectate_requested.emit(target_username)


func receive_spectate_init_package(package: String):
	var json = JSON.new()
	var parse_result = json.parse(package)
	if parse_result != OK:
		print("[SPECTATE] JSON parse error: ", json.get_error_message())
		return
	var data = json.get_data()
	var p1_display = Player.load_display_player(data["p1"])
	var p2_display = Player.load_display_player(data["p2"])

	var p1_chars = data.get("p1_characters", [])
	var p2_chars = data.get("p2_characters", [])
	var s_snapshot = data.get("snapshot", {})
	var s_match_type = data.get("match_type", 0)
	var s_timer = float(data.get("current_timer", 120.0))

	var counter = 0
	for path_name in p1_chars:
		var char = Character.from_character_name(path_name)
		char.portrait_frame = p1_display.equipped_character_frames[counter]
		char.action_frame = p1_display.equipped_action_frames[counter]
		char.hat = p1_display.equipped_hats[counter]
		_apply_mastery_cosmetics(char, p1_display)
		counter += 1
		p1_display.recruit_character(char)

	counter = 0
	for path_name in p2_chars:
		var char = Character.from_character_name(path_name)
		char.portrait_frame = p2_display.equipped_character_frames[counter]
		char.action_frame = p2_display.equipped_action_frames[counter]
		char.hat = p2_display.equipped_hats[counter]
		_apply_mastery_cosmetics(char, p2_display, true)
		counter += 1
		p2_display.recruit_character(char, true)

	start_battle_spectate.emit(p1_display, p2_display, s_snapshot, s_match_type, s_timer)


func load_replay_file(path: String):
	var log = MatchReplayLog.load_from_file(path)
	if log == null:
		print("[REPLAY] Failed to load replay from ", path)
		return
	_start_replay_from_log(log)


func load_replay_from_string(json_string: String):
	var log = MatchReplayLog.from_json_string(json_string)
	if log == null:
		print("[REPLAY] Failed to parse replay data")
		return
	_start_replay_from_log(log)


func _start_replay_from_log(log: MatchReplayLog):
	var p1 = load("res://components/player_component.tscn").instantiate()
	p1.set_username(log.p1_username)
	p1._name.change_name(log.p1_username)
	p1.rank.set_values(0, 0, 0, 0)
	var p2 = load("res://components/player_component.tscn").instantiate()
	p2.set_username(log.p2_username)
	p2._name.change_name(log.p2_username)
	p2.rank.set_values(0, 0, 0, 0)
	p2.enemy = true

	for path_name in log.p1_characters:
		var char = Character.from_character_name(path_name)
		p1.recruit_character(char)

	for path_name in log.p2_characters:
		var char = Character.from_character_name(path_name)
		p2.recruit_character(char, true)

	start_replay.emit(p1, p2, log)


func receive_player_update(player):
	# Absorb post-match fields (mastery XP, win/loss, rank, AP, etc.) onto the
	# existing _player rather than swapping the reference. The incoming player
	# was rebuilt from disk and has an empty team.characters — replacing the
	# reference wholesale would wipe the team the player just played with and
	# leave character select in a broken state.
	_player.rank.wins = player.rank.wins
	_player.rank.losses = player.rank.losses
	_player.rank.rank = player.rank.rank
	_player.rank.rank_tier = player.rank.rank_tier
	_player.rank.streak = player.rank.streak
	_player.rank._rp = player.rank._rp
	_player.rank._ranked_streak = player.rank._ranked_streak
	if player.rank.rating != null:
		_player.rank.rating = player.rank.rating
	# AP is awarded client-side at match end; the server update may arrive
	# before the cosmetic save that carries the new value, so keep whichever
	# is higher to avoid overwriting a recent gain with stale data.
	if _player.ap == null or (player.ap != null and player.ap > _player.ap):
		_player.ap = player.ap
	_player.character_progress.from_dict(player.character_progress.to_dict())
	_player.unlocks = player.unlocks
	_player.title = player.title
	_player.clan = player.clan
	_player.clan_invitations = player.clan_invitations
	_player.clan_applications = player.clan_applications
	_player.mission_data = player.mission_data
	_player.active_bounties = player.active_bounties
	_player.bounty_rerolls = player.bounty_rerolls
	player_info_panel.assign_player(_player)



func bot_button_pressed():
	if menu_up or queueing:
		return
	#request_new_version.emit(false)
	if not queueing and len(_player.team.characters) == 3:
		var new_player_chars = []
		for character in _player.team.characters:
			new_player_chars.append(Character.from_character_name(character.path_name))
		_player.team.characters.clear()
		var counter = 0
		for char in new_player_chars:
			char.portrait_frame = _player.equipped_character_frames[counter]
			char.action_frame = _player.equipped_action_frames[counter]
			char.hat = _player.equipped_hats[counter]
			_apply_mastery_cosmetics(char, _player)
			counter += 1
			_player.recruit_character(char)

		var enemy = make_random_bot()

		start_battle.emit(_player, enemy, true, randi_range(0, 100000000), BattleScene.Match.BOT, 0)


func _apply_mastery_cosmetics(char, player_source, respect_cosmetics_toggle := false):
	if respect_cosmetics_toggle and not _player.cosmetics_on:
		return
	char.mastery_portrait_on = char.path_name in player_source.equipped_mastery_profiles or char.path_name in player_source.equipped_mastery_skins
	char.mastery_skin_on = char.path_name in player_source.equipped_mastery_skins

func bounties_clicked():
	play_click_sound()
	var bounty_menu = load("res://ui/bounty_panel.tscn").instantiate()
	bounty_menu.assign_player(_player)
	open_menu_panel(bounty_menu)


func bounty_hovered():
	$RowContainer/InfoRowMargin/HBoxContainer/LeftHandColumn/TextureButton.modulate = Color(1.0, 1.0, 1.0, 0.514)


func bounty_hover_stopped():
	$RowContainer/InfoRowMargin/HBoxContainer/LeftHandColumn/TextureButton.modulate = Color(1.0, 1.0, 1.0, 1.0)

func replay_button_clicked():
	if menu_up or queueing:
		return
	play_click_sound()
	var replay_panel = ReplayListPanel.create()
	replay_panel.replay_loaded.connect(load_replay_from_string)
	open_menu_panel(replay_panel)


func replay_clicked():
	replay_button_clicked()


func replay_hovered():
	$RowContainer/InfoRowMargin/HBoxContainer/LeftHandColumn/TextureButton2.modulate = Color.hex(0xffffff80)


func replay_hover_stopped():
	$RowContainer/InfoRowMargin/HBoxContainer/LeftHandColumn/TextureButton2.modulate = Color.WHITE
