extends Node
class_name Match
static var next_match_id := 1
var match_id: int
var players = {}
var bans = {}
var picks = {}
var timed_out = false
var seed
var default_match_timer = 120.0
var acting_player
var match_type: BattleScene.Match
var cancelling = false
var starting_player
var missing_players = []
var consecutive_timeouts = 0
var manager: BattleManager = null
var spectators: Dictionary = {}
var replay_log: MatchReplayLog = null
# Server-side recorder that subscribes to the shadow manager's protocol-facing
# signals and accumulates wire-format event dictionaries. Drained by
# ServerConnection._broadcast_turn_result and shipped to both clients via
# apply_turn_result after every input, timeout, and match-end.
var event_recorder: MatchEventRecorder = null
# Phase 2 shadow validation: server-side turn counter and the state hash the
# server's BattleManager produced after each processed turn package. Clients
# report their own hash via report_state_hash for comparison.
var current_turn_number: int = 0
var server_state_hashes: Dictionary = {}
# Maps peer_id -> username for all players who have ever been in this match.
# Used to verify that a peer_id still belongs to the expected player before
# sending RPCs, preventing misrouted packets after peer-id reuse.
var peer_username_map = {}

signal timeout_current_player(nmatch, events, snapshot)
signal match_over(nmatch)
signal server_match_ended(nmatch, winner_peer_id)
signal clean_up(nmatch)

static func from_players(peer_id1, player1, player1_characters, peer_id2, player2, player2_characters, mseed, match_type):
	var new_match = load("res://components/match.tscn").instantiate()
	new_match.match_id = next_match_id
	next_match_id += 1
	new_match.seed = mseed
	new_match.match_type = match_type
	# Clear stale per-match state on the server's persistent Player objects
	# before re-recruiting. team.add_character refuses inserts past
	# max_members, so without this the second match for any user would run
	# the shadow with leftover Character instances from the first match.
	var first_player = player1
	first_player.team.characters.clear()
	first_player.equipped_characters.clear()
	for character_name in player1_characters:
		first_player.recruit_character(Character.from_character_name(character_name))
	first_player.current_match = new_match
	new_match.bans[peer_id1] = []
	new_match.picks[peer_id1] = []
	new_match.players[peer_id1] = first_player
	new_match.peer_username_map[peer_id1] = player1.username
	var second_player = player2
	second_player.team.characters.clear()
	second_player.equipped_characters.clear()
	for character_name in player2_characters:
		second_player.recruit_character(Character.from_character_name(character_name))
	second_player.current_match = new_match
	new_match.bans[peer_id2] = []
	new_match.picks[peer_id2] = []
	new_match.players[peer_id2] = second_player
	new_match.peer_username_map[peer_id2] = player2.username
	# Decide who goes first deterministically from the match seed so the
	# server-side BattleManager and both clients agree without an extra RPC.
	var coin_rng = RandomNumberGenerator.new()
	coin_rng.set_seed(mseed)
	var p1_first = coin_rng.randi_range(0, 1) == 1
	if p1_first:
		new_match.acting_player = peer_id1
		new_match.starting_player = player1.username
	else:
		new_match.acting_player = peer_id2
		new_match.starting_player = player2.username
	return new_match

func accept_ban(id, character):
	bans[id].append(character)

func player_goes_first(peer_id) -> bool:
	return acting_player != null and peer_id == acting_player

func begin_match() -> void:
	if manager != null:
		return
	if DisplayServer.get_name() != "headless":
		return
	if len(players) < 2:
		return
	var p1_peer = players.keys()[0]
	var p2_peer = players.keys()[1]
	var p1 = players[p1_peer]
	var p2 = players[p2_peer]
	manager = BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)
	# Attach the event recorder before start_battle so the very first turn's
	# setup events (TURN_STARTED for the opening turn, ENERGY_GAINED from the
	# first-turn random energy roll) are captured in the initial flush.
	event_recorder = MatchEventRecorder.new()
	event_recorder.attach(manager)
	# Hook the manager's natural match-end so server-side bookkeeping (rank,
	# AP, stats, saves, post-match player updates) runs exactly once when the
	# shadow ends the match. The MATCH_ENDED wire event is captured separately
	# by the recorder and broadcast via the next apply_turn_result.
	manager.match_ended.connect(_on_manager_match_ended)
	replay_log = MatchReplayLog.begin(self)
	var first_for_manager = (acting_player == p1_peer)
	print("[SHADOW] Match ", match_id, " starting BattleManager (", p1.username, " vs ", p2.username, ", first=", first_for_manager, ")")
	manager.start_battle(p1, p2, first_for_manager, seed, match_type)
	replay_log.record_initial_snapshot(manager.serialize_wire_snapshot())

