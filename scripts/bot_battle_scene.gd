extends Control

var player
var enemy

var random = RandomNumberGenerator.new()
@export var menu_container: HBoxContainer
@export var system_column: VBoxContainer
@export var profile_button_container: HBoxContainer
@export var info_panel: EffectTooltipHoverPanel
@onready var blotter = $BlotterContainer
@export var description_panel_container: MarginContainer
@export var turn_end_button: PanelContainer
@export var timer_bar: TimerBar
var records = {
	
}
var description_panel: PanelContainer
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
var player_profile
var enemy_profile
var game_end_panel = null
var gamestate = Gamestate.CLOSED
var match_type = Match.QUICK
var menu_up = false
var action_order = []
var ticking_order = []
var ticking_character_order = []
var random_panel
var exchange_panel
var went_second = false
var current_timer_func = func (): pass
var waiting_for_turn = false
var execution_order = {}
var last_exchange = null
var die = RandomNumberGenerator.new()
signal save_mission_progress(_player)
signal refreshing()
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
var sharp_notification_playing = false
var match_over = false
var true_execution_order = []
var reconnecting = false
signal character_clicked(character)
signal message_request(message)
signal message_demand(message)
signal log_event(event)
signal turn_ended(package)
signal match_ended(won)
signal char_select_return(player)
signal send_surrender()
signal send_save_player(_player)

var test_count = 0

var char_name_list = [
		"naruto",
		"sasuke",
		"sakura",
		"hinata",
		"hashirama",
		"boruto",
		"itachi",
		"luffy",
		"zoro",
		"usopp",
		"ace",
		"marco",
		"rob",
		"yuji",
		"nobara",
		"megumi",
		"sukuna",
		"midoriya",
		"uraraka",
		"bakugo",
		"toga",
		"natsu",
		"lucy",
		"gray",
		"erza",
		"mavis",
		"madoka",
		"sayaka",
		"mami",
		"asta",
		"yuno",
		"noelle",
		"maka",
		"soul",
		"blackstar",
		"tsubaki",
		"crona",
		"aang",
		"toph",
		"korra",
		"tatsumi",
		"akame",
		"sheele",
		"tanjiro",
		"nezuko",
		"zenitsu",
		"inosuke",
		"rengoku",
		"muichiro",
		"meliodas",
		"diane",
		"king",
		"ban",
		"tsunayoshi",
		"yamamoto",
		"ryohei",
		"squalo",
		"xanxus",
		"eren",
		"mikasa",
		"saitama",
		"genos",
		"tatsumaki",
		"shinra",
		"tamaki",
		"gon",
		"killua",
		"kurapika",
		"hisoka",
		"neferpitou",
		"misaka",
		"kuroko",
		"gunha",
		"shokuhou",
		"emiya",
		"saber",
		"gilgamesh",
		"emiyaarcher",
		"jack",
		"semiramis",
		"frankenstein",
		"mash",
		"ryuko",
		"satsuki",
		"nonon",
		"ichigo",
		"byakuya",
		"nimaiya",
		"ganta",
		"shiro",
		"ken",
		"touka",
		"rimuru",
		"edward",
		"alphonse",
		"goku",
		"vegeta",
		"gohan",
		"gogeta",
		"gatomon",
		"hawkmon",
		"renamon",
		"myotismon",
		"machinedramon",
		"gallantmon",
		"omnimon",
		"nagisa",
		"koro",
		"mars",
		"jupiter",
		"saturn",
		"frieren",
		"megumin",
		"inuyasha",
		"shinoa"
	]

var test_targets = ["zoro", "sayaka", "machinedramon"]

func group_into_random_threes(input_list: Array) -> Array:
	var pool = input_list.duplicate()
	pool.shuffle()
	
	var groups = []
	
	# 1. Create unique sets of 3 from the pool
	while pool.size() >= 3:
		groups.append([pool.pop_back(), pool.pop_back(), pool.pop_back()])
	
	# 2. Handle leftover items or odd group counts
	if pool.size() > 0 or groups.size() % 2 != 0:
		var final_set = []
		
		# Use remaining unique items first
		while pool.size() > 0:
			final_set.append(pool.pop_back())
			
		# Fill the rest of the set with random repeats if needed
		while final_set.size() < 3:
			final_set.append(input_list.pick_random())
			
		groups.append(final_set)
	
	# 3. If groups are still odd, add one more set using repeats to make it even
	if groups.size() % 2 != 0:
		var extra_set = []
		for i in range(3):
			extra_set.append(input_list.pick_random())
		groups.append(extra_set)
	print(groups)
	return groups

