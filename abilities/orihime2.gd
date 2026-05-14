extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Returns target ally's HP to its state from 2 turns prior, if it was higher than their current HP",
		["If that ally's HP doesn't change, they gain 1 Random energy", Color.DIM_GRAY],
		["While Empowered, heals the ally for 30 HP instead", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if user.marked_by("Six Princess Shielding Flowers"):
			user.manually_advance_mission(7, 1)
			Character.resolve_healing(context, target, 30)
		else:
			if target.health.hp == target.hp_last_last_turn:
				user.manually_advance_mission(6, 1)
				target.gain_random_energy()
			else:
				if target.health.hp < target.hp_last_last_turn:
					target.health.hp = target.hp_last_last_turn
					target.health.health_changed.emit(target.health.hp)
			
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 35, 1.5)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
