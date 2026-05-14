extends Ability

func describe(user):
	return "Jaden permanently gains 25 Shield. As long as this Shield persists, his team will heal 10 HP each turn and this skill is replaced by Elemental HERO Mariner."

func split_desc():
	return [
		"For 3 turns, Jaden gains 15 Shield",
		"Jaden's team heals 10 HP each turn",
		"This skill is replaced by Elemental HERO Mariner"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var shield = Effect.shield_effect(15, 6)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)

	# First-turn team heal
	for ally in user.team.characters:
		if ally.dead or ally.banished or ally.is_isolated():
			continue
		Character.resolve_healing(context, ally, 10)

	var tick_desc = func(eff):
		return "Jaden's team will heal 10 HP each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(bubbleman_tick),
		EffectType.Type.TICKING_TRIGGER, 5, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

	var swap = Effect.ability_swap_effect(7, 3, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func bubbleman_tick(context):
	var jaden = context['owner']
	for ally in jaden.team.characters:
		if ally.dead or ally.banished or ally.is_isolated():
			continue
		Character.resolve_effect_healing(context, context['effect'], ally, 10)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