var groups = []

var win_record = {}
var loss_record = {}

func make_crazy_bot(force=[]):
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username("cr4zy 1ns4n0")
	player.bot_player = true
	player.avatar_texture = load("res://assets/avatars/angywendy.png")
	var building_team = []
	for char_name in force:
		building_team.append(char_name)
	if len(groups) > 0:
		building_team = groups.pop_front()
	while len(building_team) < 3:
		var roll = randi_range(0, len(char_name_list) - 1)
		if not char_name_list[roll] in building_team:
			building_team.append(char_name_list[roll])
	for char_name in building_team:
		player.recruit_character(Character.from_character_name(char_name), true)
	for character in player.team.characters:
		character.bot_character = true
	return player

# Called when the node enters the scene tree for the first time.
func _ready():
	#groups = group_into_random_threes(char_name_list)
	var log_box = get_node_or_null("MessageBoxComponent")
	if log_box != null and log_box.has_method("bind_battle"):
		log_box.bind_battle(self)
		move_child(log_box, get_child_count() - 1)
	launch_test_battle()
	
func launch_test_battle():
	var bot1 = make_crazy_bot(test_targets)
	var bot2 = make_crazy_bot()
	start_battle_scene(bot1, bot2, true, randi_range(1, 10000000), 0)

func hide_scene():
	visible = false

func show_scene():
	visible = true

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()



func wait_for_turn():
	waiting_for_turn = true
	execution_order = {}
	true_execution_order = []
	for character in all_characters():
		character.refresh()
	gamestate = Gamestate.CLOSED
	log_turn_header(_current_turn_count + 1)
	generate_team_energy(enemy.team)
	enemy.perform_turn(self)

func bot_fake_timer_timeout():
	if match_over:
		return
	generate_team_energy(enemy.team, went_second)
	went_second = false
	enemy.perform_turn(self)

func show_panel(tooltip, panel):
	panel.show_panel(self, tooltip)
	if panel is CanvasItem:
		panel.z_index = 200
	refreshing.connect(panel.hide_panel)
	tooltip.mouse_exited.connect(panel.hide_panel)

func enemy_avatar_fetch_completed(result, response_code, headers, body):
	enemy.avatar_fetch_completed(result, response_code, headers, body)
	enemy_profile.assign_player(enemy)

func restart_test_scene():
	remove_child(player)
	remove_child(enemy)
	launch_test_battle()

func update_bot_records(win_record: Dictionary, loss_record: Dictionary):
	var path = "res://bot_records.json"
	var data = {"wins": {}, "losses": {}, "ratios": {}}
	
	# 1. Load existing data
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_helper = JSON.new()
		if json_helper.parse(file.get_as_text()) == OK:
			data = json_helper.data
	
	# 2. Merge Wins and Losses
	for name in win_record:
		data["wins"][name] = data["wins"].get(name, 0) + win_record[name]
	for name in loss_record:
		data["losses"][name] = data["losses"].get(name, 0) + loss_record[name]
	if not "ratios" in data:
		data["ratios"] = {}
	# 3. Update Ratios for all affected entries
	var all_names = win_record.keys()
	for n in loss_record.keys(): 
		if not all_names.has(n): all_names.append(n)

	for name in all_names:
		var w = float(data["wins"].get(name, 0))
		var l = float(data["losses"].get(name, 0))
		data["ratios"][name] = snapped(w / (w + l), 0.01) if (w + l) > 0 else 0.0

	# 4. Save
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(data, "\t"))
	win_record.clear()
	loss_record.clear()

func start_battle_scene(nplayer, nenemy, first, seed, m_type):

	_clear_action_log()
	_current_turn_count = 0
	match_type = m_type
	die.set_seed(seed)
	player = nplayer


	add_child(player)
	enemy = nenemy
	add_child(enemy)

	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)

	for character in all_characters():
		character.startup(self)

	create_test_interface()

	var semis = []

	for character in all_characters():
		if character.path_name == "semiramis":
			semis.append(character)
			continue
		character.startup_passives(self)

	for semiramis in semis:
		semiramis.startup_passives(self)
	set_log_paused(false)
	start_new_turn(true)
	

