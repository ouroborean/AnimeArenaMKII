extends Node


var TARGET_IP = "wss://server.animaslashanimearenaserver.org"
#"35.208.245.67"
var TARGET_PORT = 5695
var connected_peers = {}
var player_connection_state = {}
var multiplayer_peer = WebSocketMultiplayerPeer.new()
var delta_timer = 30.0
var ranked_queue = {
	Rank.Type.IRON: {},
	Rank.Type.BRONZE: {},
	Rank.Type.SILVER: {},
	Rank.Type.GOLD: {},
	Rank.Type.PLATINUM: {},
	Rank.Type.DIAMOND: {},
	Rank.Type.MASTER: {},
	Rank.Type.GRANDMASTER: {},
}
var match_waiting = false
enum Connection {
	OFFLINE,
	ONLINE,
	DISCONNECTED,
	IN_GAME
}
var ladder = {}
var clan_ladder = {}
var private_queue = {}
var private_matches: Array[Match]
var queued_players = {}
var player_check = {}
var quick_matches: Array[Match]
var ranked_matches: Array[Match]
var _player
var _version = "1.6.0"
var needed_versions = []
var missions
var clans = {}
var players = {}
var attempting_reconnect = false
@export var is_server = false
@export var bucket_handler: BucketHandler
@export var heartbeat_timer: Timer
@export var ladder_timer: Timer
signal server_start()
signal char_select(player)
signal quick_match_received(opponent, opponent_team, first, seed)
signal ranked_match_received(opponent, opponent_team, first, seed)
signal private_match_received(opponent, opponent_team, first, seed)
signal opponent_ban_received(character)
signal opponent_pick_received(character)
signal turn_package_received(package)
signal player_timeout()
signal opponent_timeout()
signal opponent_surrendered()
signal player_connected(peer_id)
signal set_login_message(message)
signal return_texture(texture)
signal prompt_restart()
signal inform_updating()
signal connection_ready()
signal connection_complete()
signal end_queue()
signal request_game_refresh()
signal character_bucket_info_broadcast(max, info_sets)
signal bucket_update(path_name, amount, max)
signal reconnection_package_received(package)
signal ladder_info_received(ladder_info)
signal clan_creation_response_received(data)
signal clan_info_received(info, connection)
signal clan_search_info_received(clan_info, connection)
signal send_player_application_invite_info(info, connection)
signal send_clan_application_invite_info(info, connection)
signal player_search_info_received(player_info, connection)
signal player_update_received(player)

var game_loaded = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if DisplayServer.get_name() != "headless":
		connection_ready.emit()
		heartbeat_timer.start()
	else:
		
		initialize_players()
		initialize_clans()
		missions = Mission.all_missions()
		for rank in ranked_queue:
			
			for i in range(5):
				ranked_queue[rank][i + 1] = []

func initialize_players():
	for file in DirAccess.get_files_at("ausers"):
		var player_name = file.get_slice(".dat", 0)
		players[player_name] = Player.load_player(load_player(player_name))


func initialize_clans():
	for file in DirAccess.get_files_at("clans"):
		var clan_name = file.get_slice(".dat", 0)
		clans[clan_name] = Clan.load_clan(load_clan(clan_name))
	

@rpc
func add_connected_info(peer_id):
	if attempting_reconnect:
		attempting_reconnect = false
		if _player == null:
			pass
		else:
			rpc_id(1, "notify_reconnecting_player", multiplayer.get_unique_id(), _player.username)
	
	multiplayer.server_disconnected.connect(heartbeat_check)
	notify_connection_complete()

@rpc("any_peer")
func notify_reconnecting_player(peer_id, username):
	connected_peers[peer_id] = players[username]
	player_connection_state[username] = Connection.ONLINE

func notify_connection_complete():
	connection_complete.emit()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	delta_timer -= delta
	if delta_timer <= 0.0:
		_on_ladder_timer_timeout()
		delta_timer = 30.0

func heartbeat_check():
	print("Heartbeat check!")
	if multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		print("Disconnected on a heartbeat!")
		
		attempting_reconnect = true
		multiplayer_peer = WebSocketMultiplayerPeer.new()
		multiplayer_peer.create_client(TARGET_IP)
		print("Recreated client")
		multiplayer.multiplayer_peer = multiplayer_peer
		print("Reset multiplayer peer")
		await get_tree().create_timer(1.0).timeout
		
	else:
		rpc_id(1, "receive_heartbeat", multiplayer.get_unique_id())

@rpc("any_peer")
func receive_heartbeat(peer_id):
	rpc_id(peer_id, "receive_heartbeat_response")

@rpc
func receive_heartbeat_response():
	print("Received Heartbeat Response!")

