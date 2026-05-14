extends Control

var login_scene
var current_scene
@export var server: ServerConnection
@export var char_select_scene: CharSelectScene
@export var battle_scene: BattleScene

var login_clicked = false
var register_clicked = false
var thread
var mutex = Mutex.new()
var semaphore = Semaphore.new()
var _player
var auto_login = false
var loading_characters = false
var waiting_to_login = false
var loading_thread_finished = false
var _reconnect_overlay: ColorRect = null
signal request_reload()

func load_texture(player):
	# A freshly deserialized Player always starts with the default
	# avatar_texture. On reconnect/relogin the HTTP refetch below is skipped,
	# so carry over the previously-fetched texture when the URL is unchanged
	# to avoid flashing the default avatar over the real one.
	if _player != null and player.avatar_url != "" and player.avatar_url == _player.avatar_url:
		player.avatar_texture = _player.avatar_texture
	_player = player
	if loading_thread_finished:
		# If the player is in a bot match, don't pull them out — bot matches
		# are client-side and can continue after a reconnection.
		if current_scene == battle_scene and battle_scene.match_type == BattleScene.Match.BOT:
			return
		# Characters are already loaded from the first login. Re-enter
		# char_select properly so match_waiting is checked and the player
		# object is refreshed.
		open_char_select()
		return
	if _player.avatar_url == "":
		start_character_loading()
	else:
		var http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.connect("request_completed", avatar_fetch_completed)
		var error = http_request.request(player.avatar_url)

func avatar_fetch_completed(result, response_code, headers, body):
	_player.avatar_fetch_completed(result, response_code, headers, body)
	start_character_loading()

func focus_username():
	$PanelContainer/MarginContainer/VBoxContainer/UsernameBox.grab_focus()



func start_character_loading():
	_player.set_username(_player.username)
	$PanelContainer.visible = false
	show_loading_blotter()
	loading_characters = true
	thread.start(char_select_scene.initialize_characters.bind(_player))

func open_char_select():
	$TouchScreenButton.visible = false
	$TouchScreenButton2.visible = false
	loading_characters = false
	# If the player was in a battle that ended while disconnected, clean it up.
	if current_scene == battle_scene:
		battle_scene.hide_scene()
		battle_scene.reset_scene()
		DisplayServer.window_set_size(Vector2i(890, 600))
	# Ensure the NameComponent is synced with the username field so the UI
	# never shows the default "Sample Name".
	_player.set_username(_player.username)
	var has_match = server.match_waiting
	char_select_scene.match_waiting = has_match
	server.match_waiting = false
	char_select_scene.assign_player(_player)
	char_select_scene.show_scene()
	$Control.visible = false
	$TextureRect.visible = false
	$UpdateBlotter.visible = false
	current_scene = char_select_scene
	loading_thread_finished = true
	$PanelContainer2.visible = false
	$GridContainer.visible = false
	# Don't hide the overlay if match_waiting — the reconnection flow will load
	# the battle scene, and the overlay should stay up until then.
	if not has_match:
		_hide_reconnect_overlay()

func return_to_char_select(_player):
	battle_scene.hide_scene()
	battle_scene.reset_scene()
	DisplayServer.window_set_size(Vector2i(890, 600))
	char_select_scene.menu_up = false
	char_select_scene.reset_scene(_player)
	char_select_scene.show_scene()
	current_scene = char_select_scene
	#server.check_latest_client_version(false)

func skip_loading():
	char_select_scene.show_scene()
	$Control.visible = false
	$TextureRect.visible = false
	$UpdateBlotter.visible = false
	$PanelContainer.visible = false
	$PanelContainer2.visible = false
	current_scene = char_select_scene

func _threaded_char_load():
	while true:
		semaphore.wait()


