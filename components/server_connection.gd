extends Node
class_name ServerConnection

# --- NETWORK CONFIGURATION ---
# Toggle NETWORK_MODE to switch between local Windows testing and the production
# websocket. LOCAL connects to a headless server running on this same machine at
# 127.0.0.1:5695 (launch the headless instance first, then start the client in a
# second window). REMOTE connects to the production wss server. The server bind
# port is the same in both modes; only the client-side URL changes.
enum NetworkMode { LOCAL, REMOTE }
const NETWORK_MODE = NetworkMode.REMOTE

const LOCAL_CLIENT_URL = "ws://127.0.0.1:5695"
const REMOTE_CLIENT_URL = "wss://server.animaslashanimearenaserver.org"

# Resolved at parse time from NETWORK_MODE. Used by both this script and game.gd.
const TARGET_IP = LOCAL_CLIENT_URL if NETWORK_MODE == NetworkMode.LOCAL else REMOTE_CLIENT_URL
const TARGET_PORT = 5695
const RECONNECT_TIMEOUT = 120.0 # Time in seconds to wait for a player to return

# --- SESSION CLASS (NEW) ---
# Holds all data for a connected user to allow for stateful reconnections
class ServerSession:
	var username: String
	var peer_id: int
	var player_data: Player # Your Player object
	var status: int = ConnectionState.ONLINE
	var current_match = null 
	var disconnect_timer: Timer = null
	
	enum ConnectionState { ONLINE, DISCONNECTED, IN_GAME }

	func _init(_username, _peer_id, _player_data):
		username = _username
		peer_id = _peer_id
		player_data = _player_data

# --- DATA STRUCTURES ---
var sessions: Dictionary = {} # Username -> ServerSession
var peer_map: Dictionary = {} # PeerID -> Username (Fast lookup)

# --- EXISTING VARIABLES ---
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

# Kept for compatibility with your enums, though Session class handles state now
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
var stats_manager: StatsManager = StatsManager.new()
@export var is_server = false
@export var bucket_handler: BucketHandler
@export var heartbeat_timer: Timer
@export var ladder_timer: Timer

# --- SIGNALS (PRESERVED) ---
signal server_start()
signal char_select(player)
signal quick_match_received(opponent, opponent_team, first, seed, canonical_role)
signal ranked_match_received(opponent, opponent_team, first, seed, canonical_role)
signal private_match_received(opponent, opponent_team, first, seed, canonical_role)
signal opponent_ban_received(character)
signal opponent_pick_received(character)
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
signal force_login_return()
signal opponent_disconnect_received()
signal opponent_reconnect_received()
# Phase 2 shadow validation: server has asked us to compute and report our
# current state hash for the given match/turn. The BattleScene listens.
signal state_hash_requested(match_id, turn_number)
# Phase 6: emitted when the server's apply_turn_result RPC arrives. Routed
# by game.tscn into BattleScene.apply_turn_result, which delegates to the
# live BattleManager. The manager's apply_turn_result is itself gated on
# `passive`, so during Phase 6 the call chain is wired but inert.
signal apply_turn_result_received(events, snapshot)
signal spectate_init_received(package)
signal spectate_denied(reason)
signal replay_saved()
# Emitted on the client when the WebSocket drops while the player is logged in.
signal connection_lost()
# Emitted on the client when the server validates a tab-away reconnect and
# the player was in a match — carries the reconnection package JSON.
signal session_reconnect_received(package)
# Emitted when a tab-away reconnect resolves without a match (session valid
# but no active game) or when the auto-login fallback completes. The overlay
# can be safely dismissed.
signal connection_lost_resolved()

var game_loaded = false
var pending_pongs: Dictionary = {} # username -> true, tracks who we're waiting on
# Client-side: tracks whether we're in the middle of an automatic reconnection
# after a tab-away disconnect (as opposed to a fresh client start).
var _is_reconnecting: bool = false
# Client-side: stored login credentials for auto-login during reconnection.
var _stored_username: String = ""
var _stored_password: String = ""
# Holds serialized replay data (Dictionary) keyed by username after a match ends.
# Players can request their replay via RPC; unclaimed replays are discarded on
# session wipe or when the player starts a new match.
var pending_replays: Dictionary = {} # username -> replay dict

# --- INITIALIZATION ---

func _ready():
	if DisplayServer.get_name() != "headless":
		multiplayer.connected_to_server.connect(notify_connection_complete)
		multiplayer.server_disconnected.connect(heartbeat_check)
		connection_ready.emit()
		heartbeat_timer.start()
	else:
		initialize_players()
		initialize_clans()
		missions = Mission.all_missions()
		for rank in ranked_queue:
			for i in range(5):
				ranked_queue[rank][i + 1] = []

# --- HELPER: GET PLAYER SAFE ---
# Replaces 'connected_peers[peer_id]' to safely get data via the new Session system
func get_player(peer_id):
	if peer_id in peer_map:
		var username = peer_map[peer_id]
		if username in sessions:
			return sessions[username].player_data
	return null

func get_session(peer_id) -> ServerSession:
	if peer_id in peer_map:
		return sessions[peer_map[peer_id]]
	return null

# --- CORE CONNECTION LOGIC ---

