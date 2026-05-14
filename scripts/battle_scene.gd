extends Control
class_name BattleScene

# ===========================================================================
# SCENE REFERENCES (unchanged from original .tscn layout)
# ===========================================================================
@export var menu_container: HBoxContainer
@export var system_column: VBoxContainer
@export var profile_button_container: HBoxContainer
@export var info_panel: EffectTooltipHoverPanel
@onready var blotter = $BlotterContainer
@export var description_panel_container: MarginContainer
@export var turn_end_button: PanelContainer
@export var timer_bar: TimerBar

# ===========================================================================
# ENUMS — kept for backward compatibility (game_end_panel.gd,
# server_connection.gd, etc. reference BattleScene.Match.*)
# ===========================================================================
enum Gamestate {
	LOADING,
	OPEN,
	RESOLVING,
	CLOSED,
	TARGETING
}
enum Match {
	PRIVATE,
	QUICK,
	BOT,
	RANKED
}

# ===========================================================================
# MANAGER — all game logic lives here
# ===========================================================================
var manager: BattleManager

# ===========================================================================
# DISPLAY-ONLY STATE
# ===========================================================================
var description_panel: PanelContainer
var player_profile
var enemy_profile
var game_end_panel = null
var menu_up = false
var random_panel
var exchange_panel
var sharp_notification_playing = false
var current_timer_func = func (): pass
var _reconnect_timer_remaining: float = 0.0
var spectator_mode: bool = false
var replay_mode: bool = false

var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"big_click": load("res://assets/sounds/champ_select.mp3"),
	"end_turn": load("res://assets/sounds/endturn.mp3"),
	"start_turn": load("res://assets/sounds/myturn.mp3"),
	"yahoo": load("res://assets/sounds/ingameyahoo.mp3"),
	"undo": load("res://assets/sounds/undo_click.mp3"),
	"character_click": load("res://assets/sounds/champ_select.mp3"),
	"soft_click": load("res://assets/sounds/soft_click.mp3"),
	"hard_click": load("res://assets/sounds/hard_clatter.mp3"),
	"pop": load("res://assets/sounds/pop.mp3"),
	"soft_clatter": load('res://assets/sounds/soft_clatter.mp3'),
	"panel_bop": load("res://assets/sounds/panel_bop.mp3"),
	"short_beep": load("res://assets/sounds/short_beep.mp3"),
	"sharp_notification": load("res://assets/sounds/sharp_notification.mp3"),
}

# ===========================================================================
# PROPERTY ACCESSORS — delegate to manager so that external code which
# accesses battle_scene.player, battle_scene.match_type, etc. still works.
# UI code like action_button.gd also reaches entity.battle.waiting_for_turn.
# Since entity.battle == manager, manager has these natively;
# these accessors are for anything that references the BattleScene directly.
# ===========================================================================
var player:
	get: return manager.player if manager else null
	set(v):
		if manager: manager.player = v
var enemy:
	get: return manager.enemy if manager else null
	set(v):
		if manager: manager.enemy = v
var gamestate:
	get: return manager.gamestate if manager else Gamestate.CLOSED
var match_type:
	get: return manager.match_type if manager else Match.QUICK
var waiting_for_turn:
	get: return manager.waiting_for_turn if manager else false
var match_over:
	get: return manager.match_over if manager else false
var reconnecting:
	get: return manager.reconnecting if manager else false

# ===========================================================================
# SIGNALS — same declarations as before for external compatibility.
# Forwarded from manager signals where applicable.
# ===========================================================================
signal save_mission_progress(_player)
signal refreshing()
signal character_clicked(character)
signal message_request(message)
signal message_demand(message)
signal log_event(event)
signal turn_ended(package)
signal match_ended(won)
signal char_select_return(player_ref)
signal send_surrender()
signal send_save_player(_player)
signal energy_exchange_requested(offer, request)
# Phase 2 shadow validation: emitted after we hash our local manager state
# in response to a state_hash_requested from the server.
signal state_hash_ready(match_id, turn_number, state_hash)
signal replay_save_requested()

# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready():
	manager = BattleManager.new()
	manager.name = "BattleManager"
	add_child(manager)
	_connect_manager_signals()
	var log_box = get_node_or_null("MessageBoxComponent")
	if log_box != null and log_box.has_method("bind_battle"):
		log_box.bind_battle(self)
		move_child(log_box, get_child_count() - 1)

func _process(_delta):
	pass

# ===========================================================================
# MANAGER SIGNAL WIRING
# ===========================================================================

func _connect_manager_signals():
	# Match lifecycle
	manager.battle_started.connect(_on_battle_started)
	manager.battle_reconnect_started.connect(_on_battle_reconnect_started)
	manager.match_ended.connect(_on_match_ended)

	# Turn flow
	manager.turn_started.connect(_on_turn_started)
	manager.waiting_for_opponent.connect(_on_waiting_for_opponent)
	manager.refreshing.connect(func(): refreshing.emit())

	# Character action sounds
	manager.character_action_confirmed.connect(_on_character_action_confirmed)
	manager.character_click_missed.connect(func(): play_sound("click"))
	manager.action_cancelled.connect(func(_c): play_sound("undo"))

	# Messages — re-emit on BattleScene so .tscn signal connections still work
	manager.message_request.connect(func(msg): message_request.emit(msg))
	manager.message_demand.connect(func(msg): message_demand.emit(msg))
	manager.log_event.connect(func(evt): log_event.emit(evt))

	# Display bridge for show_panel (UI code calls character.battle.show_panel)
	manager.show_panel_requested.connect(show_panel)

	# Energy / panels
	manager.random_panel_needed.connect(_on_random_panel_needed)
	manager.exchange_processed.connect(_on_exchange_processed)

	# Turn packages → forward to external signal
	manager.turn_package_ready.connect(func(pkg): turn_ended.emit(pkg))
	# Phase 7: passive multiplayer clients emit turn_input_ready (the canonical
	# wire input from build_turn_input) instead of turn_package_ready. We
	# forward through the same turn_ended signal so the existing game.tscn
	# wiring (turn_ended → ServerConnection.send_turn_input) still fires.
	manager.turn_input_ready.connect(func(input): turn_ended.emit(input))
	manager.send_surrender.connect(func(): send_surrender.emit())

	# Bot
	manager.bot_turn_requested.connect(_on_bot_turn_requested)
	manager.bot_surrender_triggered.connect(_on_bot_surrender_triggered)

	# Persistence / navigation → forward to external signals
	manager.save_mission_progress_requested.connect(func(p): save_mission_progress.emit(p))
	manager.save_player_requested.connect(func(p): send_save_player.emit(p))
	manager.char_select_return_requested.connect(_on_char_select_return)
	manager.match_report_ready.connect(func(_won, pkg): match_ended.emit(pkg))

	# Round execution
	manager.round_loop_started.connect(_on_round_loop_started)

	# Character clicked → forward to BattleScene signal
	manager.character_clicked.connect(func(c): character_clicked.emit(c))

# ===========================================================================
# PUBLIC ENTRY POINTS — called by game.gd / server_connection.gd
# ===========================================================================

func start_battle_scene(nplayer, nenemy, first, seed, m_type, canonical_role: int = 0):
	# Wipe any residue from a previous match before wiring up the new one.
	# Without this, a game_end_panel created by the prior match's _on_match_ended
	# can still be in the tree — the return_to_char_select flow queue_frees it
	# but on a requeue race that free can be skipped or the scene can be
	# re-shown before the free processes, leaving a stale "You lose" panel
	# covering the new battle.
	reset_scene()
	_clear_action_log()
	sharp_notification_playing = true
	play_sound("sharp_notification")

	# Configure bot timer durations (display concern)
	$BotFakeTimer.wait_time = randi_range(8, 16)
	$BotCrashTimer.wait_time = $BotFakeTimer.wait_time + 2

	# Fetch enemy avatar (display concern)
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", enemy_avatar_fetch_completed)
	http_request.request(nenemy.avatar_url)

	# Delegate all game logic to manager.
	# manager.start_battle() initialises characters, connects logic signals,
	# starts passives, assigns missions, then emits battle_started (which
	# triggers _on_battle_started for UI setup) before starting the first turn.
	manager.start_battle(nplayer, nenemy, first, seed, m_type, canonical_role)