func process_turn_package(package, first = false, last = false):
	var team = player.team
	var team_mod = 0
	if waiting_for_turn:
		team = enemy.team
		team_mod = 3
	if team_mod == 3:
		log_turn_header(_current_turn_count + 1)
	if package['timeout']:
		if team_mod == 3:
			if last:
				reconnecting = false
			handle_opponent_timeout()
			return
		generate_team_energy(team, first)
		if last:
			reconnecting = false
		handle_timeout()
		return
	
	generate_team_energy(team, first)
	if went_second:
		went_second = false

	var character_actions = package['character_actions']
	for action_set in character_actions:
		var index_of_character = action_set[0] + team_mod #because the team positions are opposite
		var char = all_characters()[index_of_character]
		var index_of_ability = action_set[1]
		var used_ability = char.moveset.get_active_abilities(char)[index_of_ability]
		team.pay_for_ability(used_ability)
		char.used_ability = used_ability
		char.acted = true
		var target_indexes = action_set[2]
		for target in target_indexes:
			#Perform position reversal
			if team_mod == 3:
				if target > 2:
					target -= 3
				else:
					target += 3
			char.targeter.add_target(all_characters()[target])
		
		var ttype = used_ability.target_type()
		if char.blind_check():
			if ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION or ttype == TargetType.Type.SELF:
				pass
			else:
				used_ability.ability_blinded = true
		execution_order[action_set[0]] = char.used_ability
	if not team_mod == 3:
		team.energy.receive_generic_allocation_offer(package['random_history'], true)
	var ticking_information = get_ticking_effect_information(team_mod == 3)
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority < b.twin_priority)
		execution_order[key] = ticking_information[key]
	true_execution_order = package['execution_order']
	if last:
		reconnecting = false
	start_round_loop()


func connect_character(char):
	char.ability_selected.connect(receive_ability_use_request)
	char.character_selected.connect(receive_character_use_request)
	char.finished_targeting.connect(reset_targeting)
	char.request_aoe_targets.connect(get_other_aoe_targets)
	char.request_random_targets.connect(get_valid_random_targets)
	char.cancel_action.connect(cancel_action)
	character_clicked.connect(char.other_character_clicked)

func cancel_action(character):
	play_sound("undo")
	action_order.erase(character)
	reset_character_targeted()
	for char in all_characters():
		character.update.emit()

func add_player_energy(energy_list):
	for energy in energy_list:
		player.team.change_energy(energy, 1)



func generate_team_energy(team, first_turn=false):
	var energy_list = []
	if not first_turn:
		for char in team.characters:
			if not char.dead and not char.banished and not char.sleepy_frieren():
				energy_list += char.generate_energy()
	else:
		var roll = roll(0, 3, "Generate 1-off first turn energy")
		energy_list.append(Energy.Type[Energy.Type.keys()[roll]])
	for energy in energy_list:
		team.change_energy(energy, 1)


func full_startup():
	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)
		character.startup(self)
		character.startup_passives(self)
	set_log_paused(false)

func create_test_interface():
	for child in menu_container.get_children():
		child.queue_free()
	var player_team_display = TeamDisplay.from_team(player.team.characters)
	
	menu_container.add_child(player_team_display)
	var enemy_team_display = TeamDisplay.from_team(enemy.team.characters, true)
	
	menu_container.add_child(enemy_team_display)
	


func get_used_ability_information():
	var output = {}
	for character in action_order:
		if character.used_ability != null:
			output[player.team.characters.find(character)] = character.used_ability
		else:
			output.erase(player.team.characters.find(character))
	return output

