extends Ability

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Clayman and Elemental HERO Bubbleman. Jaden permanently gains 100 Shield."

func split_desc():
	return [
		"Jaden permanently gains 80 Shield",
		["Only usable with Clayman + Bubbleman active", Color.DIM_GRAY],
		"Consumes Clayman and Bubbleman effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user)

	var shield = Effect.shield_effect(80, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)

func extra_usable(user):
	var has_clayman = user.has_effect(
		"Elemental HERO Clayman", EffectType.Type.SHIELD, user
	)
	var has_bubbleman = user.has_effect(
		"Elemental HERO Bubbleman", EffectType.Type.SHIELD, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.SHIELD, user
	)
	return not has_self and has_clayman and has_bubbleman

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
