extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target enemy is stunned until the end of Shokuhou's next turn",
		["During this time, that enemy's skills replace Shokuhou's skills", Color.AQUA],
		["While active, those skills cost 1 less Random energy", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	
	var duration = 3
	if user.marked_by("Exterior"):
		duration += 4
	
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(duration)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		for i in range(4):
			var copy = Effect.copy_effect(target.moveset.get_active_abilities(target)[i], i, duration, user)
			copy.system = true
			copy.set_source(self)
			Character.add_allied_effect(context, user, user, copy)

	var cost_discount = Effect.cost_mod_effect(-1, duration, Energy.Type.RANDOM)
	cost_discount.set_source(self)
	Character.add_allied_effect(context, user, user, cost_discount)

	user.effects.full_remove_effect_by_name("Exterior")

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