func start_server(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		actually_start_server()

func load_player(username, str=false):
	var player_save = FileAccess.open("ausers/" + username + ".dat", FileAccess.READ)
	var json = JSON.new()
	var json_string = player_save.get_line()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			return
	var player_data = json.get_data()
	if not str:
		return player_data
	else:
		return json_string

func load_clan(clan_name, str=false):
	var clan_save = FileAccess.open("clans/" + clan_name + ".dat", FileAccess.READ)
	var json = JSON.new()
	var json_string = clan_save.get_line()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			return
	var clan_data = json.get_data()
	if not str:
		return clan_data
	else:
		return json_string

func request_character_buckets(universe):
	rpc_id(1, "receive_character_bucket_request", multiplayer.get_unique_id(), universe)

@rpc("any_peer")
func receive_character_bucket_request(peer_id, universe):
	print("Received character bucket request from " + connected_peers[peer_id].username +"!")
	var handler_response = bucket_handler.receive_character_buckets_request(universe)
	var max = handler_response[0]
	var info_sets = handler_response[1]
	rpc_id(peer_id, "receive_character_buckets", max, info_sets)
	
@rpc
func receive_character_buckets(max, bucket_info_sets):
	character_bucket_info_broadcast.emit(max, bucket_info_sets)

func send_player_contribution(bucket_path_name, amount):
	rpc_id(1, "receive_player_contribution", multiplayer.get_unique_id(), bucket_path_name, amount)

@rpc("any_peer")
func receive_player_contribution(peer_id, bucket_path_name, amount):
	print("Server received news of " + connected_peers[peer_id].username +"'s contribution!")
	print("Contributed " + str(amount) + " to " + bucket_path_name)
	var update_announcement = bucket_handler.process_bucket_update(bucket_path_name, amount)
	rpc("update_buckets", update_announcement[0], update_announcement[1], update_announcement[2])

@rpc
func update_buckets(bucket_path_name, amount, current_max):
	bucket_handler.receive_update_from_server(bucket_path_name, amount, current_max)

func save_player(player, pass_hash=""):
	var player_save = FileAccess.open("ausers/" + player.username + ".dat", FileAccess.WRITE)
	var player_data = player.save()
	if pass_hash != "":
		player_data['pass_hash'] = pass_hash
	var json_string = JSON.stringify(player_data)
	player_save.store_line(json_string)
	player_save.close()

func save_clan(clan):
	var clan_save = FileAccess.open("clans/" + clan.clan_name + ".dat", FileAccess.WRITE)
	var clan_data = clan.save()
	var json_string = JSON.stringify(clan_data)
	clan_save.store_line(json_string)

func resave_player(player):
	var player_data = load_player(player.username)
	var pass_hash_store = player_data['pass_hash']
	save_player(player, pass_hash_store)

func actually_start_server():
	print("Starting server!")
	multiplayer_peer.create_server(TARGET_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = true
	multiplayer.peer_connected.connect(
	func(new_peer_id):
		await get_tree().create_timer(0.1).timeout
		player_connected.emit(new_peer_id)
		rpc_id(new_peer_id, "add_connected_info", new_peer_id)
	)
	multiplayer.peer_disconnected.connect(handle_disconnect)
	server_start.emit()

func handle_disconnect(peer_id):
	if peer_id in connected_peers.keys():
		print(connected_peers[peer_id].username + " disconnected!")
		var player = connected_peers[peer_id]
		if peer_id in queued_players:
			print("Disconnected while queued.")
			queued_players.erase(peer_id)
		var new_ranked_list = []
		for package in ranked_queue[connected_peers[peer_id].rank.rank][connected_peers[peer_id].rank.rank_tier]:
			if package[0] != peer_id:
				new_ranked_list.append(package)
		ranked_queue[connected_peers[peer_id].rank.rank][connected_peers[peer_id].rank.rank_tier] = new_ranked_list
		queued_players.erase(peer_id)
		
		if player.current_match != null:
			print("Disconnected while in a match.")
			player_connection_state[player.username] = Connection.DISCONNECTED
			player.current_match.check_out_player(peer_id)
			#TODO handle disconnection stuff
		else:
			print("Clean disconnection. Player going offline.")
			player_connection_state[player.username] = Connection.OFFLINE
		connected_peers.erase(peer_id)

func attempt_login(username, password):
	rpc_id(1, "receive_login_attempt", multiplayer.get_unique_id(), username, password)
	
@rpc("any_peer")
func receive_login_attempt(peer_id, username, password):
	
	# Response IDs:
	# 0 -> Login Failure (returns with message and null player)
	# 1 -> Login Success (returns with player and enters character select)
	# 2 -> Login Reconnect (returns with player and prompts character select to reach out for match when finished loading)
	var login_response
	var player_json_string = null
	var response_id = 0
	var message = ""
	if FileAccess.file_exists("ausers/" + username + ".dat"):
		var player_data = load_player(username)
		if not "pass_hash" in player_data:
			player_data["pass_hash"] = password
			var temp_player = Player.load_player(player_data)
			save_player(temp_player, password)
		
		if player_data["pass_hash"] == password:
			if not username in player_connection_state.keys() or player_connection_state[username] == Connection.OFFLINE:
				player_json_string = load_player(username, true)
				response_id = 1
#				rpc_id(peer_id, "receive_login_success", load_player(username, true))
				
				connected_peers[peer_id] = players[username]
				player_connection_state[username] = Connection.ONLINE
			elif player_connection_state[username] == Connection.IN_GAME or player_connection_state[username] == Connection.ONLINE:

				message = "Account already logged in."
				#rpc_id(peer_id, "receive_login_failure", "Account already logged in.")
			elif player_connection_state[username] == Connection.DISCONNECTED:
				player_json_string = load_player(username, true)
				response_id = 2
				connected_peers[peer_id] = players[username]
				player_connection_state[username] = Connection.ONLINE
		else:
			message = "Incorrect password."
	else:
		message = "No player with that username exists."
	login_response = get_login_response(response_id, player_json_string, message)
	rpc_id(peer_id, "receive_login_response", login_response)

func send_player_update(peer_id):
	var username = connected_peers[peer_id].username
	var json_string = load_player(username, true)
	rpc_id(peer_id, "receive_player_update", json_string)

@rpc
func receive_player_update(player_string):
	var json = JSON.new()
	var parse_result = json.parse(player_string)
	if not parse_result == OK:
		return
	var player_data = json.get_data()
	
	_player = Player.load_player(player_data)
	_player.set_username(_player.username)
	player_update_received.emit(_player)

@rpc
func receive_login_response(json_string):
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			return
	var login_response_data = json.get_data()
	var response_id = login_response_data['id']
	var message = login_response_data['message']
	var player_string = login_response_data['player']
	
	if response_id == 0:
		set_login_message.emit(message)
		return
	
	if response_id == 2:
		match_waiting = true
	var player_json = JSON.new()
	player_json.parse(player_string)
	
	_player = Player.load_player(player_json.get_data())
	char_select.emit(_player)
	

func get_login_response(login_response_id, player=null, message=""):
	var json_dict = {
		"id": login_response_id,
		"player": player,
		"message": message,
		"version": _version
	}
	return JSON.stringify(json_dict)

@rpc
func receive_login_failure(message):
	set_login_message.emit(message)
	
@rpc
func receive_login_success(json_string):
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			return
	var player_data = json.get_data()
	_player = Player.load_player(player_data)
	char_select.emit(_player)

func attempt_register(username, password):
	rpc_id(1, "receive_register_attempt", multiplayer.get_unique_id(), username, password)

@rpc("any_peer")
func receive_register_attempt(peer_id, username, password):
	print("Received register attempt")
	
	if not FileAccess.file_exists("ausers/" + username + ".dat"):
		var player = Player.new_gen(username, password, missions)
		player.set_username(username)
		players[username] = player
		save_player(player, password)
		print("Registered a new player with username " + username + ".")
		rpc_id(peer_id, "receive_register_response", "Registration successful!")
	else:
		rpc_id(peer_id, "receive_register_response", "Registration failed! An account with that name already exists.")
	

@rpc
func receive_register_response(message):
	set_login_message.emit(message)

func start_client(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Starting client!")
		var err = multiplayer_peer.create_client("wss://server.animaslashanimearenaserver.org")
		if err != OK:
			print ("Error connecting")
			return
		multiplayer.multiplayer_peer = multiplayer_peer
		#TODO: Get player info details somewhere before this
		var player = load("res://components/player_component.tscn").instantiate()
		await get_tree().create_timer(1.0).timeout
		char_select.emit(player)

func queue_quick_match(player):
	print("Queueing quick match")
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
		
	rpc_id(1, "receive_quick_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

func queue_ranked_match(player):
	print("Queueing ranked match")
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_ranked_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

@rpc("any_peer")
func receive_quick_match_queue(peer_id, player, character_names):
	print("Player " + player['username'] + " has queued into quick match with " + str(character_names) + " as their team!")
	queued_players[peer_id] = [player, character_names]
	#TODO Check for MMR shit here I guess?
	if len(queued_players.values()) > 1:
		var player1_id = queued_players.keys()[0]
		start_quick_match(player1_id, peer_id)


@rpc("any_peer")
func receive_ranked_match_queue(peer_id, player, character_names):
	print("Player " + player['username'] + " has queued into ranked match with " + str(character_names) + " as their team!")
	#TODO Check for MMR shit here I guess?
	ranked_queue[player.rank][player.tier].append([peer_id, player, character_names])
	if find_nearest_ranked_player(peer_id) != null:
		var other_package = find_nearest_ranked_player(peer_id)
		print(other_package[0])
		print(other_package[0] in connected_peers)
		var player1_package = find_nearest_ranked_player(peer_id)
		start_ranked_match(player1_package, [peer_id, player, character_names])

func queue_private_match(player, target_username):
	print("Queueing private match: " + target_username)
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_private_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names, target_username)


@rpc("any_peer")
func receive_private_match_queue(peer_id, player, character_names, target_username):
	print(player['username'] + " is private searching for " + target_username + " with " + str(character_names) + " as their team!")
	
	if player.username in private_queue:
		print("Private match found!")
		var player1_package = private_queue[player.username]
		start_private_match(player1_package, [peer_id, player, character_names])
	else:
		private_queue[target_username] = [peer_id, player, character_names]

func start_private_match(player1_package, player2_package):
	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)
	var new_match = Match.from_players(player1_package[0], connected_peers[player1_package[0]], player1_package[2], player2_package[0], connected_peers[player2_package[0]], player2_package[2], seed, BattleScene.Match.PRIVATE)
	new_match.timeout_current_player.connect(handle_timeout)
	add_child(new_match)
	new_match.start_turn_timer()
	var first = rng.randi_range(0, 1)
	if first:
		new_match.set_player_first(connected_peers[player1_package[0]], player1_package[0])
	else:
		new_match.set_player_first(connected_peers[player2_package[0]], player2_package[0])
	print("Created new private match between " + connected_peers[player1_package[0]].username + " and " + connected_peers[player2_package[0]].username + "!")
	rpc_id(player1_package[0], "receive_private_match", player2_package[1], player2_package[2], bool(first), seed)
	rpc_id(player2_package[0], "receive_private_match", player1_package[1], player1_package[2],  not bool(first), seed)
	private_matches.append(new_match)
	private_queue.erase(player1_package[1].username)
	private_queue.erase(player2_package[1].username)
	print("Sent private match to players!")

@rpc
func receive_private_match(opponent, opponent_team, first_turn, seed):
	private_match_received.emit(opponent, opponent_team, first_turn, seed)

func attempt_match_reconnect():
	rpc_id(1, "receive_match_reconnect_request", multiplayer.get_unique_id())

@rpc("any_peer")
func receive_match_reconnect_request(peer_id):
	print("Received a match reconnect request from " + connected_peers[peer_id].username)
	if not peer_id in connected_peers:
		return
	var player = connected_peers[peer_id]
	var all_matches = ranked_matches + quick_matches + private_matches
	for ongoing_match in all_matches:
		if not ongoing_match:
			continue
		print("Checking ongoing match for missing player!")
		if player.username in ongoing_match.missing_players:
			print("Getting reconnection response!")
			#TODO get reconnection package
			ongoing_match.check_in_player(peer_id, player)
			var reconnection_package = ongoing_match.get_reconnection_info(peer_id)
			rpc_id(peer_id, "receive_reconnection_response", reconnection_package)
			return
		print("Not a match! Continuing search...")
	print("Player does not have a match waiting...")

@rpc
func receive_reconnection_response(json_package):
	print("Reconnected with a response of " + str(json_package))
	reconnection_package_received.emit(json_package)

func find_nearest_ranked_player(peer_id):
	var player = connected_peers[peer_id]
	if len(ranked_queue[player.rank.rank][player.rank.rank_tier]) > 1:
		return ranked_queue[player.rank.rank][player.rank.rank_tier][0]
	var lowest_search = [player.rank.rank, player.rank.rank_tier]
	var low_search = lowest_search
	var highest_search = [player.rank.rank, player.rank.rank_tier]
	var high_search = highest_search
	while true:
		if not lowest_search == [Rank.Type.IRON, 1]:
			low_search = get_new_rank_search(low_search[0], low_search[1], false)
			lowest_search = low_search
			if len(ranked_queue[low_search[0]][low_search[1]]) > 0:
				for queue_package in ranked_queue[low_search[0]][low_search[1]]:
					if queue_package[0] in connected_peers:
						return queue_package
		if not highest_search == [Rank.Type.GRANDMASTER, 5]:
			high_search = get_new_rank_search(high_search[0], high_search[1], true)
			highest_search = high_search
			if len(ranked_queue[high_search[0]][high_search[1]]) > 0:
				for queue_package in ranked_queue[high_search[0]][high_search[1]]:
					if queue_package[0] in connected_peers:
						return queue_package
		if highest_search == [Rank.Type.GRANDMASTER, 5] and lowest_search == [Rank.Type.IRON, 1]:
			return null
			

func get_new_rank_search(current_rank, current_tier, searching_high):
	if searching_high:
		current_tier += 1
		if current_tier == 6:
			current_tier = 1
			current_rank = current_rank + 1
			if current_rank > 7:
				current_rank = 7
				current_tier = 5
	else:
		current_tier -= 1
		if current_tier == 0:
			current_tier = 5
			current_rank = current_rank - 1
			if current_rank < 0:
				current_rank = 0
				current_tier = 1
	return [current_rank, current_tier]
			

func match_ended(ended_match):
	var player1 = ended_match.players[ended_match.players.keys()[0]]
	var player2 = ended_match.players[ended_match.players.keys()[1]]
	print("Ending match between " + player1.username + " and " + player2.username)
	if ended_match.players.keys()[0] in connected_peers:
		player_connection_state[player1.username] = Connection.ONLINE
	else:
		print(player1.username + " was disconnected when the match ended!")
		player_connection_state[player1.username] = Connection.OFFLINE
	
	if ended_match.players.keys()[1] in connected_peers:
		player_connection_state[player2.username] = Connection.ONLINE
	else:
		print(player2.username + " was disconnected when the match ended!")
		player_connection_state[player2.username] = Connection.OFFLINE
	remove_match(ended_match)
	

func start_quick_match(peer_id1, peer_id2):
	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)
	var new_match = Match.from_players(peer_id1, connected_peers[peer_id1], queued_players[peer_id1][1], peer_id2, connected_peers[peer_id2], queued_players[peer_id2][1], seed, BattleScene.Match.QUICK)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.start_turn_timer()
	print("Created new quick match between " + connected_peers[peer_id1].username + " and " + connected_peers[peer_id2].username + "!")
	var first = rng.randi_range(0, 1)
	if first:
		new_match.set_player_first(connected_peers[peer_id1], peer_id1)
	else:
		new_match.set_player_first(connected_peers[peer_id2], peer_id2)
	rpc_id(peer_id1, "receive_quick_match", queued_players[peer_id2][0], queued_players[peer_id2][1], bool(first), seed)
	rpc_id(peer_id2, "receive_quick_match", queued_players[peer_id1][0], queued_players[peer_id1][1],  not bool(first), seed)
	quick_matches.append(new_match)
	queued_players.erase(peer_id1)
	queued_players.erase(peer_id2)
	print("Sent quick match to players!")

func start_ranked_match(player1_package, player2_package):
	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)
	var new_match = Match.from_players(player1_package[0], connected_peers[player1_package[0]], player1_package[2], player2_package[0], connected_peers[player2_package[0]], player2_package[2], seed, BattleScene.Match.RANKED)
	new_match.timeout_current_player.connect(handle_timeout)
	add_child(new_match)
	new_match.start_turn_timer()
	print("Created new ranked match between " + connected_peers[player1_package[0]].username + " and " + connected_peers[player2_package[0]].username + "!")
	var first = rng.randi_range(0, 1)
	if first:
		new_match.set_player_first(connected_peers[player1_package[0]], player1_package[0])
	else:
		new_match.set_player_first(connected_peers[player2_package[0]], player2_package[0])
	rpc_id(player1_package[0], "receive_ranked_match", player2_package[1], player2_package[2], bool(first), seed)
	rpc_id(player2_package[0], "receive_ranked_match", player1_package[1], player1_package[2],  not bool(first), seed)
	ranked_matches.append(new_match)
	ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
	ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
	print("Sent ranked match to players!")


