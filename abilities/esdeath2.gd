extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Esdeath stuns all other characters for 2 turns",
		["After this effect ends, Esdeath is stunned for 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(4)
		stun.set_source(self)
		stun.wrapup_func = timeout_trigger
		Character.add_hostile_effect(context, user, target, stun)


func timeout_trigger(context):
	if not user.has_effect("Mahapadma", EffectType.Type.STUN, user):
		var stun = Effect.stun_effect(4)
		stun.set_source(self)
		Character.add_allied_effect(context, user, user, stun)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