func start_battle_scene_reconnect(nplayer, nenemy, snapshot, m_type, canonical_role: int = 0, timer_remaining: float = 120.0):
	reset_scene()
	_clear_action_log()
	sharp_notification_playing = true
	play_sound("sharp_notification")

	$BotFakeTimer.wait_time = nplayer.bot_turn_delay
	$BotCrashTimer.wait_time = nplayer.bot_turn_delay + 2

	_reconnect_timer_remaining = timer_remaining

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", enemy_avatar_fetch_completed)
	http_request.request(nenemy.avatar_url)

	manager.start_battle_reconnect(nplayer, nenemy, snapshot, m_type, canonical_role)


func start_battle_scene_spectate(nplayer, nenemy, snapshot, m_type, timer_remaining: float = 120.0):
	reset_scene()
	_clear_action_log()
	spectator_mode = true
	sharp_notification_playing = true
	play_sound("sharp_notification")

	_reconnect_timer_remaining = timer_remaining

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", enemy_avatar_fetch_completed)
	http_request.request(nenemy.avatar_url)

	manager.start_battle_spectate(nplayer, nenemy, snapshot, m_type)


func start_replay(nplayer, nenemy, replay_log: MatchReplayLog):
	reset_scene()
	spectator_mode = true
	replay_mode = true
	sharp_notification_playing = true
	play_sound("sharp_notification")

	var replay_player = MatchReplayPlayer.new()
	replay_player.name = "ReplayPlayer"
	add_child(replay_player)
	replay_player.load_replay_from_log(replay_log)

	manager.start_battle_spectate(nplayer, nenemy, replay_log.initial_snapshot, replay_log.match_type)
	replay_player.bind_manager(manager)


func receive_surrender():
	manager.receive_surrender()


# Phase 2 shadow validation: server is asking us to hash our current
# BattleManager state for the given turn so it can compare against its own.
func handle_state_hash_request(match_id, turn_number):
	if manager == null:
		return
	var state_hash = manager.compute_state_hash()
	state_hash_ready.emit(match_id, turn_number, state_hash)

# Phase 6: server has broadcast the new wire-protocol payload for this
# turn. Forward it to the live manager (which gates on `passive` and is
# inert during Phase 6) and run a snapshot consistency check that compares
# the server's wire snapshot to the live manager's view, surfacing any
# protocol-level drift before Phase 7 makes the events authoritative.
func handle_apply_turn_result(events, snapshot):
	if manager == null:
		return
	manager.apply_turn_result(events, snapshot)
	_validate_snapshot_against_live(snapshot)


func _validate_snapshot_against_live(snapshot):
	if manager == null:
		return
	var drift_count := manager.validate_snapshot(snapshot)
	if drift_count > 0:
		push_warning("[SNAPSHOT DRIFT] total mismatches: ", drift_count)

# ===========================================================================
# DISPLAY-ONLY CHARACTER SIGNAL CONNECTIONS
#
# Logic signals (ability_selected → receive_ability_use_request, etc.) are
# connected by the manager inside character.startup(manager) →
# manager.connect_character(char).
#
# The display signals below are connected after the manager has initialised.
# ===========================================================================

func _connect_character_display(char):
	char.ability_selected.connect(describe_ability)
	char.character_selected.connect(describe_character)
	char.finished_targeting.connect(reset_targeting)
	char.hide_panel.connect(hide_panel)

# ===========================================================================
# MANAGER SIGNAL HANDLERS (display reactions to game-state changes)
# ===========================================================================

func _on_battle_started(_first):
	# Last-line defense against a prior match's UI surviving into this one.
	# reset_scene is already called at the top of start_battle_scene, but the
	# sweep is cheap and the visible-panel bug is worse than a double free.
	_sweep_transient_panels()
	for character in manager.all_characters():
		_connect_character_display(character)
	create_test_interface()
	describe_character(manager.all_characters()[0])