func actually_start_server():
	multiplayer_peer.create_server(TARGET_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = true

	# Connect signals for peer management
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[SERVER] Server started on port ", TARGET_PORT)
	print("[SERVER] Loaded ", players.size(), " players, ", clans.size(), " clans")
	server_start.emit()

func _on_peer_connected(new_peer_id):
	print("[SERVER] Peer connected: ", new_peer_id)
	await get_tree().create_timer(0.1).timeout
	player_connected.emit(new_peer_id)

	# Ask the client to validate their session immediately
	rpc_id(new_peer_id, "request_session_validation")

@rpc("any_peer")
func validate_session_response(username):
	var peer_id = multiplayer.get_remote_sender_id()

	if not username in sessions:
		# Session was wiped (lobby disconnect or reconnect timeout expired).
		# Client will auto-login with stored credentials.
		rpc_id(peer_id, "receive_back_to_login_command")
		return

	var session = sessions[username]

	# Already valid — peer_id matches the session (e.g. a heartbeat on a
	# still-live connection).
	if session.peer_id == peer_id:
		return

	# Tab-away reconnection: the session exists but is marked DISCONNECTED
	# because the server's ping-pong detected the frozen browser tab. Resume
	# the session with the new peer_id instead of forcing a full re-login.
	if session.status == ServerSession.ConnectionState.DISCONNECTED:
		if session.disconnect_timer:
			session.disconnect_timer.queue_free()
			session.disconnect_timer = null
		session.peer_id = peer_id
		session.status = ServerSession.ConnectionState.ONLINE
		peer_map[peer_id] = username
		print("[SESSION] Tab-away reconnect for '", username, "' (new peer ", peer_id, ")")

		if session.current_match != null and is_instance_valid(session.current_match):
			var current_match = session.current_match
			current_match.check_in_player(peer_id, session.player_data)
			var reconnection_info = current_match.get_reconnection_info(peer_id)
			# Notify opponent that this player came back
			var opponent_id = current_match.get_opponent(peer_id)
			if opponent_id != null and opponent_id in peer_map:
				var expected = current_match.get_expected_username(opponent_id)
				if expected != null and peer_map[opponent_id] == expected:
					rpc_id(opponent_id, "receive_opponent_reconnect_notification")
			rpc_id(peer_id, "receive_session_reconnect", reconnection_info)
		else:
			# No active match — the match ended while the player was away.
			# Send fresh player data so the client has up-to-date rank/AP.
			send_player_update(peer_id)
			rpc_id(peer_id, "receive_session_validated")
		return

	# Session exists but is ONLINE with a different peer_id. This happens
	# when the player returns from a frozen tab before the server's ping-pong
	# cycle detects the stale connection. Evict the old peer and treat it
	# the same as a DISCONNECTED reconnection.
	print("[SESSION] Evicting stale peer ", session.peer_id, " for '", username, "' (new peer ", peer_id, ")")
	var old_peer = session.peer_id
	peer_map.erase(old_peer)
	if multiplayer_peer.has_method("disconnect_peer"):
		multiplayer_peer.disconnect_peer(old_peer)
	session.peer_id = peer_id
	peer_map[peer_id] = username

	if session.current_match != null and is_instance_valid(session.current_match):
		var current_match = session.current_match
		current_match.check_in_player(peer_id, session.player_data)
		var reconnection_info = current_match.get_reconnection_info(peer_id)
		var opponent_id = current_match.get_opponent(peer_id)
		if opponent_id != null and opponent_id in peer_map:
			var expected = current_match.get_expected_username(opponent_id)
			if expected != null and peer_map[opponent_id] == expected:
				rpc_id(opponent_id, "receive_opponent_reconnect_notification")
		rpc_id(peer_id, "receive_session_reconnect", reconnection_info)
	else:
		# No active match — send fresh player data before validation.
		send_player_update(peer_id)
		rpc_id(peer_id, "receive_session_validated")

@rpc
func receive_back_to_login_command():
	# During tab-away reconnection, the session was wiped (player was in lobby
	# or the 60s timeout expired). Auto-login with stored credentials instead
	# of sending the player back to the login screen.
	if _is_reconnecting and _stored_username != "" and _stored_password != "":
		attempt_login(_stored_username, _stored_password)
		return
	_is_reconnecting = false
	force_login_return.emit()

@rpc
func request_session_validation():
	# If the client isn't actually logged in yet, ignore or send empty
	if _player == null:
		return
		
	# You need access to the stored password. 
	# If you don't store the raw password, you might need to store the hash 
	# or prompt the user to log in again.
	
	# Assuming you store them locally on login:
	var my_username = _player.username
	
	rpc_id(1, "validate_session_response", my_username)

func _on_peer_disconnected(peer_id):
	handle_disconnect(peer_id)

func handle_disconnect(peer_id):
	var dc_username = peer_map[peer_id] if peer_id in peer_map else "unknown"
	print("[SERVER] Peer disconnected: ", peer_id, " (", dc_username, ")")
	# 1. Remove from Queue (Always happens on DC)
	if peer_id in queued_players:
		queued_players.erase(peer_id)
		# Clean ranked queue
		var player = get_player(peer_id)
		if player:
			var new_ranked_list = []
			for package in ranked_queue[player.rank.rank][player.rank.rank_tier]:
				if package[0] != peer_id:
					new_ranked_list.append(package)
			ranked_queue[player.rank.rank][player.rank.rank_tier] = new_ranked_list

	# Remove from any match's spectator list
	var all_matches = ranked_matches + quick_matches + private_matches
	for ongoing_match in all_matches:
		if is_instance_valid(ongoing_match) and peer_id in ongoing_match.spectators:
			ongoing_match.remove_spectator(peer_id)

	# 2. Session Management
	var session = get_session(peer_id)
	if session:
		# Clear pending pong tracking
		pending_pongs.erase(session.username)

		# If in a match -> HOLD session
		if session.current_match != null:
			session.status = ServerSession.ConnectionState.DISCONNECTED
			var current_match = session.current_match
			current_match.check_out_player(peer_id)

			# Notify the opponent that this player disconnected
			var opponent_id = current_match.get_opponent(peer_id)
			if opponent_id != null and opponent_id in peer_map:
				var expected_username = current_match.get_expected_username(opponent_id)
				if expected_username != null and peer_map[opponent_id] == expected_username:
					rpc_id(opponent_id, "receive_opponent_disconnect_notification")

			# Start wipe timer
			var timer = Timer.new()
			timer.wait_time = RECONNECT_TIMEOUT
			timer.one_shot = true
			timer.timeout.connect(func(): wipe_session(session.username))
			add_child(timer)
			timer.start()
			session.disconnect_timer = timer

		# If just in lobby -> WIPE immediately (or short delay)
		else:
			wipe_session(session.username)

	# Always remove the ID mapping immediately so Godot can reuse the ID
	peer_map.erase(peer_id)

func wipe_session(username):
	if not username in sessions: return
	var session = sessions[username]
	pending_pongs.erase(username)
	pending_replays.erase(username)
	print("[SESSION] Wiping session for '", username, "'")

	# --- AUTO-SURRENDER ON TIMEOUT ---
	if session.current_match != null and is_instance_valid(session.current_match):
		print("[SESSION] ", username, " had active match — auto-surrendering")
		finalize_surrender(session)
	else:
		session.current_match = null
	# ---------------------------------

	if session.disconnect_timer:
		session.disconnect_timer.queue_free()
		session.disconnect_timer = null

	sessions.erase(username)
	print("[SESSION] Active sessions: ", sessions.size())

func start_client(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		var err = multiplayer_peer.create_client(TARGET_IP)
		if err != OK:
			return
		multiplayer.multiplayer_peer = multiplayer_peer
		# Client side player loading happens after login response now

# --- LOGIN & RECONNECT LOGIC ---

func attempt_login(username, password):
	_stored_username = username
	_stored_password = password
	rpc_id(1, "receive_login_attempt", multiplayer.get_unique_id(), username, password)
	
@rpc("any_peer")
func receive_login_attempt(peer_id, username, password):
	print("[LOGIN] Attempt from peer ", peer_id, ": '", username, "'")
	var login_response
	var player_json_string = null
	var response_id = 0
	var message = ""
	if FileAccess.file_exists("ausers/" + username + ".dat"):
		var player_data = load_player(username)
		# Legacy password hash check
		if not "pass_hash" in player_data:
			player_data["pass_hash"] = password
			var temp_player = Player.load_player(player_data)
			save_player(temp_player, password)

		if player_data["pass_hash"] == password:
			# --- NEW SESSION LOGIC ---

			# Case A: Reconnecting to an existing session
			if username in sessions and sessions[username].status == ServerSession.ConnectionState.DISCONNECTED:
				var session = sessions[username]

				# Stop the wipe timer
				if session.disconnect_timer:
					session.disconnect_timer.queue_free()
					session.disconnect_timer = null

				# Update ID
				session.peer_id = peer_id
				session.status = ServerSession.ConnectionState.ONLINE
				peer_map[peer_id] = username

				player_json_string = load_player(username, true)
				response_id = 2 # Reconnect ID
				print("[LOGIN] Reconnect: '", username, "' resumed session")

			# Case B: Already logged in elsewhere
			elif username in sessions and sessions[username].status != ServerSession.ConnectionState.DISCONNECTED:
				message = "Account already logged in."
				print("[LOGIN] Rejected: '", username, "' already logged in")

			# Case C: Fresh Login
			else:
				player_json_string = load_player(username, true)
				response_id = 1

				# Reload from disk so the session never starts with stale data
				# (the cached players[username] may predate cosmetic/rank/unlock saves).
				var fresh_player = Player.load_player(load_player(username))
				players[username] = fresh_player
				var new_session = ServerSession.new(username, peer_id, fresh_player)
				sessions[username] = new_session
				peer_map[peer_id] = username
				print("[LOGIN] Fresh login: '", username, "' (peer ", peer_id, ") — sessions: ", sessions.size())

		else:
			message = "Incorrect password."
			print("[LOGIN] Rejected: '", username, "' wrong password")
	else:
		message = "No player with that username exists."
		
	login_response = get_login_response(response_id, player_json_string, message)
	rpc_id(peer_id, "receive_login_response", login_response)

# --- REPLACED HELPERS & GAME LOGIC ---

func initialize_players():
	for file in DirAccess.get_files_at("ausers"):
		var player_name = file.get_slice(".dat", 0)
		players[player_name] = Player.load_player(load_player(player_name))

func initialize_clans():
	for file in DirAccess.get_files_at("clans"):
		var clan_name = file.get_slice(".dat", 0)
		clans[clan_name] = Clan.load_clan(load_clan(clan_name))

func notify_connection_complete():
	if _is_reconnecting:
		# Tab-away reconnect: the server's request_session_validation handles
		# everything, so suppress connection_complete (which would trigger
		# auto_login_check and race with the session validation path).
		return
	connection_complete.emit()
	
func _process(delta):
	delta_timer -= delta
	if delta_timer <= 0.0:
		_on_ladder_timer_timeout()
		delta_timer = 30.0
	# Server-initiated ping to detect frozen browser tabs
	if is_server:
		server_ping_timer_elapsed += delta
		if server_ping_timer_elapsed >= SERVER_PING_INTERVAL:
			server_ping_timer_elapsed = 0.0
			server_ping_cycle()

func heartbeat_check():
	if multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _player != null and not _is_reconnecting:
			_is_reconnecting = true
			connection_lost.emit()
		multiplayer_peer = WebSocketMultiplayerPeer.new()
		multiplayer_peer.create_client(TARGET_IP)
		multiplayer.multiplayer_peer = multiplayer_peer
		await get_tree().create_timer(1.0).timeout
	else:
		rpc_id(1, "receive_heartbeat", multiplayer.get_unique_id())

@rpc("any_peer")
func receive_heartbeat(peer_id):
	rpc_id(peer_id, "receive_heartbeat_response")

@rpc
func receive_heartbeat_response():
	pass # Keep silent to avoid log spam

# --- SERVER-INITIATED PING/PONG ---
# Detects frozen browser tabs that maintain the TCP connection but can't
# process messages. The server pings every online session; if a pong isn't
# received by the next cycle, the player is treated as disconnected.

const SERVER_PING_INTERVAL = 15.0
var server_ping_timer_elapsed = 0.0

func server_ping_cycle():
	# Check for missing pongs from the previous cycle
	for username in pending_pongs.keys():
		if username in sessions:
			var session = sessions[username]
			if session.status == ServerSession.ConnectionState.ONLINE and session.peer_id in peer_map:
				# Player didn't respond — treat as disconnected
				print("[PING] No pong from '", username, "' — forcing disconnect")
				var stale_peer_id = session.peer_id
				handle_disconnect(stale_peer_id)
				# Godot won't fire peer_disconnected for a frozen WebSocket,
				# so we manually disconnect them
				if multiplayer_peer.has_method("disconnect_peer"):
					multiplayer_peer.disconnect_peer(stale_peer_id)
	pending_pongs.clear()

	# Send new pings to all online sessions
	for username in sessions:
		var session = sessions[username]
		if session.status == ServerSession.ConnectionState.ONLINE and session.peer_id in peer_map:
			pending_pongs[username] = true
			rpc_id(session.peer_id, "receive_server_ping")

@rpc
func receive_server_ping():
	# Client responds immediately
	rpc_id(1, "receive_server_pong", multiplayer.get_unique_id())

@rpc("any_peer")
func receive_server_pong(peer_id):
	var session = get_session(peer_id)
	if session:
		pending_pongs.erase(session.username)

# --- OPPONENT DISCONNECT / RECONNECT NOTIFICATIONS ---

@rpc
func receive_opponent_disconnect_notification():
	opponent_disconnect_received.emit()

@rpc
func receive_opponent_reconnect_notification():
	opponent_reconnect_received.emit()

func start_server(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		actually_start_server()

func load_player(username, str=false):
	var player_save = FileAccess.open("ausers/" + username + ".dat", FileAccess.READ)
	var json = JSON.new()
	var json_string = player_save.get_line()
	var parse_result = json.parse(json_string)
	
	if not parse_result == OK:
		return
	var player_data = json.get_data()
	player_data.missions = {}
	json_string = JSON.stringify(player_data)
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
	var player = get_player(peer_id)
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
	# Keep the global players cache in sync so leaderboards, clan ops,
	# and fresh-login session creation never use stale data.
	players[player.username] = player

func send_player_update(peer_id):
	var player = get_player(peer_id)
	if player:
		var username = player.username
		var json_string = load_player(username, true)
		rpc_id(peer_id, "receive_player_update", json_string)

func _calculate_ap_gain(match_type, won: bool, player) -> int:
	var base_victory_amount = 350
	var ap_gain = base_victory_amount
	var streak_multiplier = 25
	var streak_max = 8

	var player_streak = player.rank.streak
	if player_streak > streak_max:
		player_streak = streak_max

	if match_type == BattleScene.Match.PRIVATE:
		ap_gain = 0
		streak_multiplier = 0
	elif match_type == BattleScene.Match.QUICK or match_type == BattleScene.Match.BOT:
		ap_gain -= 100
		streak_multiplier = 40
	elif match_type == BattleScene.Match.RANKED:
		player_streak = player.rank._ranked_streak
		streak_multiplier = 60
		if player_streak > streak_max:
			player_streak = streak_max

	if player_streak < 0:
		player_streak = 0
	ap_gain += streak_multiplier * player_streak

	if not won:
		ap_gain -= 150
		if ap_gain < 0:
			ap_gain = 0

	return ap_gain

func _send_post_match_player_updates(match_obj):
	for peer_id in match_obj.players:
		var match_player = match_obj.players[peer_id]
		# Only send if the player is still connected with the correct identity
		if peer_id in peer_map:
			var expected_username = match_obj.get_expected_username(peer_id)
			if expected_username != null and peer_map[peer_id] == expected_username:
				send_player_update(peer_id)
				print("[MASTERY] Sent player update to ", match_player.username)


func _handle_bot_match_ending(peer_id, session, package):
	var player = session.player_data
	if not "characters" in package or not package["characters"] is Array:
		print("[BOT MATCH] ", player.username, " — missing character list, ignoring")
		return
	var won = package.get("won", false)
	var char_names = package["characters"]
	print("[BOT MATCH] ", player.username, " ", "won" if won else "lost", " a bot match with: ", char_names)
	if won:
		player.rank.add_win(BattleScene.Match.BOT, 0)
	else:
		player.rank.add_loss(BattleScene.Match.BOT, 0)
	for char_name in char_names:
		if not char_name is String:
			continue
		var before_xp = player.character_progress.get_xp(char_name)
		if won:
			player.character_progress.award_xp(char_name, MasteryConfig.XP_PER_WIN)
		else:
			player.character_progress.deduct_xp(char_name, MasteryConfig.XP_PER_LOSS)
		var after_xp = player.character_progress.get_xp(char_name)
		var after_level = player.character_progress.get_level(char_name)
		print("[MASTERY] ", player.username, "/", char_name, ": ", before_xp, " -> ", after_xp, " XP (level ", after_level, ") [BOT ", "WIN" if won else "LOSS", "]")
	# Award AP server-side so it persists in the save file before the update
	var ap_gain = _calculate_ap_gain(BattleScene.Match.BOT, won, player)
	player.gain_ap(ap_gain)
	print("[AP] ", player.username, " gained ", ap_gain, " AP (bot match)")
	# Bounty progress — mirror the PvP server-side path so the player update
	# broadcast below carries fresh active_bounties. Bot matches race
	# send_match_ending ahead of update_cosmetics on the wire, so we can't
	# rely on the client's local computation reaching the server in time.
	if won:
		var enemy_chars = package.get("enemy_characters", [])
		if enemy_chars is Array:
			player.check_all_bounties(char_names, enemy_chars)
	resave_player(player)
	send_player_update(peer_id)
	print("[MASTERY] Saved and sent player update to ", player.username, " after bot match")


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
			return
	var login_response_data = json.get_data()
	var response_id = login_response_data['id']
	var message = login_response_data['message']
	var player_string = login_response_data['player']

	if response_id == 0:
		if _is_reconnecting:
			# Auto-login failed (e.g. password changed). Fall back to login screen.
			_is_reconnecting = false
			force_login_return.emit()
		else:
			set_login_message.emit(message)
		return

	if response_id == 2:
		match_waiting = true

	var player_json = JSON.new()
	player_json.parse(player_string)

	_player = Player.load_player(player_json.get_data())

	if _is_reconnecting and response_id == 1:
		# Auto-login succeeded but no match to reconnect to (session was
		# wiped). Dismiss the overlay and let char_select show normally.
		_is_reconnecting = false
		connection_lost_resolved.emit()

	char_select.emit(_player)
	

func get_login_response(login_response_id, player=null, message=""):
	var json_dict = {
		"id": login_response_id,
		"player": player,
		"message": message,
		"version": _version
	}
	return JSON.stringify(json_dict)

func attempt_register(username, password):
	rpc_id(1, "receive_register_attempt", multiplayer.get_unique_id(), username, password)

@rpc("any_peer")
func receive_register_attempt(peer_id, username, password):
	if not FileAccess.file_exists("ausers/" + username + ".dat"):
		var player = Player.new_gen(username, password, missions)
		player.set_username(username)
		players[username] = player
		save_player(player, password)
		print("[REGISTER] New account created: '", username, "'")
		rpc_id(peer_id, "receive_register_response", "Registration successful!")
	else:
		print("[REGISTER] Rejected: '", username, "' already exists")
		rpc_id(peer_id, "receive_register_response", "Registration failed! An account with that name already exists.")
	
@rpc
func receive_register_response(message):
	set_login_message.emit(message)

func queue_quick_match(player):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
		
	rpc_id(1, "receive_quick_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

func queue_ranked_match(player):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_ranked_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

@rpc("any_peer")
func receive_quick_match_queue(peer_id, player, character_names):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id):
		return

	var qp = get_player(peer_id)
	print("[QUEUE] ", qp.username, " joined quick queue (", character_names, ") — queue size: ", len(queued_players) + 1)
	queued_players[peer_id] = [player, character_names]

	if len(queued_players.values()) > 1:
		var player1_id = queued_players.keys()[0]
		
		# Prevent matching with yourself (just in case)
		if player1_id == peer_id:
			return
			
		start_quick_match(player1_id, peer_id)

@rpc("any_peer")
func receive_ranked_match_queue(peer_id, player, character_names):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id):
		return

	ranked_queue[player.rank][player.tier].append([peer_id, player, character_names])
	
	if find_nearest_ranked_player(peer_id) != null:
		var player1_package = find_nearest_ranked_player(peer_id)
		start_ranked_match(player1_package, [peer_id, player, character_names])

func queue_private_match(player, target_username):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_private_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names, target_username)


@rpc("any_peer")
func receive_private_match_queue(peer_id, player, character_names, target_username):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id): 
		return

	if player.username in private_queue:
		var player1_package = private_queue[player.username]
		start_private_match(player1_package, [peer_id, player, character_names])
	else:
		private_queue[target_username] = [peer_id, player, character_names]