func get_ticking_effect_information(is_enemy=false):
	var exclusion_check = {}
	var output = {}
	var counter = 3
	var acting_team = player.team.characters
	var enemy_team = enemy.team.characters
	if is_enemy:
		acting_team = enemy.team.characters
		enemy_team = player.team.characters
	#For each character in the match,
	for character in acting_team:
		#Get all that character's ticking effects.
		var ticking_effects = get_ticking_effects(character, is_enemy)
		#For each of those ticking effects,
		for effect in ticking_effects:
			#Get its origin (Source name, effect type, and creation ID).
			var origin = [effect.source.ability_name, effect.effect_type, effect.id]
			#If that origin has already been seen before (is inside the exclusion check dictionary),
			if origin in exclusion_check.values():
				#Find the counter key that it was first seen with by checking exclusion_check's values.
				var index_of_match = exclusion_check.values().find(origin)
				var key_match = exclusion_check.keys()[index_of_match]
				#Add that effect to the output position that matched its origin, so it can be triggered
				#along with the other effects that match its origin.
				output[key_match].append(effect)
			#otherwise,
			else:
				#Add this new effect to the output dictionary using its current execution order position as
				#its key, and add its origin to the exclusion check dictionary so we can prepare to
				#capture its sibling effects.
				output[counter] = [effect]
				exclusion_check[counter] = origin
				#Increment the counter
				counter += 1
	for character in enemy_team:
		#Get all that character's ticking effects.
		var ticking_effects = get_ticking_effects(character, is_enemy)
		#For each of those ticking effects,
		for effect in ticking_effects:
			#Get its origin (Source name, effect type, and creation ID).
			var origin = [effect.source.ability_name, effect.effect_type, effect.id]
			#If that origin has already been seen before (is inside the exclusion check dictionary),
			if origin in exclusion_check.values():
				#Find the counter key that it was first seen with by checking exclusion_check's values.
				var index_of_match = exclusion_check.values().find(origin)
				var key_match = exclusion_check.keys()[index_of_match]
				#Add that effect to the output position that matched its origin, so it can be triggered
				#along with the other effects that match its origin.
				output[key_match].append(effect)
			#otherwise,
			else:
				#Add this new effect to the output dictionary using its current execution order position as
				#its key, and add its origin to the exclusion check dictionary so we can prepare to
				#capture its sibling effects.
				output[counter] = [effect]
				exclusion_check[counter] = origin
				#Increment the counter
				counter += 1

	
	return output


func package_round_information(random_history):
	
	var round_package = {}
	
	var character_actions = []
	for character in player.team.characters:
		if character.used_ability != null:
			var targets = []
			for target in character.targeter.targets:
				targets.append(all_characters().find(target))
			character_actions.append( [player.team.characters.find(character), character.moveset.get_active_abilities(character).find(character.used_ability), targets] )
	print("Packaging random history: ")
	print(str(random_history))
	round_package['random_history'] = random_history
	round_package['character_actions'] = character_actions
	round_package['execution_order'] = true_execution_order
	round_package['timeout'] = false
	round_package['exchange'] = last_exchange
	last_exchange = null
	return round_package



func accept_player(inc_player):
	player = inc_player

func accept_enemy(inc_enemy):
	enemy = inc_enemy

func all_characters():
	return player.team.characters + enemy.team.characters

func get_team_factions_from_character(character):
	if character in player.team.characters:
		return [player.team, enemy.team]
	else:
		return [enemy.team, player.team]

func are_characters_hostile(first, second):
	if first in player.team.characters:
		return second in enemy.team.characters
	else:
		return second in player.team.characters

func find_enemy_by_path(ref_character, path):
	for character in all_characters():
		if character.path_name == path:
			if are_characters_hostile(ref_character, character):
				return character
	return false


func start_round_loop():
	if not $BotCrashTimer.is_stopped():
		$BotCrashTimer.stop()
	execution_loop_step()

func execution_loop_step():
	if len(true_execution_order) > 0:
		var action_id = true_execution_order.pop_front()
		for key in execution_order.keys():
			if typeof(key) == 3 and key == action_id:
				action_id = float(action_id)
			elif typeof(key) == 2 and key == action_id:
				action_id = int(action_id)
		var result = execute_step(execution_order[action_id])
		if not result == OK:
			print("An error occurred while attempting to execute " + execution_order[action_id].ability_name)
		if not check_match_over():
			execution_loop_step()
		else:
			test_count += 1
			update_bot_records(win_record, loss_record)
			restart_test_scene()
			return
	else:
		end_of_turn_effect_handling()

func execute_step(executable):
	if executable is Ability:
		execute_ability(executable)
	elif executable is Array:
		executable.sort_custom(func (a, b): return a.twin_priority < b.twin_priority)
		for effect in executable:
			execute_ticking_effect(effect)
	return OK