# `won` is from the manager.player perspective. The shadow always builds with
# manager.player == canonical p1 (players.keys()[0]), so the winner peer is
# unambiguous regardless of which side acted first.
func _on_manager_match_ended(won: bool) -> void:
	var keys = players.keys()
	if len(keys) < 2:
		return
	var winner_peer_id = keys[0] if won else keys[1]
	server_match_ended.emit(self, winner_peer_id)

func release_player_objects() -> void:
	# Player objects are owned by sessions/global state, not by this match.
	# Detach them from the BattleManager so the cascade-free of the match
	# scene tree doesn't take them with it. Must be called BEFORE queue_free.
	if manager == null:
		return
	for player in players.values():
		if is_instance_valid(player) and player.get_parent() == manager:
			manager.remove_child(player)

func accept_pick(id, character):
	picks[id].append(character)
	players[id].recruit_character(Character.from_character_name(character))

# ---------------------------------------------------------------------------
# Phase 7.3 — server-authoritative input validation and application
#
# `validate_input` cross-checks a canonical-frame input package (per
# MATCH_PROTOCOL.md section 2.2) against the live shadow BattleManager. It
# enforces the integrity rules from section 2.3 — sender is the acting
# player, every action references a live character on their team, every
# ability index is in range, every target is a real character, and the
# energy_allocation actually pays for the chosen abilities.
#
# `apply_input` translates the canonical input back into the legacy
# local-frame package shape that BattleManager.process_turn_package already
# knows how to consume, then drives the shadow with it. It also rotates
# the timer and updates acting_player/consecutive_timeouts so the rest of
# the match-state machine stays consistent.
# ---------------------------------------------------------------------------