func start_private_match(player1_package, player2_package):
	var p1 = get_player(player1_package[0])
	var p2 = get_player(player2_package[0])
	
	# --- SAFETY CHECK ---
	if not p1 or not p2:
		
		# Clean up the specific invalid entries so they don't block future invites
		if not p1:
			# Only erase if we can read the username from the cached package
			if player1_package[1] and "username" in player1_package[1]:
				private_queue.erase(player1_package[1].username)
				
		if not p2:
			if player2_package[1] and "username" in player2_package[1]:
				private_queue.erase(player2_package[1].username)
		return
	# --------------------

	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)

	var new_match = Match.from_players(player1_package[0], p1, player1_package[2], player2_package[0], p2, player2_package[2], seed, BattleScene.Match.PRIVATE)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	# ASSIGN MATCH TO SESSIONS
	get_session(player1_package[0]).current_match = new_match
	get_session(player2_package[0]).current_match = new_match

	var p1_first = new_match.player_goes_first(player1_package[0])
	# Canonical role is decided by seat order in Match.from_players: peer_id1
	# is always p1, peer_id2 is always p2. The shadow uses these as p1/p2
	# directly so the wire's "p1 vs p2" coordinates match the server's view.
	rpc_id(player1_package[0], "receive_private_match", player2_package[1], player2_package[2], p1_first, seed, 0)
	rpc_id(player2_package[0], "receive_private_match", player1_package[1], player1_package[2], not p1_first, seed, 1)
	# Drain the shadow's initial events (TURN_STARTED + first-turn ENERGY_GAINED
	# and, on p2-first matches, the p2 wait_for_turn pre-gen) so the acting
	# client sees their starting energy on turn 1 instead of after their first
	# submission. RPC ordering guarantees the receive_private_match handler runs
	# (and the client's manager.start_battle completes) before apply_turn_result
	# arrives on the same channel.
	_broadcast_turn_result(new_match)
	private_matches.append(new_match)

	# Standard cleanup for successful match
	private_queue.erase(player1_package[1].username)
	private_queue.erase(player2_package[1].username)
	print("[MATCH] Private match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")