func get_player_owner(character):
	if character in player.team.characters:
		return player
	if character in enemy.team.characters:
		return enemy
	return null

func execute_ability(ability):
	var char = ability.user
	if not (char.is_stunned(ability) or (char.dead or char.banished)):
		
		for target in char.targeter.targets:
			if ability.ability_name == "Bluff Kamehameha" and target.marked_by("Big Bang Kamehameha", char):
				return
			if ability.ability_name == "Rankyaku Gaicho":
				for effect in target.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
					char.manually_advance_mission(9, 1)
					target.effects.erase_effect(effect)
				for effect in target.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
					target.effects.erase_effect(effect)
					char.manually_advance_mission(9, 1)
			
		
		
		
		log_ability_use(char, ability)
		ability.start_cooldown()
		if ability.ability_blinded:
			get_valid_random_targets(char)
		if ability.classes["Harmful"] and char.is_taunted():
			char.resolve_taunt()
		var delay_check = ability.is_delayed()
		if delay_check > 0:
			ability.delay_execution(char, self, delay_check)
			return
		if not ability.classes["Preserves Channel"]:
			char.cancel_channels()
		if not char.countered(self, ability):
			char.reflect_check(self, ability)
			char.accuracy_check(ability)
			ability.execute(char, self)
			char.check_ability_use_triggers(self, ability, char.path_name == "emiyaarcher")
			char.acted = true
		else:
			for eff in char.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
				eff.user.wrath_check("counter")

func execute_ticking_effect(effect):
	if effect.target.dead or effect.target.banished:
		return
	if effect.source.classes["Action"] and effect.user.is_stunned(effect.source):
		return
	if effect.removed:
		return
	if effect.effect_type == EffectType.Type.DAMAGE:
		if effect.target.is_invuln(effect.source) and not (effect.source.classes["Bypassing"] or effect.bypassing or effect.damage_type == DamageType.Type.AFFLICTION or effect.damage_type == DamageType.Type.BLEED):
			return
		if effect.last_turn_only and effect.duration != 1:
			return
		if effect.per_stack:
			for i in range(effect.stack_count()):
				var context = QueryContext.from_game_state(effect.user, self)
				Character.resolve_effect_damage(context, effect, effect.target, effect.mag, effect.damage_type)
		else:
			var context = QueryContext.from_game_state(effect.user, self)
			Character.resolve_effect_damage(context, effect, effect.target, effect.mag, effect.damage_type)
	elif effect.effect_type == EffectType.Type.HEALING:
		if effect.target.is_isolated():
			return
		if effect.per_stack:
			for i in range(effect.stack_count()):
				effect.user.give_effect_healing(effect, effect.mag, effect.target)
		else:
			effect.user.give_effect_healing(effect, effect.mag, effect.target)
	elif effect.effect_type == EffectType.Type.TICKING_TRIGGER:
		if effect.user in effect.target.team.characters:
			if effect.target.is_isolated():
				return
		else:
			if effect.target.is_invuln(effect.source) and not (effect.source.classes["Bypassing"] or effect.bypassing):
				return 
		
		var context = QueryContext.from_effect_end(effect)
		effect.trigger.check(context)
	elif effect.effect_type == EffectType.Type.DELAYED_SKILL:
		var context = QueryContext.from_effect_end(effect)
		effect.source.delay_trigger(context)
		if effect.duration != 1:
			return
		if effect.user in effect.target.team.characters:
			if effect.target.is_isolated():
				return
		else:
			if effect.target.is_invuln(effect.set_source) and not effect.source.classes["Bypassing"]:
				return 
		var delayed_skill = effect.delay_skill
		var targets = effect.delay_targets
		var main_target = effect.delay_main_target
		
		var target_storage = effect.user.targeter.targets
		var main_target_storage = effect.user.targeter.main_target
		var used_skill_storage = effect.user.used_ability
		
		effect.user.targeter.targets = targets
		effect.user.targeter.main_target = main_target
		effect.user.used_ability = delayed_skill
		
		if not effect.user.countered(self, delayed_skill):
			effect.user.reflect_check(self, delayed_skill)
			effect.user.accuracy_check(delayed_skill)
			delayed_skill.execute(effect.user, self)
			var used_storage = effect.user.used_ability
			effect.user.check_ability_use_triggers(self, delayed_skill, effect.user.path_name == "emiyaarcher")
			effect.user.acted = true
		
		effect.user.targeter.targets = target_storage
		effect.user.targeter.main_target = main_target_storage
		effect.user.used_ability = used_skill_storage
		



