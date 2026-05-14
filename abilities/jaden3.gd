extends Ability

func describe(user):
	return "Jaden permanently gains 25 Shield. As long as this Shield persists, Elemental HERO Clayman's Shield gains 10 each turn and this skill is replaced by Elemental HERO Mudballman."

func split_desc():
	return [
		"For 3 turns, Jaden gains 15 Shield",
		"Elemental HERO Clayman's Shield gains 10 each turn, up to a maximum of 45",
		"This skill is replaced by Elemental HERO Mudballman"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var shield = Effect.shield_effect(15, 6)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)

	# First-turn shield regen
	var shields = user.get_shield_effects()
	for s in shields:
		if s.source and s.source.ability_name == "Elemental HERO Clayman":
			s.change_mag(10)
			if s.mag > 45:
				s.mag = 45

	var tick_desc = func(eff):
		return "Elemental HERO Clayman's Shield gains 10 each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(clayman_tick),
		EffectType.Type.TICKING_TRIGGER, 5, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

	var swap = Effect.ability_swap_effect(6, 2, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func clayman_tick(context):
	var jaden = context['owner']
	var shields = jaden.get_shield_effects()
	for shield in shields:
		if shield.source and shield.source.ability_name == "Elemental HERO Clayman":
			shield.change_mag(10)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