# Returns true if input is structurally valid AND the proposed actions are
# legal in the live shadow's state. The shadow manager is the authoritative
# source of truth — what it says is dead/banished/usable wins. On rejection
# a push_warning is emitted naming the specific gate that failed so turn
# rejections are debuggable from server logs.
func validate_input(input, peer_id) -> bool:
	if manager == null:
		push_warning("[VALIDATE] reject: manager null")
		return false
	if not input is Dictionary:
		push_warning("[VALIDATE] reject: input not a Dictionary")
		return false
	if peer_id != acting_player:
		push_warning("[VALIDATE] reject: peer_id ", peer_id, " != acting_player ", acting_player)
		return false
	if not (input.has("actions") and input.has("execution_order") and input.has("energy_allocation")):
		push_warning("[VALIDATE] reject: missing required keys, got ", input.keys())
		return false

	var sender_role := _peer_canonical_role(peer_id)
	if sender_role < 0:
		push_warning("[VALIDATE] reject: sender not in match")
		return false

	# Pre-populate the shadow's acting-team energy pool for the p2-first /
	# waiting_for_turn case, where process_turn_package would otherwise be the
	# first thing to call generate_team_energy. Without this the pool is empty
	# at validation time and every action looks unaffordable.
	manager.prepare_acting_energy_if_needed()

	# Sender's seat in the shadow: the shadow always builds with player == p1,
	# so sender_role 0 → manager.player.team, sender_role 1 → manager.enemy.team.
	var sender_team = manager.player.team if sender_role == 0 else manager.enemy.team
	var team_base := sender_role * 3

	var actions: Array = input.get("actions", [])
	var total_cost := {}
	for action in actions:
		if not action is Dictionary:
			push_warning("[VALIDATE] reject: action not a Dictionary")
			return false
		var canonical_char_idx := int(action.get("char_idx", -1))
		if canonical_char_idx < team_base or canonical_char_idx >= team_base + 3:
			push_warning("[VALIDATE] reject: char_idx ", canonical_char_idx, " outside sender range (base=", team_base, ")")
			return false
		var local_char_idx := canonical_char_idx - team_base
		if local_char_idx < 0 or local_char_idx >= sender_team.characters.size():
			return false
		var character = sender_team.characters[local_char_idx]
		if character.dead or character.banished:
			push_warning("[VALIDATE] reject: ", character.path_name, " dead/banished")
			return false
		var actives = character.moveset.get_active_abilities(character)
		var ability_idx := int(action.get("ability_idx", -1))
		if ability_idx < 0 or ability_idx >= actives.size():
			push_warning("[VALIDATE] reject: ", character.path_name, " ability_idx ", ability_idx, " out of range (size=", actives.size(), ")")
			return false
		var ability = actives[ability_idx]
		if ability.cooldown_remaining > 0:
			push_warning("[VALIDATE] reject: ", character.path_name, " ability ", ability.ability_name, " on cooldown ", ability.cooldown_remaining)
			return false
		if character.is_stunned(ability):
			push_warning("[VALIDATE] reject: ", character.path_name, " stunned for ", ability.ability_name)
			return false
		for energy_type in ability.cost().keys():
			total_cost[energy_type] = total_cost.get(energy_type, 0) + ability.cost()[energy_type]
		var target_idxs: Array = action.get("target_idxs", [])
		var all_chars = manager.all_characters()
		for canonical_target in target_idxs:
			var ct := int(canonical_target)
			if ct < 0 or ct >= all_chars.size():
				push_warning("[VALIDATE] reject: target ", ct, " out of bounds")
				return false

	# Total cost must be affordable from the sender team's energy pool.
	# can_afford handles RANDOM-energy substitution (where Energy.Type.RANDOM in
	# a cost can be paid with any color from the pool) which the prior raw-pool
	# check got wrong, causing first-turn rejections for any RANDOM-cost action.
	if not sender_team.energy.can_afford(total_cost):
		push_warning("[VALIDATE] reject: cannot afford ", total_cost, " from pool ", sender_team.energy.pool, " promised ", sender_team.energy.promised_pool)
		return false
	return true

# Translates the canonical-frame input package into the legacy local-frame
# turn package shape and feeds it to the shadow manager. Bumps the turn
# timer / acting_player bookkeeping the same way receive_turn_package did.
func apply_input(input, peer_id) -> void:
	if manager == null:
		return
	var sender_role := _peer_canonical_role(peer_id)
	if sender_role < 0:
		return
	var package := _canonical_input_to_legacy_package(input, sender_role)
	consecutive_timeouts = 0
	acting_player = get_opponent(peer_id)
	manager.receive_turn_package(package)
	current_turn_number += 1
	start_turn_timer()

# Returns 0 if peer is the canonical p1 (first key in players), 1 for p2,
# -1 if peer isn't in the match.
func _peer_canonical_role(peer_id) -> int:
	if not peer_id in players:
		return -1
	var keys = players.keys()
	if peer_id == keys[0]:
		return 0
	if len(keys) > 1 and peer_id == keys[1]:
		return 1
	return -1