@rpc
func receive_quick_match(opponent, opponent_team, first_turn, seed):
	print("Matched with " + opponent['username'] + " using " + str(opponent_team) + " as their team! (Playing first: " + str(first_turn) +")")
	quick_match_received.emit(opponent, opponent_team, first_turn, seed)

@rpc
func receive_ranked_match(opponent, opponent_team, first_turn, seed):
	print("Matched with " + opponent['username'] + " using " + str(opponent_team) + " as their team! (Playing first: " + str(first_turn) +")")
	ranked_match_received.emit(opponent, opponent_team, first_turn, seed)

func send_hero_ban(character):
	print("Telling the server we want to ban " + character.character_name)
	rpc_id(1, "receive_hero_ban_communication", multiplayer.get_unique_id(), character.character_name)

@rpc("any_peer")
func receive_hero_ban_communication(id, character):
	print("Server heard about " + str(id) + " wanting to ban " + character)
	var current_match = connected_peers[id].current_match
	current_match.accept_ban(id, character)
	rpc_id(current_match.get_opponent(id), "ban_hero", character)
	
@rpc
func ban_hero(character):
	print("Opponent banned " + character)
	opponent_ban_received.emit(character)

func send_hero_pick(character):
	print("Telling the server we want to pick " + character.character_name)
	rpc_id(1, "receive_hero_pick_communication", multiplayer.get_unique_id(), character.character_name)

