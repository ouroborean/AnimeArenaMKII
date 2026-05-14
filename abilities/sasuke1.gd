extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy",
		["Until that enemy dies, they take 5 damage per turn", Color.ORANGE_RED],
		["Swaps with Shadow Shuriken Wire Trap while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var dot = Effect.damage_effect(5, DamageType.Type.NORMAL, -1)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
	var swap = Effect.ability_swap_effect(4, 0, user, -1)
	swap.set_source(self)
	swap.unique_render_id = 5
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
