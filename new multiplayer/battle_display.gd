## BattleDisplay: Client-side display layer for the battle system.
##
## This script manages all UI, sound, and visual presentation. It creates
## and owns a BattleManager internally for game logic, and connects to the
## manager's signals to drive the display.
##
## Attach this to the same scene tree structure as the original BattleScene
## (battle_scene.tscn) — it expects the same @export/@onready references.
##
## All user input flows through this class and is forwarded to the manager.
## All state changes from the manager flow back through signals and update the UI.

extends Control
class_name BattleDisplay

# ===========================================================================
# SCENE REFERENCES  (same layout as the original battle_scene.tscn)
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
# DISPLAY STATE
# ===========================================================================
var manager: BattleManager

var description_panel: PanelContainer
var player_profile
var enemy_profile
var game_end_panel = null
var menu_up: bool = false
var random_panel = null
var exchange_panel = null
var sharp_notification_playing: bool = false

var sounds: Dictionary = {
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
	"soft_clatter": load("res://assets/sounds/soft_clatter.mp3"),
	"panel_bop": load("res://assets/sounds/panel_bop.mp3"),
	"short_beep": load("res://assets/sounds/short_beep.mp3"),
	"sharp_notification": load("res://assets/sounds/sharp_notification.mp3"),
}

# Signals forwarded to the game/server layer
signal save_mission_progress(_player)
signal turn_ended(package)
signal match_ended(won)
signal char_select_return(player)
signal send_surrender()
signal send_save_player(_player)

# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready():
	_create_manager()


## Creates the BattleManager and wires up all signal connections.
func _create_manager():
	manager = BattleManager.new()
	manager.name = "BattleManager"
	add_child(manager)
	_connect_manager_signals()


func _connect_manager_signals():
	# Match lifecycle
	manager.battle_started.connect(_on_battle_started)
	manager.battle_reconnect_started.connect(_on_battle_reconnect_started)
	manager.match_ended.connect(_on_match_ended)

	# Turn flow
	manager.turn_started.connect(_on_turn_started)
	manager.waiting_for_opponent.connect(_on_waiting_for_opponent)
	manager.refreshing.connect(_on_refreshing)

	# Actions
	manager.character_action_confirmed.connect(_on_character_action_confirmed)
	manager.character_click_missed.connect(_on_character_click_missed)
	manager.action_cancelled.connect(_on_action_cancelled)

	# Messages
	manager.message_request.connect(_on_message_request)
	manager.message_demand.connect(_on_message_demand)

	# Energy / panels
	manager.random_panel_needed.connect(_on_random_panel_needed)
	manager.exchange_processed.connect(_on_exchange_processed)

	# Turn packages (forward to server)
	manager.turn_package_ready.connect(_on_turn_package_ready)
	manager.send_surrender.connect(_on_send_surrender)

	# Bot
	manager.bot_turn_requested.connect(_on_bot_turn_requested)
	manager.bot_surrender_triggered.connect(_on_bot_surrender_triggered)

	# Persistence / navigation
	manager.save_mission_progress_requested.connect(func(p): save_mission_progress.emit(p))
	manager.save_player_requested.connect(func(p): send_save_player.emit(p))
	manager.char_select_return_requested.connect(_on_char_select_return)
	manager.match_report_ready.connect(func(won, pkg): match_ended.emit(pkg))

	# Round
	manager.round_loop_started.connect(_on_round_loop_started)

# ===========================================================================
# PUBLIC ENTRY POINTS — called by game.gd / server_connection.gd
# ===========================================================================

## Start a new battle. Replaces the old start_battle_scene().
func start_battle_scene(nplayer, nenemy, first: bool, seed: int, m_type, canonical_role: int = 0):
	sharp_notification_playing = true
	play_sound("sharp_notification")
	manager.start_battle(nplayer, nenemy, first, seed, m_type, canonical_role)


## Reconnection entry point. Replaces start_battle_scene_reconnect().
func start_battle_scene_reconnect(nplayer, nenemy, snapshot: Dictionary, m_type, canonical_role: int = 0):
	sharp_notification_playing = true
	play_sound("sharp_notification")
	manager.start_battle_reconnect(nplayer, nenemy, snapshot, m_type, canonical_role)


## Receive a turn package from the opponent (via server).
func receive_turn_package(package: Dictionary):
	manager.receive_turn_package(package)