func _on_battle_reconnect_started(_snapshot):
	_sweep_transient_panels()
	for character in manager.all_characters():
		_connect_character_display(character)
	create_test_interface()
	describe_character(manager.all_characters()[0])


func _on_turn_started(_is_player_turn):
	if not sharp_notification_playing:
		play_sound("start_turn")
	else:
		sharp_notification_playing = false
	if not replay_mode:
		timer_bar.stop_timer()
		if _reconnect_timer_remaining > 0.0:
			timer_bar.start_timer(_reconnect_timer_remaining, timer_bar.DEFAULT_TURN_TIMER)
			_reconnect_timer_remaining = 0.0
		else:
			timer_bar.start_timer()
		turn_end_button.stop_waiting()


func _on_waiting_for_opponent():
	if not sharp_notification_playing:
		play_sound("start_turn")
	else:
		sharp_notification_playing = false
	if not replay_mode:
		timer_bar.stop_timer()
		if _reconnect_timer_remaining > 0.0:
			timer_bar.start_timer(_reconnect_timer_remaining, timer_bar.DEFAULT_TURN_TIMER)
			_reconnect_timer_remaining = 0.0
		else:
			timer_bar.start_timer()
		turn_end_button.set_waiting()


func _on_character_action_confirmed(_character):
	$Sound.volume_db = -20
	play_sound("big_click")
	$Sound.volume_db = -10


func _on_random_panel_needed(team, random_count, exec_order):
	if random_panel != null:
		random_panel.queue_free()
	activate_menu_state()
	random_panel = RandomPanel.from_info(team, random_count, exec_order)
	random_panel.random_paid.connect(_on_allotment_accepted)
	random_panel.cancel_panel.connect(_on_allotment_cancelled)
	random_panel.request_sound.connect(play_sound)
	blotter.add_child(random_panel)


func _on_allotment_accepted(exe_order, random_history):
	random_panel.queue_free()
	random_panel = null
	deactivate_menu_state()
	manager.allotment_accepted(exe_order, random_history)


func _on_allotment_cancelled():
	random_panel.queue_free()
	random_panel = null
	deactivate_menu_state()


func _on_exchange_processed():
	if exchange_panel != null:
		exchange_panel.queue_free()
		exchange_panel = null


func _on_bot_turn_requested(_fake_delay, _crash_delay):
	# Timer wait_time was pre-configured in start_battle_scene /
	# start_battle_scene_reconnect — just start them.
	$BotFakeTimer.start()
	$BotCrashTimer.start()


func _on_bot_surrender_triggered():
	await get_tree().create_timer(2.0).timeout
	manager.end_match(true)


func _on_round_loop_started():
	if not $BotCrashTimer.is_stopped():
		$BotCrashTimer.stop()


func _on_match_ended(won):
	$BotFakeTimer.stop()
	$BotCrashTimer.stop()
	activate_menu_state()
	# Guard against a re-entered match_ended firing (e.g. a late MATCH_ENDED
	# event following an earlier local end_match): drop any existing panel
	# before minting a new one so the old instance doesn't get orphaned with
	# no reference left to free it through.
	_free_panel_now(game_end_panel)
	game_end_panel = null
	# Pass manager as the `battle` arg — it has match_type and save_player().
	# Integer enum values match BattleScene.Match so comparisons still work.
	game_end_panel = GameEndPanel.from_end_state(manager, won, manager.player, 1)
	game_end_panel.return_to_char_select.connect(_on_return_to_char_select)
	game_end_panel.save_replay.connect(_on_save_replay_requested)
	add_child(game_end_panel)


func _on_return_to_char_select():
	manager.return_to_char_select()


func _on_save_replay_requested():
	replay_save_requested.emit()


func _on_replay_saved():
	if game_end_panel != null and is_instance_valid(game_end_panel):
		game_end_panel.mark_replay_saved()


func _on_char_select_return(player_ref):
	reset_scene()
	char_select_return.emit(player_ref)

