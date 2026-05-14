## Test script for the decoupled BattleScene + BattleManager architecture.
##
## Creates two players with random 3-character teams and launches a bot match.
##
## Setup (pick one):
##
##   A) Minimal — create a scene with just a Node root, attach this script,
##      and run it. The script auto-instances battle_scene.tscn.
##
##   B) Inspector — create a scene, add a BattleScene child (instance
##      battle_scene.tscn), attach this script to the root, and wire the
##      `battle_scene` export in the inspector.
##
##   C) Code — call TestBattle.quick_start() from any other script.

extends Control
class_name TestBattle

@export var battle_scene: BattleScene

## How many characters each team gets.
const TEAM_SIZE := 3

## Set true to let the bot auto-play against itself (both sides are bots).
@export var both_bots := false

## Set true to print a turn-by-turn log to the console.
@export var verbose := true

## Optional: lock the character pool to specific names.
## Leave empty to pick randomly from the full roster.
@export var player_team_override: Array[String] = []
@export var enemy_team_override: Array[String] = []


func _ready():
	# Auto-instance the battle scene if none was assigned in the inspector
	if battle_scene == null:
		var scene_resource = load("res://scenes/battle_scene.tscn")
		if scene_resource == null:
			push_error("test_battle: Could not load res://scenes/battle_scene.tscn")
			return
		battle_scene = scene_resource.instantiate()
		add_child(battle_scene)

	run_test()


## Convenience factory — call from any script to launch a test match.
## Returns the TestBattle node (already in the tree).
static func quick_start(parent: Node, player_names: Array[String] = [], enemy_names: Array[String] = []) -> TestBattle:
	var test := TestBattle.new()
	test.player_team_override = player_names
	test.enemy_team_override = enemy_names
	parent.add_child(test)
	return test


# ===========================================================================
# CORE TEST LOGIC
# ===========================================================================

func run_test():
	var player_chars := _pick_team(player_team_override)
	var enemy_chars := _pick_team(enemy_team_override, player_chars)

	if verbose:
		print("")
		print("========================================")
		print("         TEST BATTLE START")
		print("========================================")
		print("Player team: ", _format_names(player_chars))
		print("Enemy team:  ", _format_names(enemy_chars))

	var player_obj := _build_player("TestPlayer", player_chars, false)
	var enemy_obj := _build_player("BotEnemy", enemy_chars, true)

	# Randomise who goes first
	var seed_val := randi()
	var first := bool(randi() % 2)

	if verbose:
		print("Seed: %d | First move: %s" % [seed_val, "Player" if first else "Enemy"])
		print("========================================")
		print("")

	# Connect debug logging before the battle starts
	if verbose:
		_connect_logging()

	battle_scene.visible = true
	battle_scene.show_scene()
	battle_scene.start_battle_scene(
		player_obj, enemy_obj, first, seed_val, BattleScene.Match.BOT
	)


# ===========================================================================
# TEAM BUILDING
# ===========================================================================

## Picks TEAM_SIZE character names. Uses overrides if provided, otherwise
## draws randomly from the full roster (excluding `exclude`).
func _pick_team(overrides: Array[String], exclude: Array[String] = []) -> Array[String]:
	if overrides.size() >= TEAM_SIZE:
		return overrides.slice(0, TEAM_SIZE)

	var pool = CharacterDatabase.char_name_list().duplicate()
	# Remove any already-claimed names
	for name in exclude:
		pool.erase(name)
	for name in overrides:
		pool.erase(name)
	pool.shuffle()

	var result: Array[String] = overrides.duplicate()
	while result.size() < TEAM_SIZE and pool.size() > 0:
		result.append(pool.pop_back())
	return result


## Creates a fully-wired Player node ready for battle.
func _build_player(username: String, char_names: Array[String], is_bot: bool) -> Player:
	var player: Player = load("res://components/player_component.tscn").instantiate()
	player.username = username
	player.set_username(username)
	player.mission_reference = {}
	player.mission_data = {}
	player.bot_player = is_bot

	if is_bot or both_bots:
		player.bot_player = true
		player.bot_difficulty = 70
		player.bot_turn_delay = randi_range(4, 10)

	for char_name in char_names:
		var character = Character.from_character_name(char_name)
		player.recruit_character(character, is_bot)

	return player


# ===========================================================================
# DEBUG LOGGING
# ===========================================================================

func _connect_logging():
	# Manager is created in BattleScene._ready(), which fires when the
	# scene enters the tree — so it should exist by now.
	if battle_scene.manager == null:
		push_warning("test_battle: manager not ready; logging skipped.")
		return

	var mgr := battle_scene.manager

	mgr.turn_started.connect(func(_p):
		print("[turn]  Player's turn started")
	)
	mgr.waiting_for_opponent.connect(func():
		print("[turn]  Waiting for opponent (bot will act)...")
	)
	mgr.message_request.connect(func(msg):
		print("[msg]   ", msg)
	)
	mgr.ability_will_execute.connect(func(character, ability):
		print("[exec]  %s used %s" % [character.character_name, ability.ability_name])
	)
	mgr.ticking_effect_will_execute.connect(func(effect):
		print("[tick]  %s's %s ticking on %s" % [
			effect.user.character_name,
			effect.source.ability_name,
			effect.target.character_name
		])
	)
	mgr.match_ended.connect(func(won):
		print("")
		print("========================================")
		if won:
			print("  RESULT: Player wins!")
		else:
			print("  RESULT: Player loses.")
		_print_health_summary(mgr)
		print("========================================")
		print("")
	)
	mgr.bot_turn_requested.connect(func(delay, _c):
		print("[bot]   Bot timer started (%ds)" % delay)
	)
	mgr.round_loop_started.connect(func():
		print("[exec]  --- Round execution begins ---")
	)
	mgr.action_cancelled.connect(func(character):
		print("[undo]  %s cancelled action" % character.character_name)
	)
	mgr.random_panel_needed.connect(func(_team, _rc, _eo):
		print("[panel] Random energy allocation panel opened")
	)


func _print_health_summary(mgr: BattleManager):
	print("  -- Player team --")
	for c in mgr.player.team.characters:
		var status := "DEAD" if c.dead else ("BANISHED" if c.banished else "%dHP" % c.health.hp)
		print("     %s: %s" % [c.character_name, status])
	print("  -- Enemy team --")
	for c in mgr.enemy.team.characters:
		var status := "DEAD" if c.dead else ("BANISHED" if c.banished else "%dHP" % c.health.hp)
		print("     %s: %s" % [c.character_name, status])


# ===========================================================================
# HELPERS
# ===========================================================================

func _format_names(names: Array[String]) -> String:
	return ", ".join(names)