@rpc("any_peer")
func receive_hero_pick_communication(id, character):
	print("Server heard about " + str(id) + " wanting to pick " + character)
	var current_match = connected_peers[id].current_match
	current_match.accept_pick(id, character)
	rpc_id(current_match.get_opponent(id), "pick_hero", character)

@rpc
func pick_hero(character):
	print("Opponent picked " + character)
	opponent_pick_received.emit(character)
	
func send_turn_package(package):
	print("Attempting to send turn package to server.")
	rpc_id(1, "receive_turn_package", multiplayer.get_unique_id(), package)


@rpc("any_peer")
func send_match_ending(id, package):
	#Handle database player updates for wins, losses, streaks, and mission
	#progress
	var current_match = connected_peers[id].current_match
	if not current_match:
		return
	var opponent = connected_peers[current_match.get_opponent(id)]
	var rating = opponent.rank.get_rating()
	if is_instance_valid(current_match):
		if current_match.match_type != BattleScene.Match.PRIVATE and current_match.match_type != BattleScene.Match.QUICK:
			if package[connected_peers[id].username]["won"]:
				connected_peers[id].rank.add_win(current_match.match_type, rating)
				if connected_peers[id].clan != "Clanless" and (connected_peers[id].clan in clans):
					if not opponent.clan == connected_peers[id].clan:
						var clan = clans[connected_peers[id].clan]
						clan.wins += 1
			else:
				connected_peers[id].rank.add_loss(current_match.match_type, rating)
				if connected_peers[id].clan != "Clanless" and (connected_peers[id].clan in clans):
					if not opponent.clan == connected_peers[id].clan:
						var clan = clans[connected_peers[id].clan]
						clan.losses += 1
		
			var match_statistics = load("res://components/match_statistic_set.tscn").instantiate()
			match_statistics.instantiate_from_package(package)
			match_statistics.write_full_team_statistics(connected_peers[id].username)
	
	
	resave_player(connected_peers[id])
	if not current_match == null:
		current_match.dismiss_player(id)

