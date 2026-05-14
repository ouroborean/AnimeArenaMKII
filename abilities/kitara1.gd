extends Ability

var base_damage = 15

func describe(user):
	return "Deals 15 Piercing damage to target enemy permanently. Channeled — ends if Katara uses another skill or is stunned."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy per turn, permanently.",
		["Ends if Katara uses another skill or is stunned.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var cancels = []
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var dot = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, -1)
		dot.set_source(self)
		dot.channel = true
		cancels.append(dot)
		Character.add_hostile_effect(context, user, target, dot)
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 45, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
