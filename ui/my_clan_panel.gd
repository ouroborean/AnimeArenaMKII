extends PanelContainer


@export var clan_avatar: TextureRect
@export var clan_name_label: Label
@export var clan_exp_bar: ProgressBar

@export var played_char1: TextureRect
@export var played_char2: TextureRect
@export var played_char3: TextureRect

@export var member_label: Label
@export var wins_label: Label
@export var losses_label: Label
@export var rank_label: Label

@export var clan_creation_name_label: Label
@export var clan_creation_avatar: TextureRect
@export var clan_creation_avatar_container: PanelContainer

@export var member_list_container: VBoxContainer
@export var war_info_container: VBoxContainer
@export var award_info_container: HBoxContainer

@export var clan_creation_name_textbox: TextEdit
@export var clan_creation_url_textbox: TextEdit

var waiting_for_avatar = true
var member_level = 2
var _clan
var _player
signal create_clan_clicked(clan_name, clan_url)

signal send_kick(clan_name, player_name)
signal send_promotion(clan_name, player_name)
signal send_demotion(clan_name, player_name)
signal send_leave(clan_name, player_name)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



func ingest_clan_details(data):
	#Clan details will have the following shape:
	#"clan_info" (Dict of clan info for populating actual clan detail panel)
	#"clan_lockout" (timestamp of the last time the user deleted their own clan)
	if data["clan_info"]:
		#Do clan panel population stuff
		return
	if data["clan_lockout"] != -1:
		#Do "no clan starting stuff"
		return
	#Do Searching for clan stuff
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func show_start_panel():
	$StartClanPanel.show()

func open_my_clan(clan):
	_clan = clan
	$ClanPanel.show()
	var url = clan.banner_url
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", clan_display_banner_fetch_completed)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)
	
	
	clan_name_label.text = clan.clan_name
	member_label.text = str(int(clan.member_count()))
	wins_label.text = str(int(clan.wins))
	losses_label.text = str(int(clan.losses))
	rank_label.text = str(clan.rank)
	#TODO: member list stuff
	var leader_label = $ClanPanel/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/Label
	var officer_label = $ClanPanel/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/Label2
	var member_label = $ClanPanel/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/Label3
	var list_box = $ClanPanel/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer
	list_box.remove_child(leader_label)
	list_box.remove_child(officer_label)
	list_box.remove_child(member_label)
	for child in list_box.get_children():
		child.queue_free()
	list_box.add_child(leader_label)
	for member in clan.member_info[0]:
		var row = load("res://ui/clan_member_row.tscn").instantiate()
		list_box.add_child(row)
		row.ingest_details(member, 0, _player.username, member_level)
		row.send_kick.connect(receive_kick)
		row.send_promotion.connect(receive_promotion)
		row.send_demotion.connect(receive_demotion)
		row.send_leave.connect(receive_leave)
	
	list_box.add_child(officer_label)
	for member in clan.member_info[1]:
		var row = load("res://ui/clan_member_row.tscn").instantiate()
		list_box.add_child(row)
		row.ingest_details(member, 1, _player.username, member_level)
		row.send_kick.connect(receive_kick)
		row.send_promotion.connect(receive_promotion)
		row.send_demotion.connect(receive_demotion)
		row.send_leave.connect(receive_leave)
	
	list_box.add_child(member_label)
	for member in clan.member_info[2]:
		var row = load("res://ui/clan_member_row.tscn").instantiate()
		list_box.add_child(row)
		row.ingest_details(member, 2, _player.username, member_level)
		row.send_kick.connect(receive_kick)
		row.send_promotion.connect(receive_promotion)
		row.send_demotion.connect(receive_demotion)
		row.send_leave.connect(receive_leave)
	get_level_from_wins(clan.wins)
	
	
	#TODO: War info stuff
	#TODO: awards and most-used characters
	
	$ClanPanel.show()
	$StartClanPanel.hide()

func get_level_from_wins(wins):
	var level_requirement = 10
	var level = 1
	while true:
		if wins >= level_requirement:
			level += 1
			wins -= level_requirement
			level_requirement = int(level_requirement * 1.8)
		else:
			clan_exp_bar.max_value = level_requirement
			clan_exp_bar.value = wins
			$ClanPanel/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer/MarginContainer2/ProgressBar/Label.text = str(int(level))
			break


func receive_kick(player_name):
	send_kick.emit(_clan.clan_name, player_name)

func receive_promotion(player_name):
	send_promotion.emit(_clan.clan_name, player_name)

func receive_demotion(player_name):
	send_demotion.emit(_clan.clan_name, player_name)

func receive_leave(player_name):
	print("My clan clicking leave")
	send_leave.emit(_clan.clan_name, player_name)


func _on_clan_name_text_changed():
	clan_creation_name_label.text = clan_creation_name_textbox.text.strip_edges()
	if entries_valid():
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.WHITE
	else:
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.DIM_GRAY


func _on_clan_avatar_text_changed():
	if not $AvatarPreviewTimer.is_stopped():
		$AvatarPreviewTimer.stop()
	waiting_for_avatar = true
	$AvatarPreviewTimer.start()
	$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.DIM_GRAY


func _on_avatar_preview_timer_timeout():
	if clan_creation_url_textbox.text.strip_edges() != "":
		print("Avatar preview timed out with something to attempt!")
		var url = clan_creation_url_textbox.text.strip_edges()
		var http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.connect("request_completed", banner_fetch_completed)
		
		# Perform the HTTP request. The URL below returns a PNG image as of writing.
		var error = http_request.request(url)

func clan_display_banner_fetch_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		clan_avatar.texture = texture

func banner_fetch_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		clan_creation_avatar.texture = texture
		waiting_for_avatar = false


func _on_panel_container_mouse_entered():
	if entries_valid():
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.hex(0xffffff80)


func _on_panel_container_mouse_exited():
	if entries_valid():
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.WHITE
	else:
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer/PanelContainer.modulate = Color.DIM_GRAY

func entries_valid():
	return clan_creation_name_textbox.text.strip_edges() != "" and clan_creation_url_textbox.text.strip_edges() != "" and not waiting_for_avatar

func _on_panel_container_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Clicked create clan button!")
		if not entries_valid():
			return
		print("Text edits had valid entries!")
		create_clan_clicked.emit(clan_creation_name_textbox.text.strip_edges(), clan_creation_url_textbox.text.strip_edges())

func receive_clan_creation_response(data):
	if not data['success']:
		$StartClanPanel/MarginContainer/VBoxContainer/MarginContainer/Label2.modulate = Color.WHITE
	else:
		var clan = Clan.load_clan(data['clan_data'])
		open_my_clan(clan)