@rpc
func receive_private_match(opponent, opponent_team, first_turn, seed, canonical_role):
	private_match_received.emit(opponent, opponent_team, first_turn, seed, canonical_role)

func attempt_match_reconnect():
	rpc_id(1, "receive_match_reconnect_request", multiplayer.get_unique_id())

@rpc("any_peer")
func receive_match_reconnect_request(peer_id):
	var session = get_session(peer_id)
	if not session: return

	var player = session.player_data

	var all_matches = ranked_matches + quick_matches + private_matches
	for ongoing_match in all_matches:
		if not is_instance_valid(ongoing_match):
			continue
		if ongoing_match.cancelling:
			continue
		if player.username in ongoing_match.missing_players:
			ongoing_match.check_in_player(peer_id, player)
			var reconnection_package = ongoing_match.get_reconnection_info(peer_id)

			# Link the session to the match
			session.current_match = ongoing_match

			# Notify the opponent that this player reconnected
			var opponent_id = ongoing_match.get_opponent(peer_id)
			if opponent_id != null and opponent_id in peer_map:
				var expected = ongoing_match.get_expected_username(opponent_id)
				if expected != null and peer_map[opponent_id] == expected:
					rpc_id(opponent_id, "receive_opponent_reconnect_notification")

			rpc_id(peer_id, "receive_reconnection_response", reconnection_package)
			return

@rpc
func receive_reconnection_response(json_package):
	reconnection_package_received.emit(json_package)

func find_nearest_ranked_player(peer_id):
	var player = get_player(peer_id)
	if not player: return null
	
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
					if queue_package[0] in peer_map: # Check if online
						return queue_package
		if not highest_search == [Rank.Type.GRANDMASTER, 5]:
			high_search = get_new_rank_search(high_search[0], high_search[1], true)
			highest_search = high_search
			if len(ranked_queue[high_search[0]][high_search[1]]) > 0:
				for queue_package in ranked_queue[high_search[0]][high_search[1]]:
					if queue_package[0] in peer_map: # Check if online
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
	if not is_instance_valid(ended_match):
		print("[MATCH] match_ended called on invalid match — ignoring")
		return

	var usernames = ended_match.get_player_usernames()
	print("[MATCH] Match ended. Players: ", usernames)

	# Update session states
	for username in usernames:
		if username in sessions:
			sessions[username].current_match = null
			if sessions[username].status == ServerSession.ConnectionState.DISCONNECTED:
				print("[MATCH] ", username, " was disconnected — wiping session")
				wipe_session(username)

	for spectator_peer in ended_match.spectators.keys():
		if spectator_peer in peer_map:
			var spec_username = peer_map[spectator_peer]
			if spec_username in sessions:
				sessions[spec_username].current_match = null
	ended_match.spectators.clear()

	# Detach Player objects from the BattleManager before the match scene
	# tree cascade-frees, since Players are owned by the global session map.
	ended_match.release_player_objects()

	# Server controls match lifecycle — remove from arrays and free the node
	remove_match(ended_match)
	ended_match.queue_free()


