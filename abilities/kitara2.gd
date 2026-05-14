extends Ability

func describe(user):
	return "Reflects all Harmful skills that target Katara back at their caster for 1 turn. Does not interrupt Channeling."

func split_desc():
	return [
		"Reflects all Harmful skills targeting Katara for 1 turn.",
		["Does not interrupt active Channeling.", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = make_context(battle)
	var reflect = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, 2, "Harmful skills targeting Katara reflect back at their caster.", ["Harmful"])
	reflect.set_source(self)
	reflect.invisible = true
	reflect.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, reflect)

func reflect_trigger(context):
	var attacker = context['owner']
	if attacker.used_ability.target_type() != TargetType.Type.SINGLE:
		return
	attacker.targeter.targets.erase(context['target'])
	attacker.targeter.targets.append(attacker)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 10, 0.5)

func target(user, battle):
	default_self_target_function(user, battle)
