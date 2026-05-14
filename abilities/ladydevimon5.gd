extends Ability

func describe(user):
	return "Enemies that target LadyDevimon with Harmful skills take 5 Affliction damage each turn for the rest of the game (stacks)."

func split_desc():
	return [
		"Enemies that target LadyDevimon with Harmful skills gain a permanent stack of Lady's Poison.",
		["Lady's Poison: each turn, take 5 Affliction damage per stack.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var trigger = Effect.trigger_effect(
		Trigger.always(on_harmful_received),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		-1,
		"Enemies who use a Harmful skill on LadyDevimon gain a stack of Lady's Poison.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func on_harmful_received(context):
	var attacker = context['owner']
	var lady = context['target']
	if attacker == null or lady == null:
		return
	if attacker in lady.team.characters:
		return
	apply_poison_stack(context, lady, attacker)

func apply_poison_stack(context, lady, victim):
	var poison = Effect.trigger_effect(
		Trigger.always(poison_tick),
		EffectType.Type.TICKING_TRIGGER,
		-1,
		poison_desc)
	poison.set_source(self)
	poison.stackable = true
	poison.display_stacks = true
	Character.add_hostile_effect(context, lady, victim, poison)

func poison_tick(context):
	var eff = context['effect']
	var victim = eff.target
	if victim == null or victim.dead or victim.banished:
		return
	Character.resolve_effect_damage(context, eff, victim, 5 * eff.stack_count(), DamageType.Type.AFFLICTION)

func poison_desc(eff):
	return "This character takes " + str(5 * eff.stack_count()) + " Affliction damage each turn from Lady's Poison."

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