func start_quick_match(peer_id1, peer_id2):
	var p1 = get_player(peer_id1)
	var p2 = get_player(peer_id2)
	
	# SAFETY CHECK: If either player is missing (disconnected/unauth), abort
	if not p1 or not p2:
		# Clean up the bad entries so queue doesn't get stuck
		if not p1: queued_players.erase(peer_id1)
		if not p2: queued_players.erase(peer_id2)
		return

	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)

	var new_match = Match.from_players(peer_id1, p1, queued_players[peer_id1][1], peer_id2, p2, queued_players[peer_id2][1], seed, BattleScene.Match.QUICK)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(peer_id1).current_match = new_match
	get_session(peer_id2).current_match = new_match

	var p1_first = new_match.player_goes_first(peer_id1)
	rpc_id(peer_id1, "receive_quick_match", queued_players[peer_id2][0], queued_players[peer_id2][1], p1_first, seed, 0)
	rpc_id(peer_id2, "receive_quick_match", queued_players[peer_id1][0], queued_players[peer_id1][1], not p1_first, seed, 1)
	# Drain the shadow's initial events so the acting client sees turn-1 energy
	# before submitting. See start_private_match for details.
	_broadcast_turn_result(new_match)
	quick_matches.append(new_match)
	queued_players.erase(peer_id1)
	queued_players.erase(peer_id2)
	print("[MATCH] Quick match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")

func start_ranked_match(player1_package, player2_package):
	var p1 = get_player(player1_package[0])
	var p2 = get_player(player2_package[0])
	
	# --- SAFETY CHECK ---
	if not p1 or not p2:
		
		# We must remove the invalid player from the queue, otherwise the valid player
		# will keep trying to match with this 'ghost' and get stuck forever.
		if not p1:
			ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
			
		if not p2:
			ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
			
		# We RETURN here so the valid player stays in the queue and waits for the next cycle
		return
	# --------------------

	var rng = RandomNumberGenerator.new()
	var seed = rng.randi_range(1, 6900000)

	var new_match = Match.from_players(player1_package[0], p1, player1_package[2], player2_package[0], p2, player2_package[2], seed, BattleScene.Match.RANKED)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(player1_package[0]).current_match = new_match
	get_session(player2_package[0]).current_match = new_match

	var p1_first = new_match.player_goes_first(player1_package[0])
	rpc_id(player1_package[0], "receive_ranked_match", player2_package[1], player2_package[2], p1_first, seed, 0)
	rpc_id(player2_package[0], "receive_ranked_match", player1_package[1], player1_package[2], not p1_first, seed, 1)
	# Drain the shadow's initial events so the acting client sees turn-1 energy
	# before submitting. See start_private_match for details.
	_broadcast_turn_result(new_match)
	ranked_matches.append(new_match)

	# Standard cleanup for successful match
	ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
	ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
	print("[MATCH] Ranked match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")


@rpc
func receive_quick_match(opponent, opponent_team, first_turn, seed, canonical_role):
	quick_match_received.emit(opponent, opponent_team, first_turn, seed, canonical_role)

@rpc
func receive_ranked_match(opponent, opponent_team, first_turn, seed, canonical_role):
	ranked_match_received.emit(opponent, opponent_team, first_turn, seed, canonical_role)

func send_hero_ban(character):
	rpc_id(1, "receive_hero_ban_communication", multiplayer.get_unique_id(), character.character_name)

@rpc("any_peer")
func receive_hero_ban_communication(id, character):
	var session = get_session(id)
	if not session: return
	var current_match = session.current_match
	if not current_match or not is_instance_valid(current_match): return
	current_match.accept_ban(id, character)
	var opponent_id = current_match.get_opponent(id)
	if opponent_id != null and opponent_id in peer_map:
		var expected = current_match.get_expected_username(opponent_id)
		if expected != null and peer_map[opponent_id] == expected:
			rpc_id(opponent_id, "ban_hero", character)
	
@rpc
func ban_hero(character):
	opponent_ban_received.emit(character)

func send_hero_pick(character):
	rpc_id(1, "receive_hero_pick_communication", multiplayer.get_unique_id(), character.character_name)

@rpc("any_peer")
func receive_hero_pick_communication(id, character):
	var session = get_session(id)
	if not session: return
	var current_match = session.current_match
	if not current_match or not is_instance_valid(current_match): return
	current_match.accept_pick(id, character)
	var opponent_id = current_match.get_opponent(id)
	if opponent_id != null and opponent_id in peer_map:
		var expected = current_match.get_expected_username(opponent_id)
		if expected != null and peer_map[opponent_id] == expected:
			rpc_id(opponent_id, "pick_hero", character)

@rpc
func pick_hero(character):
	opponent_pick_received.emit(character)
	
# Phase 7.4 — outbound wrapper for the canonical-frame turn input. Wired to
# BattleScene.turn_ended in game.tscn. The `input` argument is the dict built
# by BattleManager.build_turn_input (MATCH_PROTOCOL.md section 2.2).
# submit_turn_input takes (match_id, input); the client does not currently
# know its match_id, so we pass 0 and the server resolves the match via
# session.current_match.
func send_turn_input(input):
	rpc_id(1, "submit_turn_input", 0, input)

# Phase 2 shadow validation: client wraps its post-turn hash in an RPC back
# to the server. The server matches it against its own shadow hash.
func send_state_hash(match_id, turn_number, state_hash):
	rpc_id(1, "report_state_hash", match_id, turn_number, state_hash)


@rpc("any_peer")
# Phase 7.6 — bot-match-only entry point. Multiplayer matches are now handled
# server-side via Match.server_match_ended → handle_server_match_ended; this
# RPC remains only because bot matches run entirely on the client and the
# server has no shadow to drive their result.
func send_match_ending(id, package):
	var session = get_session(id)
	if not session:
		print("[MATCH END] No session for peer ", id, " — ignoring")
		return
	if "bot_match" in package and package["bot_match"]:
		_handle_bot_match_ending(id, session, package)
		return
	# Stale-client multiplayer reports are silently dropped — the server
	# already ran the bookkeeping when its shadow ended the match.
	print("[MATCH END] Ignoring legacy multiplayer report from ", session.username)