func remove_match(_match):
	if _match in quick_matches:
		quick_matches.erase(_match)
	elif _match in ranked_matches:
		ranked_matches.erase(_match)
	elif _match in private_matches:
		private_matches.erase(_match)
	
	

func write_character_statistics(character, won):
	if not FileAccess.file_exists("stats/" + character + ".stats"):
		var new_file = FileAccess.open("stats/" + character + ".stats", FileAccess.WRITE)
		var new_data = {
			"wins": int(won),
			"losses": int(not won),
			"picks": 1
		}
		var json_string = JSON.stringify(new_data)
		new_file.store_line(json_string)
	else:
		var character_file = FileAccess.open("stats/" + character + ".stats", FileAccess.READ)
		var json = JSON.new()
		var json_string = character_file.get_line()
		var parse_result = json.parse(json_string)
		
		var char_data = json.get_data()
		
		if won:
			char_data['wins'] += 1
		else:
			char_data['losses'] += 1
		char_data['picks'] += 1
		print(character + ": " + str(char_data['wins']) + " / " + str(char_data['losses']))
		
		var write_character_statistics = FileAccess.open("stats/" + character + ".stats", FileAccess.WRITE)
		
		json_string = JSON.stringify(char_data)
		write_character_statistics.store_line(json_string)

func report_match_ending(package):
	rpc_id(1, "send_match_ending", multiplayer.get_unique_id(), package)

@rpc
func process_turn_package(package):
	print("Received Turn package from enemy player!")
	turn_package_received.emit(package)

@rpc
func receive_opponent_timeout_notification():
	print("Your opponent timed out!")
	opponent_timeout.emit()

@rpc
func receive_timeout_notification():
	print("You've timed out on your turn!")
	player_timeout.emit()

func send_queue_cancellation():
	rpc_id(1, "cancel_queue", multiplayer.get_unique_id())

func check_poll_active():
	rpc_id(1, "poll_active", multiplayer.get_unique_id())

@rpc("any_peer")
func poll_active(peer_id):
	var poll_active_file = FileAccess.open("bucket data/poll.dat", FileAccess.READ)
	var active = int(poll_active_file.get_line())
	rpc_id(peer_id, "notify_poll_state", bool(active))
	

func notify_poll_state(poll_active):
	bucket_handler.get_poll_state(poll_active)

@rpc("any_peer")
func cancel_queue(peer_id):
	print("Player " + connected_peers[peer_id].username + " cancelled their queue (or matched with a bot).")
	var player = connected_peers[peer_id]
	for player_package in ranked_queue[player.rank.rank][player.rank.rank_tier]:
		if player_package[0] == peer_id:
			ranked_queue[player.rank.rank][player.rank.rank_tier].erase(player_package)
			break
	for player_package in private_queue.values():
		if player_package[0] == peer_id:
			private_queue.erase(player_package)
			break
	queued_players.erase(peer_id)


func send_surrender():
	rpc_id(1, "process_surrender", multiplayer.get_unique_id())

@rpc("any_peer")
func process_surrender(id):
	if id in connected_peers:
		print("Received a surrender from a connected peer!")
		var current_match = connected_peers[id].current_match
		current_match.cancel_match()
		rpc_id(current_match.get_opponent(id), "receive_surrender")
	else:
		print("Received a surrender from a disconnected peer!")

func request_png_image(url):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", image_request_completed)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)

func image_request_completed(result, response_code, headers, body):
	return_texture.emit(body)

func update_cosmetics(player):
	rpc_id(1, "update_player_cosmetics", multiplayer.get_unique_id(), player.username, player.make_cosmetic_update())

@rpc("any_peer")
func update_player_cosmetics(peer_id, username, player):
	connected_peers[peer_id].absorb_cosmetic_update(player)
	resave_player(connected_peers[peer_id])
	#var player_data = load_player(username)
	#player_data['wins'] = player['wins']
	#player_data['losses'] = player['losses']
	#player_data['character_frames'] = player['character_frames']
	#player_data['action_frames'] = player['action_frames']
	#player_data['characters'] = player['characters']
	#player_data['mastery_profiles'] = player['mastery_profiles']
	#player_data['mastery_skins'] = player['mastery_skins']
	#
	#player_data['hats'] = player['hats']
	#player_data['title'] = player['title']
	#player_data['unlocks'] = player['unlocks']
	#player_data['ap'] = player['ap']
	#var write_player_data = FileAccess.open("users/" + username + ".dat", FileAccess.WRITE)
	#var json_string = JSON.stringify(player_data)
	#write_player_data.store_line(json_string)
	#print(FileAccess.get_open_error())

func update_missions(player):
	rpc_id(1, "update_mission_progress", multiplayer.get_unique_id(), player.username, player.get_mission_delta())

@rpc("any_peer")
func update_mission_progress(peer_id, username, mission_delta):
	var player = connected_peers[peer_id]
	for mission_id in mission_delta:
		if not mission_id in player.mission_data:
			player.mission_data[mission_id] = {}
		for objective in missions[mission_id].objectives:
			if not objective.obj_id in player.mission_data[mission_id]:
				player.mission_data[mission_id][objective.obj_id] = 0
			player.mission_data[mission_id][objective.obj_id] += mission_delta[mission_id][objective.obj_id]
	
	resave_player(player)
	
	

func finalize_avatar_update(player):
	rpc_id(1, "update_player_cosmetics", multiplayer.get_unique_id(), player.username, player.save())
	
@rpc("any_peer")
func update_player_avatar_data(peer_id, username, url):
	var player_data = load_player(username)
	player_data['avatar_url'] = url
	var write_player_statistics = FileAccess.open("ausers/" + username + ".dat", FileAccess.WRITE)
	var json_string = JSON.stringify(player_data)
	write_player_statistics.store_line(json_string)

func check_latest_client_version(reroute=true):
	var version_package = [_version, OS.get_name()]
	rpc_id(1, "compare_versions", multiplayer.get_unique_id(), version_package, reroute)