func start_new_turn(first_turn = false):
	log_turn_header(_current_turn_count + 1)
	if first_turn:
		set_log_paused(true)
	for character in player.team.characters:
		character.check_start_of_turn_triggers(self)
	for character in enemy.team.characters:
		character.check_start_of_turn_triggers(self)
	if first_turn:
		set_log_paused(false)
	
	if not reconnecting:
		generate_team_energy(player.team, first_turn)

	waiting_for_turn = false
	execution_order = {}
	true_execution_order = []
	for character in all_characters():
		character.refresh()
	player.perform_turn(self)

func receive_ability_use_request(character, ability):
	#TODO: if the ability use is invalid...
	if character.enemy:
		#TODO display ability information instead of targeting
		return
	if gamestate == Gamestate.CLOSED:
		return
	
	
	reset_character_targeted()
	if ability.usable(character):
		character.targeter.start_targeting(ability)
		ability.target(character, self)

func tick_durations():
	for character in all_characters():
		if not character.banished:
			character.effects.tick_all_effects_durations()
		else:
			for banish in character.effects.get_effects_by_type(EffectType.Type.BANISH):
				banish.tick_effect()
			if len(character.effects.get_effects_by_type(EffectType.Type.BANISH)) < 1:
				character.banished = false
			for eff in character.effects._effects:
				if eff.tick_during_banish:
					eff.tick_effect()



func end_of_turn_effect_handling():
	var team = player.team.characters
	if waiting_for_turn:
		team = enemy.team.characters
	for character in all_characters():
		if character.dead or character.banished:
			character.check_cancels()
			if not character.banished:
				character.effects.clear_non_system_effects(character)
	for character in team:
		if not (character.dead or character.banished):
			character.moveset.advance_cooldowns(character)
			character.check_end_of_turn_triggers(self)
	
	tick_durations()
	
	turn_over()

func end_match(won):
	match_over = true
	
func check_match_over():
	if check_lose_condition():
		for character in enemy.team.characters:
			if character.path_name in win_record:
				win_record[character.path_name] += 1
			else:
				win_record[character.path_name] = 1
		for character in player.team.characters:
			if character.path_name in loss_record:
				loss_record[character.path_name] += 1
			else:
				loss_record[character.path_name] = 1
		end_match(false)
		print("Bot 1 lost")
		return true
	if check_win_condition():
		for character in player.team.characters:
			if character.path_name in win_record:
				win_record[character.path_name] += 1
			else:
				win_record[character.path_name] = 1
		for character in enemy.team.characters:
			if character.path_name in loss_record:
				loss_record[character.path_name] += 1
			else:
				loss_record[character.path_name] = 1
		end_match(true)
		print("Bot 2 lost")
		return true
	return false
	
func turn_over():
	action_order = []
	if check_match_over():
		test_count += 1
		await get_tree().create_timer(0.01).timeout
		update_bot_records(win_record, loss_record)
		restart_test_scene()
		return
	
	await get_tree().create_timer(0.01).timeout
	
	if waiting_for_turn:
		waiting_for_turn = false
		start_new_turn()
	else:
		for character in enemy.team.characters:
			character.check_start_of_turn_triggers(self)
		for character in player.team.characters:
			character.check_start_of_turn_triggers(self)
		wait_for_turn()
		

func get_ticking_effects(character, is_enemy=false):
	var ticking_effects = []
	var team = player.team.characters
	if is_enemy:
		team = enemy.team.characters
		
	for effect in character.get_damage_effects():
		if effect.user in team and (not effect.last_turn_only or effect.duration == 1):
			ticking_effects.append(effect)
	
	for effect in character.get_healing_effects():
		if effect.user in team:
			ticking_effects.append(effect)
			
	for effect in character.get_ticking_triggers():
		if effect.user in team:
			ticking_effects.append(effect)
	
	for effect in character.get_delayed_skills():
		if effect.user in team and effect.duration == 1:
			ticking_effects.append(effect)
	
	return ticking_effects