# Phase 7.6 — server-authoritative match end. Connected to
# Match.server_match_ended; runs all post-match bookkeeping (rank, AP, stats,
# saves, player updates), broadcasts the final apply_turn_result containing
# the MATCH_ENDED event, and tears the match down — all in one synchronous
# pass so callers (submit_turn_input, finalize_surrender) don't need to
# duplicate the broadcast logic.
func handle_server_match_ended(nmatch, winner_peer_id):
	if not is_instance_valid(nmatch):
		return
	var winner = nmatch.players.get(winner_peer_id, null)
	var loser_peer_id = nmatch.get_opponent(winner_peer_id)
	var loser = nmatch.players.get(loser_peer_id, null) if loser_peer_id != null else null
	if winner == null or loser == null:
		print("[MATCH END] Missing winner/loser on match ", nmatch.match_id, " — aborting bookkeeping")
		return

	print("[MATCH END] Match ", nmatch.match_id, " ended: ", winner.username, " beat ", loser.username, " (type=", nmatch.match_type, ")")

	# Rank adjustments — all multiplayer modes except PRIVATE
	if nmatch.match_type != BattleScene.Match.PRIVATE:
		var winner_rating = loser.rank.get_rating()
		var loser_rating = winner.rank.get_rating()
		winner.rank.add_win(nmatch.match_type, winner_rating)
		loser.rank.add_loss(nmatch.match_type, loser_rating)
		if winner.clan != "Clanless" and (winner.clan in clans) and winner.clan != loser.clan:
			clans[winner.clan].wins += 1
		if loser.clan != "Clanless" and (loser.clan in clans) and loser.clan != winner.clan:
			clans[loser.clan].losses += 1

	# AP for both sides
	var winner_ap = _calculate_ap_gain(nmatch.match_type, true, winner)
	var loser_ap = _calculate_ap_gain(nmatch.match_type, false, loser)
	winner.gain_ap(winner_ap)
	loser.gain_ap(loser_ap)
	print("[AP] ", winner.username, " gained ", winner_ap, " AP, ", loser.username, " gained ", loser_ap, " AP")

	# Bounty progress — mirror battle_manager.end_match's winner-only rule.
	# Must run before resave_player / _send_post_match_player_updates so the
	# updated active_bounties get persisted and broadcast to the client.
	if nmatch.match_type != BattleScene.Match.PRIVATE:
		var winner_team = winner.team.characters.map(func(c): return c.path_name)
		var loser_team = loser.team.characters.map(func(c): return c.path_name)
		winner.check_all_bounties(winner_team, loser_team)

	# Record match stats / mastery XP — exactly once
	print("[MASTERY] Recording stats for match. Winner: ", winner.username)
	stats_manager.record_match(nmatch, winner.username)
	resave_player(winner)
	resave_player(loser)
	print("[MASTERY] Saved both players after XP award")

	# Push fresh player data to both clients
	_send_post_match_player_updates(nmatch)

	# Drain whatever the recorder accumulated this turn (DAMAGE / DIED /
	# MATCH_ENDED / etc.) and broadcast it before the match scene tree is freed.
	_broadcast_turn_result(nmatch)

	# Store replay data in memory for players to request instead of saving to
	# server disk. The data is discarded when the session is wiped or the player
	# starts a new match.
	if nmatch.replay_log != null:
		nmatch.replay_log.set_winner(winner.username)
		var replay_dict = nmatch.replay_log.to_dict()
		pending_replays[winner.username] = replay_dict
		pending_replays[loser.username] = replay_dict

	# Tear down the match (releases players, frees the node, clears sessions)
	match_ended(nmatch)

# Drain the shadow's event recorder, capture a snapshot, and ship them to
# both clients via apply_turn_result. Used by both the normal turn path
# (submit_turn_input) and the surrender / match-end paths so all clients
# observe state changes through the same wire format.
func _broadcast_turn_result(nmatch):
	if nmatch == null or not is_instance_valid(nmatch):
		return
	if nmatch.event_recorder == null or nmatch.manager == null:
		return
	var events_payload = nmatch.event_recorder.events.duplicate()
	nmatch.event_recorder.clear()
	var snapshot_payload = nmatch.manager.serialize_wire_snapshot()
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			rpc_id(client_peer, "apply_turn_result", events_payload, snapshot_payload)
	for spectator_peer in nmatch.spectators.keys():
		if spectator_peer in peer_map:
			rpc_id(spectator_peer, "apply_turn_result", events_payload, snapshot_payload)
	if nmatch.replay_log != null and events_payload.size() > 0:
		nmatch.replay_log.record_turn(events_payload, snapshot_payload)

func remove_match(_match):
	quick_matches.erase(_match)
	ranked_matches.erase(_match)
	private_matches.erase(_match)
	# Also purge any invalid (freed) references that may have accumulated
	quick_matches = quick_matches.filter(func(m): return is_instance_valid(m))
	ranked_matches = ranked_matches.filter(func(m): return is_instance_valid(m))
	private_matches = private_matches.filter(func(m): return is_instance_valid(m))
	
	
func report_match_ending(package):
	rpc_id(1, "send_match_ending", multiplayer.get_unique_id(), package)

# ===========================================================================
# Phase 2 shadow validation
#
# Server drives a passive BattleManager per match. After every package the
# server processes, it asks both clients for their post-turn state hash and
# compares them to its own — any mismatch is logged as a desync sample so we
# can iterate on parity before going server-authoritative.
# ===========================================================================

func _advance_shadow(nmatch, package, _sender_peer_id):
	if nmatch == null or nmatch.manager == null:
		return
	if nmatch.manager.match_over:
		return
	nmatch.manager.receive_turn_package(package)
	nmatch.current_turn_number += 1
	var turn_n: int = nmatch.current_turn_number
	# Snapshot the state at this exact turn so a later desync dump shows the
	# state we were comparing against, not the post-advancement state.
	var state_snapshot = nmatch.manager.serialize_gamestate()
	var json_str = JSON.stringify(state_snapshot)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(json_str.to_utf8_buffer())
	var server_hash: String = ctx.finish().hex_encode()
	nmatch.server_state_hashes[turn_n] = {"hash": server_hash, "state": state_snapshot}
	print("[HASH] Match ", nmatch.match_id, " turn ", turn_n, " server=", server_hash)
	# Phase 5: drain the event recorder and broadcast the new wire payload to
	# both clients in parallel with the existing relay path. The client-side
	# apply_turn_result is a no-op stub during Phase 5; Phase 6 wires it into
	# the local BattleManager. Drained events include any setup events that
	# fired during start_battle on the very first call.
	if nmatch.event_recorder != null:
		var events_payload = nmatch.event_recorder.events.duplicate()
		nmatch.event_recorder.clear()
		var snapshot_payload = nmatch.manager.serialize_wire_snapshot()
		print("[PROTOCOL] Match ", nmatch.match_id, " turn ", turn_n, " broadcasting ", events_payload.size(), " events")
		for client_peer in nmatch.players.keys():
			var expected_proto = nmatch.get_expected_username(client_peer)
			if client_peer in peer_map and expected_proto != null and peer_map[client_peer] == expected_proto:
				rpc_id(client_peer, "apply_turn_result", events_payload, snapshot_payload)
	# Ask both clients for their post-turn hash so we can compare. The reply
	# arrives asynchronously via report_state_hash. RPC ordering on the same
	# channel guarantees that process_turn_package (sent above) is delivered
	# before request_state_hash, so the opponent's manager has finished
	# processing this turn before being asked to hash.
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			rpc_id(client_peer, "request_state_hash", nmatch.match_id, turn_n)

# Server-side: a client has computed its post-turn hash and reported it back.
# Compare against the server's hash for that turn and log any mismatch.
@rpc("any_peer")
func report_state_hash(match_id, turn_number, client_hash):
	var sender_id = multiplayer.get_remote_sender_id()
	var session = get_session(sender_id)
	if session == null:
		return
	var nmatch = session.current_match
	if nmatch == null or not is_instance_valid(nmatch):
		return
	if nmatch.match_id != match_id:
		return
	if not turn_number in nmatch.server_state_hashes:
		# Server hasn't reached this turn yet (or already wiped) — ignore.
		return
	var entry = nmatch.server_state_hashes[turn_number]
	var server_hash: String = entry["hash"]
	var sender_username = nmatch.get_expected_username(sender_id)
	if server_hash == client_hash:
		print("[HASH] Match ", match_id, " turn ", turn_number, " ",
			sender_username, "=", client_hash, " (match)")
		return
	print("[DESYNC] Match ", match_id, " turn ", turn_number, ": ",
		sender_username, " hash=", client_hash.substr(0, 12),
		" server=", server_hash.substr(0, 12))
	_dump_desync_sample(nmatch, turn_number, sender_username, client_hash, server_hash, entry["state"])

# Client-side: server is asking for our post-turn state hash.
@rpc
func request_state_hash(match_id, turn_number):
	# The client's authoritative gameplay manager lives on the BattleScene.
	# We don't keep a direct reference here; let any listener answer the
	# request via signal. The BattleScene wires this up in Phase 2.3.
	state_hash_requested.emit(match_id, turn_number)