@rpc("any_peer")
func compare_versions(peer_id, version_package, reroute):
	var version_list = []
	var version = version_package[0]
	var os = version_package[1]
	var broken_versions = [
		"0.1.0",
		"0.2.0",
		"0.3.0",
		"1.0.0"
	]
	if version in broken_versions:
		print("A player attempted to login with an outdated Windows version!")
		version_list.append("FAIL")
	if version != _version and os == "macOS":
		print("A player attempted to login with an outdated Mac version!")
		version_list.append("FAIL")
	var version_file = FileAccess.open("version.txt", FileAccess.READ)
	while not version_file.eof_reached():
		var line = version_file.get_line()
		if not line == "":
			version_list.append(line)
	
	
	rpc_id(peer_id, "receive_update_notification", version_list, reroute)
	
@rpc
func receive_update_notification(version_list, reroute):
	if "FAIL" in version_list:
		get_tree().quit()
	if OS.get_name() == "macOS":
		if reroute:
			char_select.emit(_player)
		return
	for version in version_list:
		print("Notified of necessary version: " + version)
		if not FileAccess.file_exists("res://patch" + version + ".pck"):
			print(version + ".pck file does not exist")
			needed_versions.append(version)
	if len(needed_versions) < 1 or OS.get_name() == "macOS":
		if reroute or OS.get_name() == "macOS":
			char_select.emit(_player)
		return
	end_queue.emit()
	inform_updating.emit()
	download_version()
	
func download_version():
	var version = needed_versions[0]
	var http_request = HTTPRequest.new()
	http_request.download_chunk_size = 65536
	http_request.download_file = "res://patch" + version + ".pck"
	add_child(http_request)
	http_request.connect("request_completed", new_version_mod_pack)
	var error = http_request.request("https://storage.googleapis.com/a-a-patch/patch" + version + ".pck")

func new_version_mod_pack(result, response_code, headers, body):
	print("Download complete!")
	ProjectSettings.load_resource_pack("res://patch" + needed_versions[0] + ".pck")
	needed_versions.pop_front()
	if len(needed_versions) > 0:
		download_version()
	else:
		if not game_loaded:
			request_game_refresh.emit()
		else:
			print("Prompting Restart!")
			prompt_restart.emit()

@rpc
func receive_surrender():
	print("Opponent surrendered!")
	opponent_surrendered.emit()

func handle_timeout(nmatch):
	var package = {"timeout": true}
	rpc_id(nmatch.acting_player, "receive_timeout_notification")
	rpc_id(nmatch.get_opponent(nmatch.acting_player), "process_turn_package", package)
	nmatch.timed_out = false
	print("Sent timeout notification to players")

@rpc("any_peer")
func receive_turn_package(id, package):
	var current_match = connected_peers[id].current_match
	if not current_match.timed_out:
		current_match.receive_turn_package(id, package)
		rpc_id(current_match.get_opponent(id), "process_turn_package", package)

func send_leaderboard_request():
	rpc_id(1, "receive_leaderboard_request", multiplayer.get_unique_id())
	
@rpc("any_peer")
func receive_leaderboard_request(peer_id):
	var sets = bucket_handler.process_leaderboard_request()
	rpc_id(peer_id, "receive_leaderboard_information", sets)

@rpc
func receive_leaderboard_information(leaderboard_info_sets):
	bucket_handler.process_leaderboard_sets(leaderboard_info_sets)


func send_ladder_request(panel):
	for connection in ladder_info_received.get_connections():
		ladder_info_received.disconnect(connection['callable'])
	ladder_info_received.connect(panel.accept_ladder_data)
	rpc_id(1, "request_ladder_details", multiplayer.get_unique_id())

@rpc("any_peer")
func request_ladder_details(peer_id):
	print("Received request for ladder info!")
	var ladder_info = {
		"player_data": [],
		"clan_data": []
	}
	
	for username in players:
		var player = players[username]
		if not player:
			continue
		if player.rank.get_rating() == 0:
			continue
		ladder_info["player_data"].append(
			{
				"username": username,
				"wins": player.rank.wins,
				"losses": player.rank.losses,
				"rating": player.rank.get_rating(),
				"clan_name": player.clan
			}
		)
	
	for clan_name in clans:
		var clan = clans[clan_name]
		if clan.wins == 0 or clan.member_count() == 1:
			continue
		ladder_info["clan_data"].append(
			{
				"clan_name": clan.clan_name,
				"wins": clan.wins,
				"losses": clan.losses,
				"level": clan.get_level_from_wins(),
				"members": clan.member_count()
			}
		)
	
	ladder_info["player_data"].sort_custom(func(a, b): return a["rating"] > b["rating"])
	ladder_info["clan_data"].sort_custom(func(a, b): return a["level"] > b["level"])
	rpc_id(peer_id, "receive_ladder_details", ladder_info)

@rpc
func receive_ladder_details(ladder_info):
	print("Received ladder info!")
	ladder_info_received.emit(ladder_info)

func _on_ladder_timer_timeout():
	return
	if DisplayServer.get_name() != "headless":
		return
	print("Ladder timer timing out! Updating ladder!")
	for player in players:
		ladder[players[player].username] = players[player].rank.get_rating()
	for clan in clans:
		clan_ladder[clan] = clan.get_level_from_wins()

func send_clan_creation_request(clan_name, clan_avatar_url, panel):
	clan_creation_response_received.connect(panel.receive_clan_creation_response)
	rpc_id(1, "receive_clan_creation_request", multiplayer.get_unique_id(), clan_name, clan_avatar_url)

@rpc("any_peer")
func receive_clan_creation_request(peer_id, clan_name, clan_avatar_url):
	print("Server received request to create clan (" + clan_name + ") for " + connected_peers[peer_id].username)
	#Response is dictionary: 
	#   success: boolean
	#   clan_data: dictionary
	#   
	#
	#
	if FileAccess.file_exists("clans/" + clan_name + ".dat"):		
		rpc_id(peer_id, "receive_clan_creation_response", {"success": false, "clan_data": {}})
	else:
		#TODO: handle clan creation
		print("Clan name valid")
		var clan = load("res://components/clan.tscn").instantiate()
		clan.clan_name = clan_name
		clan.banner_url = clan_avatar_url
		clan.members[0] = [connected_peers[peer_id].username]
		save_clan(clan)
		print("Saved clan")
		connected_peers[peer_id].clan = clan_name
		clans[clan_name] = clan
		resave_player(connected_peers[peer_id])
		print("Saved Player")
		var clan_data = clan.save()
		rpc_id(peer_id, "receive_clan_creation_response", {"success": true, "clan_data": clan_data})