# ===========================================================================
# UI CREATION
# ===========================================================================

func create_test_interface():
	$Background.texture = load("res://assets/backgrounds/" + manager.player.equipped_ingame_background + ".png")
	player_profile = PlayerPanel.from_player(manager.player)
	enemy_profile = EnemyPanel.from_enemy(manager.enemy)
	profile_button_container.remove_child(system_column)
	profile_button_container.add_child(player_profile)
	profile_button_container.add_child(system_column)
	profile_button_container.add_child(enemy_profile)

	if not replay_mode:
		manager.player.team.energy.initialize_display()
		manager.player.team.energy.deploy_energy_display(system_column)
		if not spectator_mode:
			manager.player.team.energy.display.open_exchange_panel.connect(open_exchange_panel)

		manager.enemy.team.energy.initialize_display(spectator_mode)
		if spectator_mode:
			manager.enemy.team.energy.deploy_energy_display(system_column)

	if replay_mode:
		# Keep the button visible so the viewer can step through turns manually.
		turn_end_button.visible = true
		turn_end_button.stop_waiting()
		$UI/ProfileButtonRow/SystemColumn/MarginContainer/VBoxContainer/TurnEndButton/MarginContainer/Label.text = "Next Turn"
	elif spectator_mode:
		turn_end_button.visible = false

	var player_team_display = TeamDisplay.from_team(manager.player.team.characters)
	menu_container.add_child(player_team_display)
	var enemy_team_display = TeamDisplay.from_team(manager.enemy.team.characters, true)
	menu_container.add_child(enemy_team_display)

# ===========================================================================
# DESCRIPTION PANELS
# ===========================================================================

func describe_ability(user, ability):
	var panel = AbilityDescriptionPanel.from_description(user, ability)
	if description_panel != null:
		description_panel_container.remove_child(description_panel)
		description_panel.queue_free()
	description_panel = panel
	description_panel_container.add_child(panel)

func describe_character(user):
	var panel = CharacterInBattleDescription.from_character(user)
	if description_panel != null:
		description_panel_container.remove_child(description_panel)
		description_panel.queue_free()
	description_panel = panel
	description_panel.request_panel.connect(describe_ability)
	description_panel_container.add_child(panel)

# ===========================================================================
# ENERGY EXCHANGE UI
# ===========================================================================

func open_exchange_panel():
	if manager.player.team.energy.can_exchange() and not manager.waiting_for_turn:
		var panel = EnergyExchangePanel.new_panel(manager.player.team.energy.true_pool())
		panel.exchange_complete.connect(_on_exchange_complete)
		panel.exchange_cancelled.connect(_on_exchange_cancelled)
		exchange_panel = panel
		activate_menu_state()
		blotter.add_child(panel)

func _on_exchange_complete(offer, request):
	deactivate_menu_state()
	if manager.passive:
		energy_exchange_requested.emit(offer, request)
	else:
		manager.accept_exchange(offer, request)

func _on_exchange_cancelled():
	if exchange_panel != null:
		exchange_panel.queue_free()
		exchange_panel = null
	deactivate_menu_state()

# ===========================================================================
# SOUND
# ===========================================================================

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

# ===========================================================================
# MENU / BLOTTER STATE
# ===========================================================================

func activate_menu_state():
	menu_up = true
	blotter.visible = true

func deactivate_menu_state():
	menu_up = false
	blotter.visible = false

# ===========================================================================
# TOOLTIP PANELS
# ===========================================================================

func show_panel(tooltip, panel):
	panel.show_panel(self, tooltip)
	if panel is CanvasItem:
		panel.z_index = 200
	refreshing.connect(panel.hide_panel)
	tooltip.mouse_exited.connect(panel.hide_panel)

func hide_panel():
	info_panel.visible = false

# ===========================================================================
# TARGETING VISUALS
# ===========================================================================

func reset_targeting():
	manager.reset_character_targeted()


# ===========================================================================
# SCENE MANAGEMENT
# ===========================================================================

func hide_scene():
	visible = false