## Opponent surrendered.
func receive_surrender():
	manager.receive_surrender()

# ===========================================================================
# MANAGER SIGNAL HANDLERS
# ===========================================================================

func _on_battle_started(first: bool):
	# Set up bot timer durations
	$BotFakeTimer.wait_time = randi_range(8, 16)
	$BotCrashTimer.wait_time = $BotFakeTimer.wait_time + 2

	# Fetch enemy avatar
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_enemy_avatar_fetch_completed)
	http_request.request(manager.enemy.avatar_url)

	create_test_interface()
	describe_character(manager.all_characters()[0])


func _on_battle_reconnect_started(_snapshot: Dictionary):
	$BotFakeTimer.wait_time = manager.player.bot_turn_delay
	$BotCrashTimer.wait_time = manager.player.bot_turn_delay + 2

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_enemy_avatar_fetch_completed)
	http_request.request(manager.enemy.avatar_url)

	create_test_interface()
	describe_character(manager.all_characters()[0])


func _on_turn_started(_is_player_turn: bool):
	if not sharp_notification_playing:
		play_sound("start_turn")
	else:
		sharp_notification_playing = false
	timer_bar.stop_timer()
	timer_bar.start_timer()
	turn_end_button.stop_waiting()


func _on_waiting_for_opponent():
	if not sharp_notification_playing:
		play_sound("start_turn")
	else:
		sharp_notification_playing = false
	timer_bar.stop_timer()
	timer_bar.start_timer()
	turn_end_button.set_waiting()


func _on_refreshing():
	pass  # Additional display refresh logic if needed


func _on_character_action_confirmed(_character):
	$Sound.volume_db = -20
	play_sound("big_click")
	$Sound.volume_db = -10


func _on_character_click_missed():
	play_sound("click")


func _on_action_cancelled(_character):
	play_sound("undo")


func _on_message_request(message: String):
	$MessageBoxComponent.show_message(message) if has_node("MessageBoxComponent") else print(message)


func _on_message_demand(message: String):
	$MessageBoxComponent.show_message(message) if has_node("MessageBoxComponent") else print(message)


func _on_random_panel_needed(team, random_count, exec_order: Dictionary):
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


func _on_turn_package_ready(package: Dictionary):
	turn_ended.emit(package)


func _on_send_surrender():
	send_surrender.emit()


func _on_bot_turn_requested(fake_delay: float, _crash_delay: float):
	$BotFakeTimer.wait_time = fake_delay
	$BotCrashTimer.wait_time = fake_delay + 2
	$BotFakeTimer.start()
	$BotCrashTimer.start()


func _on_bot_surrender_triggered():
	await get_tree().create_timer(2.0).timeout
	manager.end_match(true)


func _on_round_loop_started():
	if not $BotCrashTimer.is_stopped():
		$BotCrashTimer.stop()


func _on_match_ended(won: bool):
	$BotFakeTimer.stop()
	$BotCrashTimer.stop()
	activate_menu_state()
	# Pass manager as the `battle` argument — it has match_type and save_player().
	# The enum integer values match BattleScene.Match so comparisons still work.
	game_end_panel = GameEndPanel.from_end_state(manager, won, manager.player, 1)
	game_end_panel.return_to_char_select.connect(_on_return_to_char_select)
	add_child(game_end_panel)


func _on_char_select_return(player_ref):
	reset_scene()
	char_select_return.emit(player_ref)


func _on_return_to_char_select():
	manager.return_to_char_select()

# ===========================================================================
# DISPLAY-ONLY CHARACTER CONNECTIONS
# ===========================================================================

## Connect the display-relevant signals from each character.
## Called after the manager has connected its own logic signals via
## character.startup() → manager.connect_character().
func connect_character_display(char):
	char.ability_selected.connect(describe_ability)
	char.character_selected.connect(describe_character)
	char.finished_targeting.connect(reset_targeting)
	char.hide_panel.connect(hide_panel)
	char.cancel_action.connect(func(_c): play_sound("undo"))

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

	manager.player.team.energy.initialize_display()
	manager.player.team.energy.deploy_energy_display(system_column)
	manager.player.team.energy.display.open_exchange_panel.connect(open_exchange_panel)

	manager.enemy.team.energy.initialize_display(true)

	var player_team_display = TeamDisplay.from_team(manager.player.team.characters)
	menu_container.add_child(player_team_display)

	var enemy_team_display = TeamDisplay.from_team(manager.enemy.team.characters, true)
	menu_container.add_child(enemy_team_display)

	# Connect display signals for all characters
	for character in manager.all_characters():
		connect_character_display(character)

