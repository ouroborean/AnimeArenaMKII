extends Node
class_name Battle

var player
var enemy

var random = RandomNumberGenerator.new()
var die = RandomNumberGenerator.new()

enum Match {
	PRIVATE,
	QUICK,
	BOT,
	RANKED
}
enum Gamestate {
	LOADING,
	OPEN,
	RESOLVING,
	CLOSED,
	TARGETING
}
var gamestate = Gamestate.LOADING
var match_type
var went_second = false
var waiting_for_turn = false
var match_over = false

func _ready():
	print("Starting Battle!")
	var mock_player = get_mock_player()
	var mock_enemy = get_mock_enemy()
	start_battle(mock_player, mock_enemy, 5692, Match.PRIVATE, true)

func get_mock_player():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Player 1")
	player.avatar_texture = load("res://assets/avatars/angywendy.png")
	var building_team = ["naruto", "sasuke", "sakura"]
	for char_name in building_team:
		player.recruit_character(Character.from_character_name(char_name), true)
	return player

func get_mock_enemy():
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("Player 2")
	player.avatar_texture = load("res://assets/avatars/angywendy.png")
	var building_team = ["luffy", "zoro", "usopp"]
	for char_name in building_team:
		player.recruit_character(Character.from_character_name(char_name), true)
	return player

func assign_player(_player):
	player = _player

func assign_enemy(_enemy):
	enemy = _enemy

func set_seed(_seed):
	die.set_seed(_seed)

func set_match_type(_match_type):
	match_type = _match_type

func connect_character(character):
	pass

func get_team_factions_from_character(character):
	if character in player.team.characters:
		return [player.team, enemy.team]
	else:
		return [enemy.team, player.team]

func start_battle(_player, _enemy, _seed, _match_type, first):
	assign_player(_player)
	assign_enemy(_enemy)
	set_seed(_seed)
	set_match_type(_match_type)
	print("Assigned starting properties!")
	_player.team.instantiate_energy_pool()
	_enemy.team.instantiate_energy_pool()
	print("Instantiated energy pools!")
	#_player.set_mission_diff()
	
	for character in all_characters():
		character.initialize(true)
	print("Initialized Characters")
	print("Match initialized!")
	for character in all_characters():
		character.startup(self)
	print("Ran character startup")
	var semis = []
	
	for character in all_characters():
		if character.path_name == "semiramis":
			semis.append(character)
			continue
		character.startup_passives(self)
	print("Started character passives")
	for semiramis in semis:
		print("Starting a Semiramis passive")
		semiramis.startup_passives(self)
		
	for character in player.team.characters:
		for mission_id in player.mission_reference.keys():
			var mission = player.mission_reference[mission_id]
			mission.assign(character, player)
	print("Assigned missions")
	if not first:
		print("Player going second! Beginning wait.")
		went_second = true
		wait_for_turn()
	else:
		print("Player going first! Starting first turn.")
		start_new_turn(true)

func all_characters():
	return player.team.characters + enemy.team.characters

func roll(min, max, desc = "None"):
	var result = die.randi_range(min, max)
	return result

func wait_for_turn():
	print("Player waiting for turn")
	gamestate = Gamestate.CLOSED
	waiting_for_turn = true
	for character in player.team.characters:
		character.waiting = true
	for character in all_characters():
		character.refresh()

func start_new_turn(first_turn = false):
	print("Player starting their turn!")
	gamestate = Gamestate.OPEN
	waiting_for_turn = false
	for character in player.team.characters:
		character.waiting = false
	for character in player.team.characters:
		character.check_start_of_turn_triggers(self)
	for character in enemy.team.characters:
		character.check_start_of_turn_triggers(self)
	generate_team_energy(player.team, first_turn)

func generate_team_energy(team, first_turn=false):
	print("Generating energy")
	var energy_list = []
	if not first_turn:
		for char in team.characters:
			if not char.dead and not char.banished and not char.sleepy_frieren():
				energy_list += char.generate_energy()
	else:
		var roll = roll(0, 3)
		energy_list.append(Energy.Type[Energy.Type.keys()[roll]])
	for energy in energy_list:
		team.change_energy(energy, 1)

func bot_turn():
	if match_over:
		return
	generate_team_energy(enemy.team, went_second)
	went_second = false
	enemy.perform_turn(self)

func receive_ability_use_request(character, ability):
	if character.enemy:
		return
	if gamestate == Gamestate.CLOSED:
		return
	
	if ability.usable(character) and ability.extra_usable(character):
		character.targeter.start_targeting(ability)
		ability.target(character, self)