@rpc
func receive_clan_creation_response(clan_creation_response_data):
	print("Received response to clan creation: " + str(clan_creation_response_data))
	clan_creation_response_received.emit(clan_creation_response_data)
	if clan_creation_response_data['success']:
		_player.clan = clan_creation_response_data['clan_data']['clan_name']

func request_clan_info(clan_name, receiver):
	print("Client requesting clan info")
	clan_info_received.connect(receiver.on_clan_info_received)
	rpc_id(1, "receive_clan_info_request", multiplayer.get_unique_id(), clan_name)

@rpc("any_peer")
func receive_clan_info_request(peer_id, clan_name):
	if clan_name in clans:
		#TODO: do clan info stuff
		var clan_info = clans[clan_name].save()
		clan_info["member_info"] = {
			0: [],
			1: [],
			2: []
		}
		for i in range(3):
			for player_name in clan_info['members'][i]:
				
				clan_info["member_info"][i].append({
					"username":players[player_name].username,
					"wins":players[player_name].rank.wins,
					"losses":players[player_name].rank.losses,
					"avatar_url":players[player_name].avatar_url,
				})
		
		
		rpc_id(peer_id, "receive_clan_info", {"success": true, "clan_info": clan_info})
	else:
		#TODO: send a "no clan found response"
		rpc_id(peer_id, "receive_clan_info", {"success": false, "clan_info": {}})

@rpc
func receive_clan_info(clan_info):
	clan_info_received.emit(clan_info, self)

func request_clan_search(clan_search_string, receiver):
	print("Requesting a clan search!")
	clan_search_info_received.connect(receiver.receive_clan_search_info)
	rpc_id(1, "receive_clan_search_request", multiplayer.get_unique_id(), clan_search_string)
	
@rpc("any_peer")
func receive_clan_search_request(peer_id, clan_search_string):
	print("Server received clan search from " + connected_peers[peer_id].username)
	print("Search term: " + clan_search_string)
	var matching_clans = []
	for clan in clans:
		if clan_search_string in clan:
			matching_clans.append({
				"clan_name": clans[clan].clan_name,
				"members": clans[clan].member_count(),
				"banner_url": clans[clan].banner_url
			})
	rpc_id(peer_id, "receive_clan_search_info", matching_clans)
	
@rpc
func receive_clan_search_info(clan_info):
	print("Player received clan search info in Server")
	clan_search_info_received.emit(clan_info, self)

func request_player_search(player_search_string, receiver):
	player_search_info_received.connect(receiver.player_search_info_received)
	rpc_id(1, "receive_player_search_request", multiplayer.get_unique_id(), player_search_string)

@rpc("any_peer")
func receive_player_search_request(peer_id, player_search_string):
	print("Server received clan search from " + connected_peers[peer_id].username)
	print("Search term: " + player_search_string)
	
	var matching_players = []
	for player in players:
		if player_search_string in player:
			matching_players.append({
				"username": players[player].username,
				"wins": players[player].rank.wins,
				"losses": players[player].rank.losses,
				"avatar_url": players[player].avatar_url
			})
	rpc_id(peer_id, "receive_player_search_info", matching_players)

@rpc
func receive_player_search_info(player_info):
	player_search_info_received.emit(player_info, self)

func send_clan_application(clan_name, player_name):
	rpc_id(1, "receive_clan_application", multiplayer.get_unique_id(), clan_name, player_name)

@rpc("any_peer")
func receive_clan_application(peer_id, clan_name, player_name):
	print("Server receiving clan application from " + player_name + " for " + clan_name)
	if clan_name in clans:
		print("Adding player application to clan.")
		clans[clan_name].applied_players.append(player_name)
		save_clan(clans[clan_name])
	if player_name in players:
		players[player_name].clan_applications.append(clan_name)
		resave_player(players[player_name])

func request_player_application_invite_info(player_name, panel):
	send_player_application_invite_info.connect(panel.receive_player_application_invite_info)
	rpc_id(1, "receive_player_application_invite_request", multiplayer.get_unique_id(), player_name)

func send_player_invite(clan_name, player_name):
	rpc_id(1, "receive_player_invite", multiplayer.get_unique_id(), clan_name, player_name)

@rpc("any_peer")
func receive_player_invite(peer_id, clan_name, player_name):
	print("Server receiving clan invitation from " + clan_name + " for " + player_name)
	if not (player_name in players):
		return
	if players[player_name].clan != "Clanless":
		return
	if clan_name in clans:
		clans[clan_name].invited_players.append(player_name)
		save_clan(clans[clan_name])
	if player_name in players:
		players[player_name].clan_invitations.append(clan_name)
		resave_player(players[player_name])

@rpc("any_peer")
func receive_player_application_invite_request(peer_id, player_name):
	var clan_info = {
		"invitations": [],
		"applications": []
	}
	var seen_names = []
	if player_name in players:
		var player = players[player_name]
		for invitation in player.clan_invitations:
			if invitation in clans:
				seen_names.append(invitation)
				var clan = clans[invitation]
				clan_info["invitations"].append({
					"clan_name": clan.clan_name,
					"members": clan.member_count(),
					"banner_url": clan.banner_url
				})
		for application in player.clan_applications:
			if application in clans and not (application in seen_names):
				seen_names.append(application)
				var clan = clans[application]
				clan_info["applications"].append({
					"clan_name": clan.clan_name,
					"members": clan.member_count(),
					"banner_url": clan.banner_url
				})
	rpc_id(peer_id, "receive_player_application_invite_info", clan_info)


@rpc
func receive_player_application_invite_info(info):
	send_player_application_invite_info.emit(info, self)

func request_clan_application_invite_info(clan_name, panel):
	send_clan_application_invite_info.connect(panel.receive_clan_application_invite_info)
	rpc_id(1, "receive_clan_application_invite_request", multiplayer.get_unique_id(), clan_name)

