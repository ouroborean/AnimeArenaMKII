extends HBoxContainer
class_name ClanPanel

@export var my_clan_tab: PanelContainer
@export var find_clans_tab: PanelContainer
@export var clan_wars_tab: PanelContainer
var player
var member_level = 2
signal attempt_create_clan(clan_name, clan_avatar_url, panel)
signal request_clan_search(clan_string, panel)
signal request_player_search(player_string, panel)
signal send_clan_application(clan_string)
signal send_view_clan_request(clan_string)
signal send_cancel_clan_application(clan_string, player_name)
signal send_player_invitation(clan_string, player_name)
signal send_cancel_player_invitation(clan_string, player_name)
signal request_clan_info(clan, panel)
signal send_clan_offer_accept(clan_name, player_name)
signal refresh_panel(target_tab)
signal send_kick(clan_name, player_name)
signal send_promotion(clan_name, player_name)
signal send_demotion(clan_name, player_name)
signal send_leave(clan_name, player_name)


var tabs = {}

var panels = {}

func receive_send_clan_application(clan):
	print("Panel is sending clan application to " + clan)
	send_clan_application.emit(clan)
	quick_restart()

func receive_send_player_invitation(clan_name, player_name):
	send_player_invitation.emit(clan_name, player_name)
	quick_restart()

func receive_cancel_player_invitation(clan_string, player_name):
	send_cancel_player_invitation.emit(clan_string, player_name)
	quick_restart()

func receive_clan_accept(clan_string, player_name=""):
	if player_name:
		send_clan_offer_accept.emit(clan_string, player_name)
	else:
		send_clan_offer_accept.emit(clan_string, player.username)
	quick_restart()

func quick_restart(target_tab="find_clans"):
	refresh_panel.emit(target_tab)


func receive_view_clan_request(clan):
	print("Panel is requesting to view clan: " + clan)
	request_clan_info.emit(clan, self)

# Called when the node enters the scene tree for the first time.
func _ready():
	tabs = {
		"my_clan": my_clan_tab,
		"find_clans": find_clans_tab,
		"clan_wars": clan_wars_tab
	}
	panels = {
		"my_clan": $PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/MyClanMargin/Control,
		"find_clans": $PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/FindClansMargin/PanelContainer,
		"clan_wars": $PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/ClanWarsMargin
	}

signal close_panel()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_player(_player):
	player = _player
	if player.clan == "Clanless":
		$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/MyClanMargin/Control.show_start_panel()
	$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/MyClanMargin/Control._player = _player
	$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/FindClansMargin/PanelContainer.player = player.username

func _on_texture_button_mouse_entered():
	$MarginContainer/TextureButton.modulate = Color.hex(0xffffff80)
	
func set_tab_active(tab_name):
	var button = tabs[tab_name]
	var panel = button.get("theme_override_styles/panel")
	
	for button_name in tabs:
		var tab = tabs[button_name]
		var tab_panel = tab.get("theme_override_styles/panel")
		panels[button_name].hide()
		tab_panel.border_width_bottom = 1.0
	panel.border_width_bottom = 0.0
	panels[tab_name].show()
	

func _on_texture_button_mouse_exited():
	$MarginContainer/TextureButton.modulate = Color.WHITE

func on_clan_info_received(clan_info, server):
	server.clan_info_received.disconnect(on_clan_info_received)
	var clan = Clan.load_clan(clan_info["clan_info"])
	accept_clan_info(clan)

func _on_texture_button_pressed():
	close_panel.emit()

func accept_clan_info(clan):
	panels["my_clan"].member_level = 2
	if clan.clan_name == player.clan:
		for i in range(3):
			if player.username in clan.members[i]:
				print("Accepting clan member with rank of " + str(i))
				member_level = i
				panels["my_clan"].member_level = i
	if member_level == 2:
		panels["find_clans"].veil_panel()
	set_tab_active("my_clan")
	panels["my_clan"].open_my_clan(clan)


func clan_wars_button_click(event):
	return
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		print("Clicked on Clan Wars button!")
		set_tab_active("clan_wars")


func find_clans_button_click(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		print("Clicked on Find Clans button!")
		set_tab_active("find_clans")

func clan_management_mode():
	print("Swapping to clan management mode!")
	print(player.clan)
	$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/FindClansMargin/PanelContainer.swap_to_clan_management(player.clan)

func receive_kick(clan_name, player_name):
	send_kick.emit(clan_name, player_name)
	quick_restart("my_clan")
	

func receive_promotion(clan_name, player_name):
	send_promotion.emit(clan_name, player_name)
	quick_restart("my_clan")
	

func receive_demotion(clan_name, player_name):
	send_demotion.emit(clan_name, player_name)
	quick_restart("my_clan")
	

func receive_leave(clan_name, player_name):
	send_leave.emit(clan_name, player_name)
	print("Clan panel sending leave")
	quick_restart("my_clan")
	

func receive_clan_application_invite_info(info, server):
	server.send_clan_application_invite_info.disconnect(receive_clan_application_invite_info)
	print(info)
	$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/FindClansMargin/PanelContainer.populate_invite_application_panel(info, false)
	

func receive_player_application_invite_info(info, server):
	server.send_player_application_invite_info.disconnect(receive_player_application_invite_info)
	print(info)
	$PanelContainer/MarginContainer/MarginContainer/MarginContainer2/VBoxContainer/PanelContainer/FindClansMargin/PanelContainer.populate_invite_application_panel(info)

func my_clan_button_click(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		print("Clicked on My Clan button!")
		if player.clan != "Clanless":
			request_clan_info.emit(player.clan, self)
		set_tab_active("my_clan")

func my_clan_panel_create_clicked(clan_name, clan_avatar_url):
	attempt_create_clan.emit(clan_name, clan_avatar_url, self)

func search_panel_search_requested(clan_string, panel):
	request_clan_search.emit(clan_string, panel)

func search_panel_player_search_requested(player_string, panel):
	request_player_search.emit(player_string, panel)

func receive_clan_creation_response(data):
	print("Received clan creation response in clan panel!")
	panels["my_clan"].receive_clan_creation_response(data)


func receive_cancel_clan_application(clan_name, player_name=""):
	var _player
	if player_name:
		_player = player_name
	else:
		_player = player.username
	print("Sending a cancel clan application signal!")
	send_cancel_clan_application.emit(clan_name, _player)
	quick_restart()