func show_scene():
	visible = true

func reset_scene():
	$BotFakeTimer.stop()
	$BotCrashTimer.stop()
	_reconnect_timer_remaining = 0.0
	spectator_mode = false
	replay_mode = false
	deactivate_menu_state()
	# Null the var after freeing so a second reset_scene call (the return path
	# hits this twice: once via _on_char_select_return, once via game.tscn's
	# char_select_return → return_to_char_select wiring) doesn't touch a freed
	# instance, and so start_battle_scene's defensive reset on requeue starts
	# from a clean slate.
	#
	# _free_panel_now unparents synchronously before queue_free, so the panel
	# stops rendering on the same frame — plain queue_free defers to end-of-
	# frame, which is too late if start_battle_scene paints the new match UI
	# in the same tick (the exact race that left "You lose..." visible on a
	# consecutive match).
	_free_panel_now(game_end_panel)
	game_end_panel = null
	_free_panel_now(random_panel)
	random_panel = null
	_free_panel_now(exchange_panel)
	exchange_panel = null
	var replay_node = get_node_or_null("ReplayPlayer")
	if replay_node:
		replay_node.pause_playback()
		replay_node.queue_free()
	# Type-sweep every direct child of BattleScene for any transient panel the
	# tracked vars might have missed (stale reference, orphaned from an earlier
	# double-creation, etc.). This is the safety net that catches the case where
	# a panel is in the tree but no var still points at it.
	_sweep_transient_panels()
	for node in menu_container.get_children():
		node.queue_free()
	for node in profile_button_container.get_children():
		if not node == system_column:
			node.queue_free()
	for node in system_column.get_children():
		if node is EnergyDisplay:
			system_column.remove_child(node)
	if description_panel != null:
		description_panel.visible = false


# Unparent synchronously, then queue_free for end-of-frame cleanup. The
# unparent is the important part — it's what stops the panel from continuing
# to render on the same frame. Safe to call with null or a freed instance.
func _free_panel_now(panel):
	if panel == null:
		return
	if not is_instance_valid(panel):
		return
	var parent = panel.get_parent()
	if parent != null:
		parent.remove_child(panel)
	panel.queue_free()


# Walk direct children of BattleScene and free any transient panel/blotter
# node that survived the var-based cleanup. Only these specific UI types are
# touched — permanent layout (BlotterContainer, profile_button_container,
# menu_container, timers, background) stays intact.
func _sweep_transient_panels():
	for node in get_children():
		if node is GameEndPanel or node is RandomPanel or node is EnergyExchangePanel:
			_free_panel_now(node)

# ===========================================================================
# SURRENDER UI
# ===========================================================================

func surrender_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		$PanelContainer.show()

func finish_surrender():
	print("Surrendering!")
	if not manager.enemy.bot_player:
		send_surrender.emit()
	manager.end_match(false)

func surrender_button_hover():
	$UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.hex(0xffffff88)

func surrender_button_stop_hover():
	$UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.WHITE

func surrender_yes_hovered() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer.modulate = Color.hex(0xffffff80)

func surrender_yes_hover_stopped() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer.modulate = Color.WHITE

func surrender_no_hovered() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2.modulate = Color.hex(0xffffff80)

func surrender_no_hover_stopped() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2.modulate = Color.WHITE

func surrender_yes_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		finish_surrender()
		$PanelContainer.hide()

func surrender_no_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		$PanelContainer.visible = false

# ===========================================================================
# AVATAR HANDLING
# ===========================================================================

func enemy_avatar_fetch_completed(result, response_code, headers, body):
	manager.enemy.avatar_fetch_completed(result, response_code, headers, body)
	enemy_profile.assign_player(manager.enemy)

# ===========================================================================
# TIMER CALLBACKS — timers live in the scene, logic lives in manager
# ===========================================================================

func bot_fake_timer_timeout():
	manager.bot_fake_timer_timeout()

func _on_bot_crash_timer_timeout():
	manager.bot_crash_timer_timeout()

func _on_delay_timer_timeout():
	manager.execution_loop_step()