@rpc("any_peer")
func receive_clan_application_invite_request(peer_id, clan_name):
	var player_info = {
		"applications": [],
		"invitations": []
	}
	var seen_names = []
	if clan_name in clans:
		var clan = clans[clan_name]
		for invitation in clan.invited_players:
			if invitation in players:
				seen_names.append(invitation)
				var player = players[invitation]
				player_info["invitations"].append({
					"username": player.username,
					"wins": player.rank.wins,
					"losses": player.rank.losses,
					"avatar_url": player.avatar_url
				})
		for application in clan.applied_players:
			if application in players and not (application in seen_names):
				seen_names.append(application)
				var player = players[application]
				player_info["applications"].append({
					"username": player.username,
					"wins": player.rank.wins,
					"losses": player.rank.losses,
					"avatar_url": player.avatar_url
				})
	rpc_id(peer_id, "receive_clan_application_invite_info", player_info)
	


@rpc
func receive_clan_application_invite_info(info):
	send_clan_application_invite_info.emit(info, self)

func send_clan_application_cancel(clan_name, player_name):
	rpc_id(1, "receive_clan_application_cancel", multiplayer.get_unique_id(), clan_name, player_name)
	

@rpc("any_peer")
func receive_clan_application_cancel(peer_id, clan_name, player_name):
	print("Server received request to terminate pending clan offer between " + clan_name + " and " + player_name)
	if clan_name in clans:
		var clan = clans[clan_name]
		if player_name in clan.applied_players:
			clan.applied_players.erase(player_name)
			save_clan(clan)
		if player_name in clan.invited_players:
			clan.invited_players.erase(player_name)
			save_clan(clan)
	if player_name in players:
		var player = players[player_name]
		if clan_name in player.clan_applications:
			player.clan_applications.erase(clan_name)
			resave_player(player)
		if clan_name in player.clan_invitations:
			player.clan_invitations.erase(clan_name)
			resave_player(player)

func send_player_invitation_cancel(clan_name, player_name):
	rpc_id(1, "receive_player_invitation_cancel", multiplayer.get_unique_id(), clan_name, player_name)

@rpc("any_peer")
func receive_player_invitation_cancel(peer_id, clan_name, player_name):
	if clan_name in clans:
		var clan = clans[clan_name]
		if player_name in clan.applied_players:
			clan.invited_players.erase(player_name)
			save_clan(clan)
		if player_name in clan.invited_players:
			clan.invited_players.erase(player_name)
			save_clan(clan)
	if player_name in players:
		var player = players[player_name]
		if clan_name in player.clan_invitations:
			player.clan_invitations.erase(clan_name)
			resave_player(player)
		if clan_name in player.clan_invitations:
			player.clan_invitations.erase(clan_name)
			resave_player(player)

func send_clan_offer_accepted(clan_name, player_name):
	rpc_id(1, "receive_clan_offer_accepted", multiplayer.get_unique_id(), clan_name, player_name)
	
@rpc("any_peer")
func receive_clan_offer_accepted(peer_id, clan_name, player_name):
	if not player_name in players:
		receive_clan_application_cancel(0, clan_name, player_name)
	if players[player_name].clan != "Clanless":
		receive_clan_application_cancel(0, clan_name, player_name)
	if not clan_name in clans:
		receive_clan_application_cancel(0, clan_name, player_name)
	
	var clan = clans[clan_name]
	var player = players[player_name]
	
	if not ( (clan_name in player.clan_applications) or (clan_name in player.clan_invitations) ):
		print("Player must have cancelled invite")
		
		receive_clan_application_cancel(0, clan_name, player_name)
		return
	if not ( (player_name in clan.applied_players) or (player_name in clan.invited_players) ):
		print("Clan must have cancelled invite")
		
		receive_clan_application_cancel(0, clan_name, player_name)
		return
	
	clan.members[2].append(player_name)
	if player_name in clan.applied_players:
		clan.applied_players.erase(player_name)
	if player_name in clan.invited_players:
		clan.invited_players.erase(player_name)
	
	if clan_name in player.clan_invitations:
		player.clan_invitations.erase(clan_name)
	if clan_name in player.clan_applications:
		player.clan_applications.erase(clan_name)
	
	player.clan = clan_name
	save_clan(clan)
	resave_player(player)
	check_for_online_player_to_update(player_name)

func check_for_online_player_to_update(username):
	for peer in connected_peers:
		if connected_peers[peer].username == username:
			send_player_update(peer)

func receive_kick(clan_name, player_name):
	rpc_id(1, "kick_received", clan_name, player_name)

@rpc("any_peer")
func kick_received(clan_name, player_name):
	if clan_name in clans:
		var clan = clans[clan_name]
		for i in range(3):
			if player_name in clan.members[i]:
				clan.members[i].erase(player_name)
		save_clan(clan)
	if player_name in players:
		var player = players[player_name]
		player.clan = "Clanless"
		resave_player(player)
		check_for_online_player_to_update(player_name)

func receive_promotion(clan_name, player_name):
	rpc_id(1, "promotion_received", clan_name, player_name)

@rpc("any_peer")
func promotion_received(clan_name, player_name):
	var current_rank
	if clan_name in clans:
		var clan = clans[clan_name]
		for i in range(3):
			if player_name in clan.members[i]:
				clan.members[i].erase(player_name)
				current_rank = i
		if current_rank:
			clan.members[current_rank - 1].append(player_name)
		save_clan(clan)
	if player_name in players:
		check_for_online_player_to_update(player_name)
	
func receive_demotion(clan_name, player_name):
	rpc_id(1, "demotion_received", clan_name, player_name)

@rpc("any_peer")
func demotion_received(clan_name, player_name):
	var current_rank
	if clan_name in clans:
		var clan = clans[clan_name]
		for i in range(3):
			if player_name in clan.members[i]:
				clan.members[i].erase(player_name)
				current_rank = i
		if current_rank:
			clan.members[current_rank + 1].append(player_name)
		save_clan(clan)
	if player_name in players:
		check_for_online_player_to_update(player_name)
	
func receive_leave(clan_name, player_name):
	rpc_id(1, "leave_received", clan_name, player_name)

@rpc("any_peer")
func leave_received(clan_name, player_name):
	if clan_name in clans:
		var clan = clans[clan_name]
		for i in range(3):
			if player_name in clan.members[i]:
				clan.members[i].erase(player_name)
		save_clan(clan)
	if player_name in players:
		var player = players[player_name]
		player.clan = "Clanless"
		resave_player(player)
		check_for_online_player_to_update(player_name)
