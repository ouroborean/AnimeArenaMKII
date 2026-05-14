extends PanelContainer

@export var text_edit: TextEdit

var mode = "find_clans"
var clan = ""
var player = ""
signal request_clan_info_search(clan_string, panel)
signal request_player_info_search(player_string, panel)
signal send_clan_application(clan_string)
signal send_view_clan_request(clan_string)
signal send_cancel_clan_application(clan_name)
signal send_clan_invitation(clan_string, player_string)
signal accept_clan_offer(clan_name, player_name)
signal deny_clan_offer(clan_name, player_name)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func swap_to_clan_management(clan_name):
	
	mode = "find_members"
	clan = clan_name
	print("Setting clan name to " + clan_name)
	print("Clan name is now " + clan)
	$MarginContainer/VBoxContainer/MarginContainer/Label.text = "Find Members"
	$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit.placeholder_text = "  Search for players..."

func _on_text_edit_text_changed():
	if not $MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit/Timer.is_stopped():
		$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit/Timer.stop()
	if $MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit.text.strip_edges() == "":
		return
	$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit/Timer.start()

func player_search_info_received(player_search_info, server):
	print("Received player_search_info: " + str(player_search_info))
	server.clan_search_info_received.disconnect(player_search_info_received)
	for player in player_search_info:
		var row = load("res://ui/clan_search_player_info_row.tscn").instantiate()
		$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/VBoxContainer.add_child(row)
		row.send_clan_invitation.connect(receive_send_clan_invitation)
		row.ingest_details(player)

func receive_clan_search_info(clan_search_info, server):
	print("Received clan search info: " + str(clan_search_info))
	server.clan_search_info_received.disconnect(receive_clan_search_info)
	for clan in clan_search_info:
		var row = load("res://ui/clan_search_info_row.tscn").instantiate()
		$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/VBoxContainer.add_child(row)
		row.send_clan_application.connect(receive_send_clan_application)
		row.send_view_clan_request.connect(receive_view_clan_request)
		row.ingest_details(clan)

func veil_panel():
	$Panel.show()

func receive_send_clan_invitation(player):
	send_clan_invitation.emit(clan, player)

func receive_send_clan_application(clan):
	send_clan_application.emit(clan)

func receive_view_clan_request(clan):
	send_view_clan_request.emit(clan)

func receive_clan_offer_decline(clan_name="", player_name=""):
	var _clan
	var _player
	if player_name:
		_player = player_name
	else:
		_player = player
	if clan_name:
		_clan = clan_name
	else:
		_clan = clan
	print("Denying clan offer between " + _clan + " and " + _player)
	deny_clan_offer.emit(_clan, _player)

func receive_clan_offer_accept(clan_name="", player_name = ""):
	var _clan
	var _player
	if player_name:
		_player = player_name
	else:
		_player = player
	if clan_name:
		_clan = clan_name
	else:
		_clan = clan
	accept_clan_offer.emit(_clan, _player)

func populate_invite_application_panel(info, player_search=true):
	for child in $MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.get_children():
		child.queue_free()
	if player_search:
		for invitation in info["invitations"]:
			var row = load("res://ui/clan_search_playerside_invitation_row.tscn").instantiate()
			row.accept_clan_invitation.connect(receive_clan_offer_accept)
			row.decline_clan_invitation.connect(receive_clan_offer_decline)
			$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.add_child(row)
			
			row.ingest_details(invitation)
		for application in info["applications"]:
			var row = load("res://ui/clan_search_application_row.tscn").instantiate()
			row.send_view_clan_request.connect(receive_view_clan_request)
			row.cancel_clan_application.connect(receive_cancel_clan_application)
			$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.add_child(row)
			row.ingest_details(application)
	else:
		for invitation in info["invitations"]:
			var row = load("res://ui/clan_search_invitation_row.tscn").instantiate()
			row.cancel_player_invitation.connect(receive_clan_offer_decline)
			$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.add_child(row)
			row.ingest_details(invitation)
		for application in info["applications"]:
			var row = load("res://ui/clan_search_clanside_application_row.tscn").instantiate()
			row.accept_player_application.connect(receive_clan_offer_accept)
			row.deny_player_application.connect(receive_clan_offer_decline)
			$MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.add_child(row)
			row.ingest_details(application)

func receive_cancel_clan_application(clan_name):
	send_cancel_clan_application.emit(clan_name)

func _on_timer_timeout():
	#TODO: Send clan search info
	for child in $MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/ScrollContainer/MarginContainer/VBoxContainer.get_children():
		child.queue_free()
	if mode == "find_clans":
		request_clan_info_search.emit($MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit.text.strip_edges(), self)
	else:
		request_player_info_search.emit($MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/TextEdit.text.strip_edges(), self)
