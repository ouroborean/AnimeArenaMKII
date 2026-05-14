extends Ability


func describe(user):
	return "After being used, the first time Itachi's HP is brought below 50, this effect will be triggered (Invisible). Once triggered, Itachi's other skills are permanently replaced by their alternate versions. During this time, he gains 50 Shield, permanently ignores non-damage effects, and takes 10 Affliction damage at the end of each turn."


func split_desc():
	return [
		"Sets up Susanoo (Invisible)",
		["When Itachi's HP drops below 50: gains 50 Shield, permanently ignores non-damage effects, takes 10 Affliction damage per turn", Color.CADET_BLUE],
		["On activation, Crow Clone / Tsukuyomi / Kotoamatsukami are permanently replaced by Totsuka Blade / Yata Mirror / Slumbering Dragon", Color.AQUAMARINE],
	]


func execute(user, battle):
	var context = make_context(battle)

	# Lock the slot so Susanoo cannot be used again.
	var used = Effect.mark(-1, "Susanoo has already been used.")
	used.invisible = true
	used.system = true
	apply_allied(context, user, used)

	# If Itachi is already below the threshold at cast time, activate
	# immediately — HEALTH_CHANGE_TRIGGER only fires on transitions and
	# would otherwise stall until the next HP change.
	if user.health.hp < 50:
		susanoo_activate(context)
		return

	var trigger = Trigger.from_condition(Condition.health_is(user, -1, 49), susanoo_activate)
	var trig_eff = Effect.trigger_effect(
		trigger,
		EffectType.Type.HEALTH_CHANGE_TRIGGER,
		-1,
		"If Itachi's HP drops below 50, Susanoo activates.")
	trig_eff.invisible = true
	apply_allied(context, user, trig_eff)


func susanoo_activate(context):
	var itachi = context['owner']
	var qc = QueryContext.from_game_state(itachi, itachi.battle)

	apply_allied(qc, itachi, Effect.shield_effect(50, -1))
	apply_allied(qc, itachi, Effect.ignore_non_damage_effect(-1))
	apply_allied(qc, itachi, Effect.damage_effect(10, DamageType.Type.AFFLICTION, -1))

	swap_ability(qc, 4, 0, -1)
	swap_ability(qc, 5, 1, -1)
	swap_ability(qc, 6, 2, -1)

	itachi.effects.remove_effect("Susanoo", EffectType.Type.HEALTH_CHANGE_TRIGGER, itachi)


func extra_usable(user):
	return not user.has_effect("Susanoo", EffectType.Type.MARK, user)


func custom_behavior(context):
	return behavior_self_panic_button(context, 20)


func target(user, battle):
	default_self_target_function(user, battle)
