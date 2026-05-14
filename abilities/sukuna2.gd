extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna targets an enemy. If their HP is 60-31, he sets their HP to 60. If their HP is 30 or less, he executes them."

func split_desc():
	return [
		"Targets an enemy, having different effects based on their current HP:",
		["100-61: Sets their HP to 60", Color.CADET_BLUE],
		["60-31: Sets their HP to 30", Color.CADET_BLUE],
		["30 or less: Executes them", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hp = target.health.hp
		if hp > 60:
			target.health.hp = 60
			target.health.health_changed.emit(target.health.hp)
		elif hp > 30:
			target.health.hp = 30
			target.health.health_changed.emit(target.health.hp)
		else:
			target.execute_attempt(30, user, self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Malevolent Shrine")
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
