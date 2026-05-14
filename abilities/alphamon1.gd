extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy and Shatters them for 2 turns (refreshes)."

func split_desc():
	return [
		"Deals 20 damage to target enemy.",
		"Shatters them for 2 turns (refreshes).",
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var shatter = Effect.def_negate(3)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