func dc_to_login():
	# During a tab-away reconnection the overlay is already up and
	# server_connection handles re-authentication automatically. Don't tear
	# down the current scene or show the login UI.
	if server._is_reconnecting:
		return
	battle_scene.hide_scene()
	battle_scene.reset_scene()
	char_select_scene.hide_scene()
	$PanelContainer.visible = true
	$TextureRect.visible = true
	login_clicked = false
	$PanelContainer2.visible = true

func add_peer_label(peer_id):
	var label = Label.new()
	label.text = str(peer_id)
	$Control/VBoxContainer.add_child(label)

func update_peer_label_storage():
	for child in $Control/VBoxContainer.get_children():
		child.queue_free()
	for key in server.connected_peers.keys():
		if not server.connected_peers[key] is int:
			add_peer_label(key)

func login_click(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if not login_clicked:
			login_clicked = true
			if auto_login:
				if not FileAccess.file_exists("res://login.dat"):
					var login_file = FileAccess.open("res://login.dat", FileAccess.WRITE)
					login_file.store_line($PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text)
					login_file.store_line($PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text)
			server.attempt_login($PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text, $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text)

func register_click(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if not register_clicked:
			if $PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text.lstrip(" ").rstrip(" ") != "" and $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text.lstrip(" ").rstrip(" ") != "":
				register_clicked = true
				server.attempt_register($PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text, $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text)
			else:
				set_login_message("Please enter your desired username and password, then click Register.")

func set_login_message(message):
	$PanelContainer/MarginContainer/VBoxContainer/Label.text = message
	login_clicked = false
	register_clicked = false

func start_server():
	$Control.visible = false
	$PanelContainer.visible = false
	$TextureRect.visible = false

func start_battle(player, enemy, first, seed, match_type, canonical_role: int = 0):
	print("Starting battle!")
	char_select_scene.hide_scene()
	DisplayServer.window_set_size(Vector2i(890, 600))
	battle_scene.visible = true
	battle_scene.show_scene()
	current_scene = battle_scene
	battle_scene.start_battle_scene(player, enemy, first, seed, match_type, canonical_role)

func start_battle_with_reconnect(player, enemy, snapshot, match_type, canonical_role: int = 0, timer_remaining: float = 120.0):
	print("Reconnecting to battle!")
	char_select_scene.hide_scene()
	DisplayServer.window_set_size(Vector2i(890, 600))
	battle_scene.visible = true
	battle_scene.show_scene()
	current_scene = battle_scene
	battle_scene.start_battle_scene_reconnect(player, enemy, snapshot, match_type, canonical_role, timer_remaining)
	server._is_reconnecting = false
	_hide_reconnect_overlay()

func start_battle_spectate(p1_player, p2_player, snapshot, match_type, timer_remaining: float = 120.0):
	print("Spectating battle!")
	char_select_scene.hide_scene()
	DisplayServer.window_set_size(Vector2i(890, 600))
	battle_scene.visible = true
	battle_scene.show_scene()
	current_scene = battle_scene
	battle_scene.start_battle_scene_spectate(p1_player, p2_player, snapshot, match_type, timer_remaining)

func start_replay(p1_player, p2_player, replay_log: MatchReplayLog):
	print("Starting replay!")
	char_select_scene.hide_scene()
	DisplayServer.window_set_size(Vector2i(890, 600))
	battle_scene.visible = true
	battle_scene.show_scene()
	current_scene = battle_scene
	battle_scene.start_replay(p1_player, p2_player, replay_log)

# ---------------------------------------------------------------------------
# RECONNECTION OVERLAY
# ---------------------------------------------------------------------------

func _show_reconnect_overlay():
	if _reconnect_overlay != null:
		return
	_reconnect_overlay = ColorRect.new()
	_reconnect_overlay.color = Color(0, 0, 0, 0.65)
	_reconnect_overlay.z_index = 100
	_reconnect_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_reconnect_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var label = Label.new()
	label.text = "Connection lost. Reconnecting..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.add_theme_font_size_override("font_size", 22)
	_reconnect_overlay.add_child(label)
	add_child(_reconnect_overlay)


func _hide_reconnect_overlay():
	if _reconnect_overlay == null:
		return
	_reconnect_overlay.queue_free()
	_reconnect_overlay = null


# Called when the server confirms the session is valid but there is no active
# match (or after a successful auto-login with no match to rejoin). If the
# client was in a battle that ended while disconnected, clean it up and return
# to char select.
func _on_connection_lost_resolved():
	_hide_reconnect_overlay()
	if current_scene == battle_scene:
		# Bot matches run client-side with no server match. Let the player
		# resume where they left off instead of tearing down the battle.
		if battle_scene.match_type == BattleScene.Match.BOT:
			return
		# The match ended while disconnected. Tear down the battle scene and
		# return to char select. Don't call assign_player here — the server
		# already sent a player update via receive_player_update which updates
		# the existing UI in-place. If this was the auto-login path,
		# open_char_select will run right after and handle assign_player.
		battle_scene.hide_scene()
		battle_scene.reset_scene()
		DisplayServer.window_set_size(Vector2i(890, 600))
		char_select_scene.menu_up = false
		char_select_scene.show_scene()
		current_scene = char_select_scene


# Called when the server validates the session and the player was in a match.
# Reconstructs characters and loads the battle scene from the snapshot,
# bypassing char_select entirely.
func handle_session_reconnect(package_json: String):
	var json = JSON.new()
	var parse_result = json.parse(package_json)
	if parse_result != OK:
		push_warning("[RECONNECT] Failed to parse reconnection package")
		_hide_reconnect_overlay()
		return
	var pkg = json.get_data()
	var r_enemy = Player.load_display_player(pkg["enemy"])
	var r_snapshot = pkg["snapshot"]
	var r_match_type = pkg["match_type"]
	var r_canonical_role = int(pkg.get("canonical_role", 0))
	var r_timer_remaining = float(pkg.get("current_timer", 120.0))

	# Rebuild player team from the package character names + local cosmetics
	_player.team.characters.clear()
	_player.equipped_characters.clear()
	var counter = 0
	for path_name in pkg["player_characters"]:
		var character = Character.from_character_name(path_name)
		character.portrait_frame = _player.equipped_character_frames[counter]
		character.action_frame = _player.equipped_action_frames[counter]
		character.hat = _player.equipped_hats[counter]
		character.mastery_portrait_on = path_name in _player.equipped_mastery_profiles or path_name in _player.equipped_mastery_skins
		character.mastery_skin_on = path_name in _player.equipped_mastery_skins
		counter += 1
		_player.recruit_character(character)

	counter = 0
	for char_name in pkg["enemy_characters"]:
		var character = Character.from_character_name(char_name)
		character.portrait_frame = r_enemy.equipped_character_frames[counter]
		character.action_frame = r_enemy.equipped_action_frames[counter]
		character.hat = r_enemy.equipped_hats[counter]
		if _player.cosmetics_on:
			character.mastery_portrait_on = char_name in r_enemy.equipped_mastery_profiles or char_name in r_enemy.equipped_mastery_skins
			character.mastery_skin_on = char_name in r_enemy.equipped_mastery_skins
		counter += 1
		r_enemy.recruit_character(character, true)

	start_battle_with_reconnect(_player, r_enemy, r_snapshot, r_match_type, r_canonical_role, r_timer_remaining)


func receive_update_notification():
	print("Showing update blotter?")
	$UpdateBlotter.visible = true
	$UpdateBlotter/MarginContainer/VBoxContainer/ProgressBar.visible = false
	$UpdateBlotter/MarginContainer/VBoxContainer/LoadingLabel.visible = false
	$UpdateBlotter/MarginContainer/VBoxContainer/UpdateLabel.visible = true
	$UpdateBlotter/MarginContainer/VBoxContainer/UpdateLabel.text = "Downloading patches. Please do not close Anime-Arena."
	
	
func receive_update_completion():
	$UpdateBlotter/MarginContainer/VBoxContainer/UpdateLabel.text = "Updates downloaded. Please re-launch Anime-Arena to continue."

func show_loading_blotter():
	$UpdateBlotter/MarginContainer/VBoxContainer/ProgressBar.visible = true
	$UpdateBlotter/MarginContainer/VBoxContainer/UpdateLabel.visible = false
	$UpdateBlotter/MarginContainer/VBoxContainer/LoadingLabel.visible = true
	$UpdateBlotter.visible = true
	$UpdateBlotter/MarginContainer/VBoxContainer/ProgressBar.max_value = len(char_select_scene.char_name_list)

func update_loading_blotter():
	$UpdateBlotter/MarginContainer/VBoxContainer/ProgressBar.value += 0.11

func auto_login_check():
	if FileAccess.file_exists("res://login.dat"):
		print("Found login data")
		var login_file = FileAccess.open("res://login.dat", FileAccess.READ)
		var creds = []
		while not login_file.eof_reached():
			var line = login_file.get_line()
			if not line == "":
				creds.append(line)
		server.attempt_login(creds[0], creds[1])

# Called when the node enters the scene tree for the first time.
func _ready():
	thread = Thread.new()
	
	if DisplayServer.get_name() != "headless":
		
		print(server.multiplayer_peer.get_connection_status())
		print("Game starting connection!")
		server.multiplayer_peer.create_client(server.TARGET_IP)
		print("Created client")
		multiplayer.multiplayer_peer = server.multiplayer_peer
		print("Set multiplayer peer")
		print(server.multiplayer_peer.get_connection_status())
		await get_tree().create_timer(1.0).timeout
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -20)
	print("Game readied")
	$PanelContainer/MarginContainer/VBoxContainer/UsernameBox.connect("focus_entered", username_text_entry)
	$PanelContainer/MarginContainer/VBoxContainer/PasswordBox.connect("focus_entered", password_text_entry)

func username_text_entry():
	return
	if not (OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return
	var text = JavaScriptBridge.eval(
			"prompt('%s', '%s');" % ["Please enter username:", $PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text], 
			true
			)
	if text == "<null>":
		text = ""
	$PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text = text
	release_focus()

func password_text_entry():
	return
	if not (OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return
	var text = JavaScriptBridge.eval(
			"prompt('%s', '%s');" % ["Please enter password:", $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text], 
			true
			)
	if text == "<null>":
		text = ""
	$PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text = text
	release_focus()

func version_check():
	pass

func attempt_server_connect():
	server.multiplayer_peer.create_client(server.TARGET_IP)
	multiplayer.multiplayer_peer = server.multiplayer_peer

func _exit_tree():
	thread.wait_to_finish()

func reload():
	request_reload.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if loading_characters:
		update_loading_blotter()


func start_connection():
	#attempt_server_connect()
	pass


func _on_check_box_toggled(button_pressed):
	auto_login = not auto_login


func update_player(player_data):
	pass

func attempt_server_connect_loop():
	var disconnection_panel = load("res://ui/disconnection_panel.tscn").instantiate()
	add_child(disconnection_panel)


func mobile_touch_username():
	pass


func mobile_touch_password():
	pass


func open_keyboard(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		$GridContainer.visible = true
		$PanelContainer2.visible = false


func _on_grid_container_send_letter(letter):
	if $PanelContainer/MarginContainer/VBoxContainer/UsernameBox.has_focus():
		if letter == "backspace":
			$PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text = $PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text.left(-1)
		else:
			$PanelContainer/MarginContainer/VBoxContainer/UsernameBox.text += letter
	elif $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.has_focus():
		if letter == "backspace":
			$PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text = $PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text.left(-1)
		else:
			$PanelContainer/MarginContainer/VBoxContainer/PasswordBox.text += letter
	