func handle_timeout():
	for character in player.team.characters:
		if character.used_ability:
			character.acted_clicked()
	var ticking_information = get_ticking_effect_information()
	true_execution_order = []
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority <= b.twin_priority)
		execution_order[key] = ticking_information[key]
		true_execution_order.append(key)
	start_round_loop()

func handle_opponent_timeout():
	for character in enemy.team.characters:
		if not character.dead and not character.banished:
			character.generate_energy()
	
	var ticking_information = get_ticking_effect_information(true)
	true_execution_order = []
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority <= b.twin_priority)
		execution_order[key] = ticking_information[key]
		true_execution_order.append(key)
	start_round_loop()

func reset_targeting():
	reset_character_targeted()

func receive_character_use_request(character):
	if gamestate == Gamestate.CLOSED:
		return	
	if character.targeted:
		$Sound.volume_db = -20
		play_sound("big_click")
		$Sound.volume_db = -10
		for char in player.team.characters:
			if char.targeter.targeting:
				action_order.append(char)
				break
		character_clicked.emit(character)
	else:
		play_sound("click")

func finalize_action(char):
	player.team.pay_for_ability(char.used_ability)
	char.acted = true

func get_other_aoe_targets(targeter, main_target, faction_specific, and_check=false):
	for character in all_characters():
		if not (character in targeter.targeter.targets) and not character == main_target and character.targeted and (not faction_specific or not are_characters_hostile(character, main_target)) and (not and_check or targeter.used_ability.and_target(character)):
			targeter.targeter.add_target(character)

func get_valid_random_targets(char):
	var hostile = true
	
	if char.targeter.main_target in char.team.characters:
		hostile = false
	char.targeter.clear_targets()
	var output = []
	char.targeter.targeting_ability = char.used_ability
	char.targeter.targeting_ability.target(char, self)
	
	for character in all_characters():
		if character.targeted and (character in char.team.characters or (hostile and not character in char.team.characters)):
			output.append(character)
	var target_roll = roll(0, len(output) - 1, "Valid Random Targets")
	var new_target = output[target_roll]
	char.targeter.add_target(new_target)
	char.targeter.main_target = new_target
	

func roll(min, max, desc = "None"):
	#print(str(multiplayer.get_unique_id()) +": Rolling die (" + str(die.seed) + ")")
	#print("Description: " + desc)
	#print("\tParameters: " + str(min) + " to " + str(max))
	var result = die.randi_range(min, max)
	#print("\tResult: " + str(result))
	return result

func request_message(message):
	message_request.emit(message)

func demand_message(message):
	message_demand.emit(message)

var _current_turn_count: int = 0
var _log_paused: bool = false

func set_log_paused(paused: bool):
	_log_paused = paused

func _clear_action_log():
	var log_box = get_node_or_null("MessageBoxComponent")
	if log_box != null and log_box.has_method("clear_log"):
		log_box.clear_log()

func emit_log_event(event: BattleLogEvent):
	if event == null or _log_paused:
		return
	if event.turn == 0:
		event.turn = _current_turn_count
	log_event.emit(event)

func log_ability_use(user, ability):
	if ability != null:
		if "invisible" in ability and ability.invisible:
			return
		if "classes" in ability and ability.classes is Dictionary and ability.classes.get("Passive", false):
			return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.ABILITY_USE).with_actor(user).with_ability(ability))

func log_damage(dealer, target, amount, damage_type, source_ability = null, source_effect = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.DAMAGE).with_actor(dealer).with_target(target).with_amount(amount).with_damage_type(damage_type)
	if source_ability != null:
		event.with_ability(source_ability)
	if source_effect != null:
		event.with_effect(source_effect)
	emit_log_event(event)

func log_healing(healer, target, amount, source_ability = null, source_effect = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.HEALING).with_actor(healer).with_target(target).with_amount(amount)
	if source_ability != null:
		event.with_ability(source_ability)
	if source_effect != null:
		event.with_effect(source_effect)
	emit_log_event(event)

func log_effect_applied(applier, target, effect):
	if effect == null or effect.invisible or effect.system:
		return
	if effect.effect_type == EffectType.Type.COUNTER_TRIGGER_NOTIFICATION or effect.effect_type == EffectType.Type.INVISIBLE_EXPIRATION:
		return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.EFFECT_APPLIED).with_actor(applier).with_target(target).with_effect(effect))