# Phase 6: server broadcasts the wire-protocol payload (event stream +
# snapshot) to both clients alongside the existing relay. We forward it
# through a signal so BattleScene can route it to the live BattleManager
# without ServerConnection needing to know about scene structure. The
# manager's apply_turn_result early-returns when not in passive mode, so
# during Phase 6 this call chain is wired but inert. Phase 7 flips
# passive=true for non-bot matches and the events become authoritative.
@rpc
func apply_turn_result(events: Array, snapshot: Dictionary):
	apply_turn_result_received.emit(events, snapshot)

func _dump_desync_sample(nmatch, turn_number, client_username, client_hash, server_hash, server_state):
	if not DirAccess.dir_exists_absolute("desync"):
		DirAccess.make_dir_absolute("desync")
	var filename = "desync/desync_" + str(nmatch.match_id) + "_" + str(turn_number) + ".json"
	var sample = {
		"match_id": nmatch.match_id,
		"turn": turn_number,
		"server_hash": server_hash,
		"client_hash": client_hash,
		"client_username": client_username,
		"server_state": server_state,
		"player_usernames": nmatch.get_player_usernames(),
	}
	var f = FileAccess.open(filename, FileAccess.WRITE)
	if f == null:
		print("[DESYNC] Failed to open ", filename, " for write")
		return
	f.store_string(JSON.stringify(sample, "\t"))
	f.close()
	print("[DESYNC] Wrote sample to ", filename)

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
	var player = get_player(peer_id)
	if not player: return
	
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
	var session = get_session(id)
	if session:
		print("[MATCH] Surrender from ", session.username)
		finalize_surrender(session)


func finalize_surrender(session: ServerSession):
	var current_match = session.current_match
	# Nullify immediately to prevent stale reference access
	session.current_match = null
	if not (current_match and is_instance_valid(current_match)):
		return

	# Look up opponent by username — session.peer_id may have been erased from
	# peer_map 60s ago after a disconnect-driven auto-surrender.
	var opponent_username = current_match.get_opponent_username(session.peer_id)

	if current_match.manager == null:
		# Surrender during ban/pick (no shadow yet) — fall back to plain cancel.
		current_match.cancel_match()
	else:
		# Resolve the winner peer_id by username so the auto-surrender path
		# (where session.peer_id may be stale) still routes to the right side.
		var winner_peer_id = null
		for pid in current_match.players:
			if opponent_username != null and current_match.players[pid].username == opponent_username:
				winner_peer_id = pid
				break

		if winner_peer_id == null:
			current_match.cancel_match()
		else:
			# Drive the shadow's natural end_match flow with the surrendering
			# side as the loser. end_match emits match_ended_event (recorded as
			# MATCH_ENDED) and match_ended (which fires server_match_ended →
			# handle_server_match_ended → bookkeeping + broadcast + teardown).
			# Phase 7.7: surrenders flow through the same wire path as natural
			# match ends; receive_surrender stays as a redundant notification
			# until Phase 10 collapses it into apply_turn_result.
			var p1_peer = current_match.players.keys()[0]
			var won_for_manager = (winner_peer_id == p1_peer)
			current_match.manager.end_match(won_for_manager)

	# Direct opponent notification — preserved until Phase 10 folds SURRENDER
	# into the apply_turn_result event stream.
	if opponent_username and opponent_username in sessions:
		var opponent_session = sessions[opponent_username]
		if opponent_session.status == ServerSession.ConnectionState.ONLINE:
			if opponent_session.peer_id in peer_map:
				rpc_id(opponent_session.peer_id, "receive_surrender")

func request_png_image(url):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", image_request_completed)
	var error = http_request.request(url)

func image_request_completed(result, response_code, headers, body):
	return_texture.emit(body)

func update_cosmetics(player):
	rpc_id(1, "update_player_cosmetics", multiplayer.get_unique_id(), player.username, player.make_cosmetic_update())

@rpc("any_peer")
func update_player_cosmetics(peer_id, username, player):
	var p = get_player(peer_id)
	if p:
		p.absorb_cosmetic_update(player)
		resave_player(p)

func update_missions(player):
	rpc_id(1, "update_mission_progress", multiplayer.get_unique_id(), player.username, player.get_mission_delta())

@rpc("any_peer")
func update_mission_progress(peer_id, username, mission_delta):
	var player = get_player(peer_id)
	if not player: return
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
		version_list.append("FAIL")
	if version != _version and os == "macOS":
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
		if not FileAccess.file_exists("res://patch" + version + ".pck"):
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
	ProjectSettings.load_resource_pack("res://patch" + needed_versions[0] + ".pck")
	needed_versions.pop_front()
	if len(needed_versions) > 0:
		download_version()
	else:
		if not game_loaded:
			request_game_refresh.emit()
		else:
			prompt_restart.emit()

@rpc
func receive_surrender():
	opponent_surrendered.emit()

func handle_timeout(nmatch, events, snapshot):
	print("[TIMEOUT] Match ", nmatch.match_id, " turn timeout, broadcasting ", events.size(), " events")
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			rpc_id(client_peer, "apply_turn_result", events, snapshot)

# Phase 7.3 — server-authoritative input handler. Replaces receive_turn_package
# for non-bot multiplayer matches. Validates the canonical-frame input
# (MATCH_PROTOCOL.md section 2.2) against the live shadow, applies it through
# the shadow's BattleManager, and broadcasts the resulting events + snapshot
# to both clients via apply_turn_result. Unlike the legacy relay, the server
# does NOT forward the raw input to the opponent — both clients are passive
# and consume only the authoritative event stream.
@rpc("any_peer")
func submit_turn_input(_match_id, input):
	var sender_id = multiplayer.get_remote_sender_id()
	var session = get_session(sender_id)
	if not session:
		return
	var current_match = session.current_match
	if not current_match or not is_instance_valid(current_match):
		return
	if current_match.cancelling or current_match.timed_out:
		return
	if current_match.manager == null:
		return

	if not current_match.validate_input(input, sender_id):
		var sender_name = peer_map[sender_id] if sender_id in peer_map else "unknown"
		push_warning("[INPUT] Rejected from ", sender_name)
		return

	current_match.apply_input(input, sender_id)

	# If the input ended the match, handle_server_match_ended already drained
	# the recorder, broadcast the final apply_turn_result, and tore the match
	# down synchronously while the manager.match_ended signal was firing.
	# Skip the normal broadcast in that case so we don't double-send events.
	if not is_instance_valid(current_match) or current_match.manager == null:
		return
	if current_match.manager.match_over:
		return

	_broadcast_turn_result(current_match)

func send_energy_exchange(offer: Dictionary, request: int):
	var wire_offer := {}
	for key in offer.keys():
		wire_offer[int(key)] = int(offer[key])
	rpc_id(1, "submit_energy_exchange", wire_offer, int(request))

@rpc("any_peer")
func submit_energy_exchange(offer_dict, request_type):
	var sender_id = multiplayer.get_remote_sender_id()
	var session = get_session(sender_id)
	if not session:
		return
	var current_match = session.current_match
	if not current_match or not is_instance_valid(current_match):
		return
	if current_match.cancelling or current_match.timed_out:
		return
	if current_match.manager == null:
		return
	if sender_id != current_match.acting_player:
		push_warning("[EXCHANGE] Rejected: sender ", sender_id, " is not acting player")
		return

	var offer := {}
	for key in offer_dict.keys():
		offer[int(key)] = int(offer_dict[key])
	var request := int(request_type)

	var sender_role = current_match._peer_canonical_role(sender_id)
	var sender_team = current_match.manager.player.team if sender_role == 0 else current_match.manager.enemy.team

	for energy_type in offer.keys():
		if sender_team.energy.pool.get(energy_type, 0) < offer[energy_type]:
			push_warning("[EXCHANGE] Rejected: cannot afford offer ", offer, " from pool ", sender_team.energy.pool)
			return

	if sender_role == 0:
		current_match.manager.accept_exchange(offer, request)
	else:
		current_match.manager.accept_enemy_exchange(offer, request)
	current_match.manager.last_exchange = null

	_broadcast_turn_result(current_match)

