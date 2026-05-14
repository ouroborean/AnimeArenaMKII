extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, Nobara will ignore instant-kill and execute effects. At the end of each of her turns, if she is affected by a harmful non-damaging effect, she will heal 15 HP and gain 10 DR until this skill ends. Usable while stunned."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(4, "Nobara will ignore instant-kill and execute effects.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var tick = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 3, "If Nobara is affected by a harmful non-damaging effect at the end of her turn, she will heal 15 HP and gain 10 DR for 1 turn.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)
	for effect in user.effects._effects:
		if not user.is_hostile(effect.user):
			continue
		if effect.effect_type in [
			EffectType.Type.STUN,
			EffectType.Type.DAMAGE_MOD,
			EffectType.Type.DEF_NEGATE,
			EffectType.Type.DAMAGE_NEGATE,
			EffectType.Type.COST_CHANGE,
			EffectType.Type.COST_MOD,
			EffectType.Type.COUNTER_USE,
			EffectType.Type.COUNTER_RECEIVE,
			EffectType.Type.REFLECT_USE,
			EffectType.Type.REFLECT_RECEIVE,
			EffectType.Type.HEALING_MOD,
			EffectType.Type.VULNERABILITY,
			EffectType.Type.BLIND,
			EffectType.Type.DAMAGE_NULLIFICATION,
			EffectType.Type.COOLDOWN_MOD,
			EffectType.Type.DELAY,
			EffectType.Type.ISOLATE,
			EffectType.Type.TAUNT,
			EffectType.Type.PARALYZE,
			EffectType.Type.HEAL_CUT,
			EffectType.Type.DAMAGE_CAP,
			EffectType.Type.HEALTH_CAP,
			]:
				Character.resolve_healing(context, user, 15)
				var dr = Effect.damage_reduction_effect(10, 2)
				dr.set_source(self)
				dr.unique_render_id = 5
				Character.add_allied_effect(context, user, user, dr)
				return

func tick_trigger(context):
	for effect in user.effects._effects:
		if not user.is_hostile(effect.user):
			continue
		if effect.effect_type in [
			EffectType.Type.STUN,
			EffectType.Type.DAMAGE_MOD,
			EffectType.Type.DEF_NEGATE,
			EffectType.Type.DAMAGE_NEGATE,
			EffectType.Type.COST_CHANGE,
			EffectType.Type.COST_MOD,
			EffectType.Type.COUNTER_USE,
			EffectType.Type.COUNTER_RECEIVE,
			EffectType.Type.REFLECT_USE,
			EffectType.Type.REFLECT_RECEIVE,
			EffectType.Type.HEALING_MOD,
			EffectType.Type.VULNERABILITY,
			EffectType.Type.BLIND,
			EffectType.Type.DAMAGE_NULLIFICATION,
			EffectType.Type.COOLDOWN_MOD,
			EffectType.Type.DELAY,
			EffectType.Type.ISOLATE,
			EffectType.Type.TAUNT,
			EffectType.Type.PARALYZE,
			EffectType.Type.HEAL_CUT,
			EffectType.Type.DAMAGE_CAP,
			EffectType.Type.HEALTH_CAP,
			]:
				Character.resolve_effect_healing(context, context['effect'], user, 15)
				var dr = Effect.damage_reduction_effect(10, 2)
				dr.set_source(self)
				Character.add_allied_effect(context, user, user, dr)
				return

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
