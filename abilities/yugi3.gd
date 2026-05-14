extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Stuns all characters' Harmful skills for 3 turns",
		["Swaps to Dark Magician while active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(6, ["Harmful"])
		stun.set_source(self)
		if target in user.team.characters:
			Character.add_hostile_effect(context, user, target, stun)
		else:
			Character.add_hostile_effect(context, user, target, stun)
	var swap = Effect.ability_swap_effect(4, 2, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	
	user.call_unique("yugi", "check_card", ["swords"])
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
