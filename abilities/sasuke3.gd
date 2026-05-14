extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 30 damage to target enemy and marks them for 3 turns",
		["On the third turn, swaps to Kirin for 1 turn", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
		var mark = Effect.mark(6, "This character has been marked by Great Dragon Fire.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
	var delay = Effect.empty(4, "Great Dragon Fire will swap to Kirin.")
	delay.set_source(self)
	delay.invisible = true
	delay.wrapup_func = apply_kirin_swap
	Character.add_allied_effect(context, user, user, delay)

func apply_kirin_swap(context):
	var swap = Effect.ability_swap_effect(5, 2, user, 2)
	swap.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['effect'].user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
