extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 Affliction damage to all enemies for 2 turns",
		["All characters have their skill costs increased by 1 Random energy", Color.CADET_BLUE],
		["Swaps with Scream Chaser", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var total_cost = 0
	var captured_cost = cost()
	for cost_type in captured_cost:
		total_cost += captured_cost[cost_type]
	for target in user.targeter.targets:
		if not target in user.team.characters:
			Character.resolve_damage(context, target, 10, DamageType.Type.AFFLICTION)
			var damage_ef = Effect.damage_effect(10, DamageType.Type.AFFLICTION, 3)
			damage_ef.set_source(self)
			Character.add_hostile_effect(context, user, target, damage_ef)
		var energy_mod = Effect.cost_mod_effect(1, 5, Energy.Type.RANDOM)
		energy_mod.set_source(self)
		Character.add_allied_effect(context, user, target, energy_mod)
	var swap = Effect.ability_swap_effect(4, 1, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	user.manually_advance_mission(6, total_cost)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