# Reverses the canonical encoding from BattleManager.build_turn_input back
# to the legacy local-frame shape consumed by process_turn_package. The
# shadow's `player` is always canonical p1, so the legacy frame's "team"
# (the receiving side) is the shadow's player.team and team_mod alternates
# based on whether the sender is canonically p1 or p2.
func _canonical_input_to_legacy_package(input, sender_role: int) -> Dictionary:
	var character_actions: Array = []
	for action in input.get("actions", []):
		var canonical_char := int(action.get("char_idx", 0))
		var local_team_idx := canonical_char - sender_role * 3
		var ability_idx := int(action.get("ability_idx", 0))
		var canonical_targets: Array = action.get("target_idxs", [])
		var legacy_targets: Array = []
		for ct in canonical_targets:
			var canonical_t := int(ct)
			# Legacy targets are in the SENDER's local frame (0..2 = sender
			# team, 3..5 = opposing team). For p1 sender that's identity; for
			# p2 sender we swap the two halves (the same +3/-3 swap that
			# process_turn_package applies when team_mod == 3).
			if sender_role == 0:
				legacy_targets.append(canonical_t)
			else:
				legacy_targets.append(canonical_t + 3 if canonical_t < 3 else canonical_t - 3)
		character_actions.append([local_team_idx, ability_idx, legacy_targets])

	# execution_order: 0..5 = canonical character index, >= 6 = wire ticking ID.
	# Translate character entries back to sender-team local index 0..2 and
	# subtract the +3 ticking offset so the manager sees its native counter ids.
	var legacy_exec_order: Array = []
	for entry in input.get("execution_order", []):
		if typeof(entry) == TYPE_INT and entry >= 0 and entry < 6:
			legacy_exec_order.append(entry - sender_role * 3)
		elif typeof(entry) == TYPE_INT and entry >= 6:
			legacy_exec_order.append(entry - 3)
		else:
			legacy_exec_order.append(entry)

	var legacy_exchange = null
	var exchange_payload = input.get("exchange", null)
	if exchange_payload != null:
		var offer_dict := {}
		for energy_type in exchange_payload.get("offer", {}).keys():
			offer_dict[int(energy_type)] = int(exchange_payload["offer"][energy_type])
		legacy_exchange = [offer_dict, int(exchange_payload.get("request", 0))]

	return {
		"random_history": input.get("energy_allocation", []),
		"character_actions": character_actions,
		"execution_order": legacy_exec_order,
		"timeout": false,
		"exchange": legacy_exchange,
	}

func start_turn_timer():
	$Timer.stop()
	$Timer.wait_time = default_match_timer
	$Timer.start()

func cancel_match():
	if cancelling:
		return
	cancelling = true
	$Timer.stop()
	match_over.emit(self)

func handle_turn_timeout():
	if cancelling:
		return
	consecutive_timeouts += 1
	if consecutive_timeouts >= 3:
		$Timer.stop()
		cancel_match()
		return
	if manager == null:
		return
	timed_out = true

	# Drain any stale events the recorder may be holding before applying the
	# timeout package, so the broadcast contains only this timeout's events.
	if event_recorder != null:
		event_recorder.clear()

	# Feed the shadow a timeout package the same way apply_input feeds a real
	# input package — the shadow handles per-team energy generation, ticking
	# effects, and used_ability cleanup the same as it does for real turns.
	var package := {
		"random_history": [],
		"character_actions": [],
		"execution_order": [],
		"timeout": true,
		"exchange": null,
	}
	manager.receive_turn_package(package)
	current_turn_number += 1

	var events_payload: Array = []
	if event_recorder != null:
		events_payload = event_recorder.events.duplicate()
		event_recorder.clear()
	var snapshot_payload = manager.serialize_wire_snapshot()

	timeout_current_player.emit(self, events_payload, snapshot_payload)
	acting_player = get_opponent(acting_player)
	timed_out = false
	start_turn_timer()

func get_player_by_username(username):
	for player in players.values():
		if player.username == username:
			return player

func check_in_player(peer_id, player):
	missing_players.erase(player.username)
	var missing_player = get_player_by_username(player.username)
	for character in missing_player.team.characters:
		player.recruit_character(Character.from_character_name(character.path_name))
	var old_peer_id = players.find_key(missing_player)
	# Rebuild players / peer_username_map preserving the old key order. p1 is
	# players.keys()[0] and p2 is [1] everywhere (canonical seat indexing, role
	# mapping in get_reconnection_info, p1_peer/p2_peer in from_match_manager,
	# get_opponent, server_connection match-end lookups). A naive erase+insert
	# would drop the reconnecting peer to the end and silently flip roles.
	var rebuilt := {}
	var rebuilt_username_map := {}
	for key in players.keys():
		if key == old_peer_id:
			rebuilt[peer_id] = player
			rebuilt_username_map[peer_id] = player.username
		else:
			rebuilt[key] = players[key]
			rebuilt_username_map[key] = peer_username_map[key]
	players = rebuilt
	peer_username_map = rebuilt_username_map
	player.current_match = self
	# acting_player is keyed by peer_id. If the reconnecting player was the one
	# whose turn it is, the stored peer_id is now stale, so validate_input
	# would reject their moves. Bump it to the new peer_id.
	if acting_player == old_peer_id:
		acting_player = peer_id
	# Resume the turn timer if it was paused due to this player's disconnect
	if $Timer.paused:
		$Timer.paused = false


