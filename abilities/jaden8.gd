extends Ability

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Avian and Elemental HERO Bubbleman. Jaden permanently gains 45 Shield. As long as this Shield persists, Jaden will cleanse all Harmful effects on his team each turn."

func split_desc():
	return [
		"Cleanses all Harmful effects on Jaden's team each turn",
		["Only usable with Avian + Bubbleman active", Color.DIM_GRAY],
		"Consumes Avian and Bubbleman effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user)


	# First-turn cleanse
	for ally in user.team.characters:
		if ally.dead or ally.banished:
			continue
		ally.effects.cleanse_all_enemy_effects(ally)

	var tick_desc = func(eff):
		return "Jaden will cleanse all Harmful effects on his team each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(mariner_tick),
		EffectType.Type.TICKING_TRIGGER, -1, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func mariner_tick(context):
	var jaden = context['owner']
	for ally in jaden.team.characters:
		if ally.dead or ally.banished:
			continue
		ally.effects.cleanse_all_enemy_effects(ally)

func extra_usable(user):
	var has_avian = user.has_effect(
		"Elemental HERO Avian", EffectType.Type.SHIELD, user
	)
	var has_bubbleman = user.has_effect(
		"Elemental HERO Bubbleman", EffectType.Type.SHIELD, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.TICKING_TRIGGER, user
	)
	return not has_self and has_avian and has_bubbleman

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