func log_effect_expired(target, effect, reason: String = "expired"):
	if effect == null or effect.invisible or effect.system:
		return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.EFFECT_EXPIRED).with_target(target).with_effect(effect).with_extra("reason", reason))

func log_counter(actor):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.COUNTER).with_actor(actor))

func log_reflect(actor):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.REFLECT).with_actor(actor))

func log_invuln_block(actor, target, ability = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.INVULN_BLOCK).with_actor(actor).with_target(target)
	if ability != null:
		event.with_ability(ability)
	emit_log_event(event)

func log_miss(actor, target):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.MISS).with_actor(actor).with_target(target))

func log_death(character):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.DEATH).with_actor(character))

func log_revive(character):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.REVIVE).with_actor(character))

func log_energy_gain(team, element_name: String):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.ENERGY_GAIN).with_extra("element", element_name)
	if team != null and team.characters.size() > 0:
		event.with_actor(team.characters[0])
	emit_log_event(event)

func log_turn_header(turn_number: int, who: String = ""):
	_current_turn_count = turn_number
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.TURN_HEADER).with_extra("who", who))

func log_system(text: String, demand: bool = false):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.SYSTEM).with_extra("text", text)
	if demand:
		event.as_demand()
	emit_log_event(event)

func reset_character_targeted():
	for character in all_characters():
		if character.targeter.targeting:
			character.targeter.reset()
		character.set_untargeted()


func receive_turn_package(package):
	
	process_turn_package(package, went_second)
	
	#if not went_second:
	#	generate_team_energy(enemy.team)
	#else:
	#	went_second = false
	#
#
	#var character_actions = package['character_actions']
	#for action_set in character_actions:
	#	print("Unpacking an action!")
	#	var index_of_character = action_set[0] + 3 #because the team positions are opposite
	#	var char = all_characters()[index_of_character]
	#	var index_of_ability = action_set[1]
	#	print("Ability index: " + str(index_of_ability))
	#	var used_ability = char.moveset.get_active_abilities(char)[index_of_ability]
	#	print("Used ability name: " + used_ability.ability_name)
	#	char.used_ability = used_ability
	#	char.acted = true
	#	var target_indexes = action_set[2]
	#	for target in target_indexes:
	#		#Perform position reversal
	#		if target > 2:
	#			target -= 3
	#		else:
	#			target += 3
	#		char.targeter.add_target(all_characters()[target])
	#	
	#	var ttype = used_ability.target_type()
	#	if char.blind_check():
	#		if ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION or ttype == TargetType.Type.SELF:
	#			pass
	#		else:
	#			used_ability.ability_blinded = true
	#	execution_order[action_set[0]] = char.used_ability
	#var ticking_information = get_ticking_effect_information(true)
	#for key in ticking_information.keys():
	#	execution_order[key] = ticking_information[key]
	#true_execution_order = package['execution_order']
	#start_round_loop()

func check_lose_condition():
	for character in player.team.characters:
		if not (character.dead or character.banished):
			return false
	return true

func check_win_condition():
	for character in enemy.team.characters:
		if not (character.dead or character.banished):
			return false
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_delay_timer_timeout():
	execution_loop_step()

func start_timer_w_timeout(timeout):
	var timer_timeout = func ():
		timeout.call()
	if $Timer.timeout.is_connected(current_timer_func):
		$Timer.timeout.disconnect(current_timer_func)
	current_timer_func = timer_timeout
	$Timer.timeout.connect(timer_timeout)
	$Timer.start()

func receive_surrender():
	end_match(true)

func package_match_report(won):
	return {}

func surrender_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		$PanelContainer.show()

func finish_surrender():
	if not enemy.bot_player:
		send_surrender.emit()
	end_match(false)
	
func surrender_button_hover():
	$UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.hex(0xffffff88)

func surrender_button_stop_hover():
	$UI/MarginContainer2/SystemInfoRow/MarginContainer/VBoxContainer/PanelContainer.modulate = Color.WHITE

func _on_panel_container_2_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		#DisplayLens.full_battle_lens(player, enemy)
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

func _on_bot_crash_timer_timeout():
	start_round_loop()

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