# ===========================================================================
# DESCRIPTION PANELS
# ===========================================================================

func describe_ability(_user, ability):
	var panel = AbilityDescriptionPanel.from_description(_user, ability)
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
	manager.accept_exchange(offer, request)


func _on_exchange_cancelled():
	if exchange_panel != null:
		exchange_panel.queue_free()
		exchange_panel = null
	deactivate_menu_state()

# ===========================================================================
# SOUND
# ===========================================================================

func play_sound(sound_name: String):
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
	manager.refreshing.connect(panel.hide_panel)
	tooltip.mouse_exited.connect(panel.hide_panel)


func hide_panel():
	info_panel.visible = false

# ===========================================================================
# TARGETING VISUALS
# ===========================================================================

func reset_targeting():
	manager.reset_character_targeted()
	for character in manager.all_characters():
		character.update.emit()

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
	deactivate_menu_state()
	if not game_end_panel == null:
		game_end_panel.queue_free()
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

func _on_enemy_avatar_fetch_completed(result, response_code, headers, body):
	manager.enemy.avatar_fetch_completed(result, response_code, headers, body)
	enemy_profile.assign_player(manager.enemy)

# ===========================================================================
# TIMER CALLBACKS — forward to manager
# ===========================================================================

func bot_fake_timer_timeout():
	manager.bot_fake_timer_timeout()


func _on_bot_crash_timer_timeout():
	manager.bot_crash_timer_timeout()


func _on_delay_timer_timeout():
	manager.execution_loop_step()


func start_timer_w_timeout(timeout):
	var timer_timeout = func():
		timeout.call()
	if $Timer.timeout.is_connected(_current_timer_func):
		$Timer.timeout.disconnect(_current_timer_func)
	_current_timer_func = timer_timeout
	$Timer.timeout.connect(timer_timeout)
	$Timer.start()

var _current_timer_func = func(): pass

# ===========================================================================
# INPUT FORWARDING
# ===========================================================================

## Called when "End Turn" button is clicked.
func turn_end_clicked():
	manager.turn_end_clicked()


## Called when the debug pretty-print button is clicked.
func stringify_gamestate():
	manager.stringify_gamestate()


## Forwarded from game.gd for player/enemy setup.
func accept_player(inc_player):
	manager.player = inc_player


func accept_enemy(inc_enemy):
	manager.enemy = inc_enemy


func _on_panel_container_2_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		pass


func save_player():
	manager.save_player()


func package_match_report(won: bool):
	return manager.package_match_report(won)

# ===========================================================================
# CONVENIENCE ACCESSORS — so external code can still reach common state
# through the display without knowing about the manager.
# ===========================================================================

func get_player():
	return manager.player if manager else null

func get_enemy():
	return manager.enemy if manager else null

func get_gamestate():
	return manager.gamestate if manager else BattleManager.Gamestate.CLOSED

func get_match_type():
	return manager.match_type if manager else BattleManager.MatchType.QUICK

func is_waiting_for_turn() -> bool:
	return manager.waiting_for_turn if manager else false

func is_match_over() -> bool:
	return manager.match_over if manager else false

func is_reconnecting() -> bool:
	return manager.reconnecting if manager else false

func get_match_statistics():
	return manager.match_statistics if manager else null

func all_characters() -> Array:
	return manager.all_characters() if manager else []

func get_team_factions_from_character(character) -> Array:
	return manager.get_team_factions_from_character(character)

func are_characters_hostile(first, second) -> bool:
	return manager.are_characters_hostile(first, second)

func find_enemy_by_path(ref_character, path):
	return manager.find_enemy_by_path(ref_character, path)

func roll(min_val: int, max_val: int, desc: String = "None") -> int:
	return manager.roll(min_val, max_val, desc)

func request_message(message: String):
	manager.request_message(message)

func demand_message(message: String):
	manager.demand_message(message)

func get_player_owner(character):
	return manager.get_player_owner(character)