func get_reconnection_info(peer_id):
	# Phase 8.1: reconnection is now snapshot-based. The server ships the live
	# wire snapshot (same shape as apply_turn_result's trailing payload) and the
	# client rebuilds its passive manager directly from it — no seed, no history
	# replay, no per-turn re-execution. The reconnection payload is O(1) in turn
	# count, which is the whole point of the phase.
	var player = players[peer_id]
	var opponent = players[get_opponent(peer_id)]
	var player_characters = []
	var enemy_characters = []
	for character in player.team.characters:
		player_characters.append(character.path_name)
	for character in opponent.team.characters:
		enemy_characters.append(character.path_name)
	var enemy_display_info = opponent.display_package()
	# Canonical role of THIS peer: peer_id1 (players.keys()[0]) is always p1,
	# peer_id2 is always p2, matching the seat assignment in from_players.
	var peer_keys = players.keys()
	var canonical_role := 0 if peer_id == peer_keys[0] else 1

	# The authoritative state lives on the shadow. serialize_wire_snapshot is
	# index-stable (sides[0] = p1, sides[1] = p2) and includes energy pools and
	# effect payloads, so the client can walk it with the same _reconcile_*
	# helpers that process regular apply_turn_result payloads.
	var snapshot = {}
	if manager != null:
		snapshot = manager.serialize_wire_snapshot()

	var reconnection_package = {
		"enemy": enemy_display_info,
		"player_characters": player_characters,
		"enemy_characters": enemy_characters,
		"snapshot": snapshot,
		"current_timer": $Timer.time_left,
		"match_type": match_type,
		"canonical_role": canonical_role,
	}
	return JSON.stringify(reconnection_package)

func check_out_player(peer_id):
	if not peer_id in players:
		return
	missing_players.append(players[peer_id].username)
	# Pause the turn timer if the disconnected player is the one who needs to act.
	# This prevents unfair timeouts against a player whose browser tab froze.
	# The timer resumes when they reconnect (check_in_player) or the server
	# wipe timer fires and auto-surrenders them.
	if acting_player == peer_id:
		$Timer.paused = true

func get_opponent(peer_id):
	if len(players.keys()) < 2:
		return null
	if peer_id == players.keys()[0]:
		return players.keys()[1]
	else:
		return players.keys()[0]

# Returns the username that this peer_id was originally assigned to in this match.
# Used by the server to cross-check that a peer_id still belongs to the same player
# before sending RPCs, preventing misrouted packets after Godot reuses a peer_id.
func get_expected_username(peer_id):
	if peer_id in peer_username_map:
		return peer_username_map[peer_id]
	return null

func get_opponent_username(peer_id):
	var opponent_id = get_opponent(peer_id)
	if opponent_id == null:
		return null
	return get_expected_username(opponent_id)

func get_player_usernames() -> Array:
	var usernames = []
	for player in players.values():
		usernames.append(player.username)
	return usernames

func add_spectator(peer_id: int) -> void:
	spectators[peer_id] = true
	print("[SPECTATOR] Peer ", peer_id, " spectating match ", match_id)

func remove_spectator(peer_id: int) -> void:
	spectators.erase(peer_id)

func get_spectator_init() -> String:
	var keys = players.keys()
	if keys.size() < 2:
		return ""
	var p1 = players[keys[0]]
	var p2 = players[keys[1]]
	var p1_chars := []
	var p2_chars := []
	for character in p1.team.characters:
		p1_chars.append(character.path_name)
	for character in p2.team.characters:
		p2_chars.append(character.path_name)
	var snapshot := {}
	if manager != null:
		snapshot = manager.serialize_wire_snapshot()
	var package := {
		"p1": p1.display_package(),
		"p2": p2.display_package(),
		"p1_characters": p1_chars,
		"p2_characters": p2_chars,
		"snapshot": snapshot,
		"match_type": match_type,
		"current_timer": $Timer.time_left,
	}
	return JSON.stringify(package)