# ---------------------------------------------------------------------------
# SPECTATOR
# ---------------------------------------------------------------------------

func send_spectate_request(target_username: String):
	rpc_id(1, "submit_spectate_request", target_username)

@rpc("any_peer")
func submit_spectate_request(target_username: String):
	var sender_id = multiplayer.get_remote_sender_id()
	var session = get_session(sender_id)
	if not session:
		return
	if session.current_match != null:
		rpc_id(sender_id, "receive_spectate_denied", "You are already in a match.")
		return

	var all_matches = ranked_matches + quick_matches + private_matches
	for ongoing_match in all_matches:
		if not is_instance_valid(ongoing_match) or ongoing_match.cancelling:
			continue
		if ongoing_match.manager == null:
			continue
		var match_usernames = ongoing_match.get_player_usernames()
		if target_username in match_usernames:
			ongoing_match.add_spectator(sender_id)
			session.current_match = ongoing_match
			var init_package = ongoing_match.get_spectator_init()
			rpc_id(sender_id, "receive_spectate_init", init_package)
			return

	rpc_id(sender_id, "receive_spectate_denied", "No active match found for " + target_username + ".")

@rpc
func receive_spectate_init(json_package: String):
	spectate_init_received.emit(json_package)

@rpc
func receive_spectate_denied(reason: String):
	spectate_denied.emit(reason)

# Tab-away reconnection: server validated the session and the player has an
# active match. The package is the same JSON that attempt_match_reconnect
# produces, so the client can rebuild the battle scene from it.
@rpc
func receive_session_reconnect(reconnection_package_json: String):
	_is_reconnecting = false
	session_reconnect_received.emit(reconnection_package_json)

# Tab-away reconnection: server validated the session but the player has no
# active match. The overlay can be dismissed.
@rpc
func receive_session_validated():
	_is_reconnecting = false
	connection_lost_resolved.emit()

# ---------------------------------------------------------------------------
# REPLAY DOWNLOAD
# ---------------------------------------------------------------------------

# Client calls this to ask the server for the replay data from the last match.
func send_replay_request():
	rpc_id(1, "submit_replay_request")

@rpc("any_peer")
func submit_replay_request():
	var sender_id = multiplayer.get_remote_sender_id()
	var session = get_session(sender_id)
	if not session:
		return
	var replay_dict = pending_replays.get(session.username, null)
	if replay_dict == null:
		print("[REPLAY] No pending replay for ", session.username)
		return
	print("[REPLAY] Sending replay to ", session.username)
	rpc_id(sender_id, "receive_replay_data", replay_dict)
	pending_replays.erase(session.username)

@rpc
func receive_replay_data(replay_dict: Dictionary):
	var log = MatchReplayLog.from_dict(replay_dict)
	if log == null:
		push_warning("[REPLAY] Failed to parse replay data from server")
		return
	log.save_to_file()
	print("[REPLAY] Saved replay locally: ", log.match_id)
	replay_saved.emit()

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

const LADDER_TOP_N = 50

@rpc("any_peer")
func request_ladder_details(peer_id):
	var requesting_player = get_player(peer_id)
	var requesting_username = ""
	if requesting_player:
		requesting_username = requesting_player.username

	var all_players = []
	for username in players:
		var player = players[username]
		if not player:
			continue
		all_players.append({
			"username": username,
			"wins": player.rank.wins,
			"losses": player.rank.losses,
			"rating": player.rank.get_rating(),
			"streak": player.rank.streak,
			"ranked_streak": player.rank._ranked_streak,
			"clan_name": player.clan
		})

	var all_clans = []
	for clan_name in clans:
		var clan = clans[clan_name]
		if clan.wins == 0 or clan.member_count() == 1:
			continue
		all_clans.append({
			"clan_name": clan.clan_name,
			"wins": clan.wins,
			"losses": clan.losses,
			"level": clan.get_level_from_wins(),
			"members": clan.member_count()
		})
	all_clans.sort_custom(func(a, b): return a["level"] > b["level"])

	var ladder_info = {
		"by_rating": _build_top_n_with_me(all_players, "rating", LADDER_TOP_N, requesting_username),
		"by_wins": _build_top_n_with_me(all_players, "wins", LADDER_TOP_N, requesting_username),
		"by_streak": _build_top_n_with_me(all_players, "streak", LADDER_TOP_N, requesting_username),
		"clan_data": all_clans.slice(0, LADDER_TOP_N)
	}
	rpc_id(peer_id, "receive_ladder_details", ladder_info)


# Sorts `rows` by `sort_key` descending, drops non-positive entries (0-rating
# / 0-win / 0-or-loss-streak players don't belong on a "top" board), takes
# top `n`, and — when the requester isn't in that top — appends their full
# rank + row so the client can show a "you" entry below the cut.
func _build_top_n_with_me(rows: Array, sort_key: String, n: int, my_username: String) -> Dictionary:
	var sorted_rows = []
	for row in rows:
		if row[sort_key] <= 0:
			continue
		sorted_rows.append(row)
	sorted_rows.sort_custom(func(a, b): return a[sort_key] > b[sort_key])

	var top = sorted_rows.slice(0, n)

	var me_entry = null
	if my_username != "":
		var found_in_top = false
		for row in top:
			if row["username"] == my_username:
				found_in_top = true
				break
		if not found_in_top:
			for i in range(sorted_rows.size()):
				if sorted_rows[i]["username"] == my_username:
					me_entry = {"rank": i + 1, "row": sorted_rows[i]}
					break

	return {"top": top, "me": me_entry}

@rpc
func receive_ladder_details(ladder_info):
	ladder_info_received.emit(ladder_info)

func _on_ladder_timer_timeout():
	return
	if DisplayServer.get_name() != "headless":
		return
	for player in players:
		ladder[players[player].username] = players[player].rank.get_rating()
	for clan in clans:
		clan_ladder[clan] = clan.get_level_from_wins()

func send_clan_creation_request(clan_name, clan_avatar_url, panel):
	clan_creation_response_received.connect(panel.receive_clan_creation_response)
	rpc_id(1, "receive_clan_creation_request", multiplayer.get_unique_id(), clan_name, clan_avatar_url)

@rpc("any_peer")
func receive_clan_creation_request(peer_id, clan_name, clan_avatar_url):
	var player = get_player(peer_id)
	if FileAccess.file_exists("clans/" + clan_name + ".dat"):		
		rpc_id(peer_id, "receive_clan_creation_response", {"success": false, "clan_data": {}})
	else:
		var clan = load("res://components/clan.tscn").instantiate()
		clan.clan_name = clan_name
		clan.banner_url = clan_avatar_url
		clan.members[0] = [player.username]
		save_clan(clan)
		player.clan = clan_name
		clans[clan_name] = clan
		resave_player(player)
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
	var player = get_player(peer_id)
	print("Server received clan search from " + player.username)
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
	var player = get_player(peer_id)
	print("Server received clan search from " + player.username)
	print("Search term: " + player_search_string)
	
	var matching_players = []
	for p_key in players:
		if player_search_string in p_key:
			matching_players.append({
				"username": players[p_key].username,
				"wins": players[p_key].rank.wins,
				"losses": players[p_key].rank.losses,
				"avatar_url": players[p_key].avatar_url
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
	print("Server received request to terminate pending clan offer between " + str(clan_name) + " and " + str(player_name))
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
	if username in sessions and sessions[username].status == ServerSession.ConnectionState.ONLINE:
		var peer_id = sessions[username].peer_id
		send_player_update(peer_id)

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