func start_timer_w_timeout(timeout):
	var timer_timeout = func ():
		timeout.call()
	if $Timer.timeout.is_connected(current_timer_func):
		$Timer.timeout.disconnect(current_timer_func)
	current_timer_func = timer_timeout
	$Timer.timeout.connect(timer_timeout)
	$Timer.start()

# ===========================================================================
# INPUT FORWARDING
# ===========================================================================

func turn_end_clicked():
	if replay_mode:
		var replay_node = get_node_or_null("ReplayPlayer")
		if replay_node and not replay_node.is_at_end():
			replay_node.step_forward()
		return
	manager.turn_end_clicked()

func accept_player(inc_player):
	manager.player = inc_player

func accept_enemy(inc_enemy):
	manager.enemy = inc_enemy

func save_player():
	manager.save_player()

func package_match_report(won):
	return manager.package_match_report(won)

func stringify_gamestate():
	manager.stringify_gamestate()

func _on_panel_container_2_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		pass

func action_log_button_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		var log_box = get_node_or_null("MessageBoxComponent")
		if log_box != null and log_box.has_method("toggle_visibility"):
			log_box.toggle_visibility()

func action_log_button_hover():
	var btn = get_node_or_null("UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/ActionLogButton")
	if btn != null:
		btn.modulate = Color.hex(0xffffff88)

func action_log_button_stop_hover():
	var btn = get_node_or_null("UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/ActionLogButton")
	if btn != null:
		btn.modulate = Color.WHITE

# ===========================================================================
# FORWARDING METHODS — for any external code that calls methods on
# the BattleScene reference directly.
# ===========================================================================

func all_characters():
	return manager.all_characters()

func get_team_factions_from_character(character):
	return manager.get_team_factions_from_character(character)

func are_characters_hostile(first, second):
	return manager.are_characters_hostile(first, second)

func find_enemy_by_path(ref_character, path):
	return manager.find_enemy_by_path(ref_character, path)

func get_player_owner(character):
	return manager.get_player_owner(character)

func roll(min_val, max_val, desc = "None"):
	return manager.roll(min_val, max_val, desc)

func request_message(message):
	manager.request_message(message)

func demand_message(message):
	manager.demand_message(message)

func emit_log_event(event):
	manager.emit_log_event(event)

func set_log_paused(paused: bool):
	manager.set_log_paused(paused)

func _clear_action_log():
	var log_box = get_node_or_null("MessageBoxComponent")
	if log_box != null and log_box.has_method("clear_log"):
		log_box.clear_log()
	if manager != null:
		manager._current_turn_count = 0

func log_ability_use(user, ability):
	manager.log_ability_use(user, ability)

func log_damage(dealer, target, amount, damage_type, source_ability = null, source_effect = null):
	manager.log_damage(dealer, target, amount, damage_type, source_ability, source_effect)

func log_healing(healer, target, amount, source_ability = null, source_effect = null):
	manager.log_healing(healer, target, amount, source_ability, source_effect)

func log_effect_applied(applier, target, effect):
	manager.log_effect_applied(applier, target, effect)

func log_effect_expired(target, effect, reason: String = "expired"):
	manager.log_effect_expired(target, effect, reason)

func log_counter(actor):
	manager.log_counter(actor)

func log_reflect(actor):
	manager.log_reflect(actor)

func log_invuln_block(actor, target, ability = null):
	manager.log_invuln_block(actor, target, ability)

func log_miss(actor, target):
	manager.log_miss(actor, target)

func log_death(character):
	manager.log_death(character)

func log_revive(character):
	manager.log_revive(character)

func log_energy_gain(team, element_name: String):
	manager.log_energy_gain(team, element_name)

func log_turn_header(turn_number: int, who: String = ""):
	manager.log_turn_header(turn_number, who)

func log_system(text: String, demand: bool = false):
	manager.log_system(text, demand)

func generate_team_energy(team, first_turn=false):
	manager.generate_team_energy(team, first_turn)

func add_player_energy(energy_list):
	manager.add_player_energy(energy_list)
