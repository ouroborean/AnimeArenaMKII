extends Ability

var initial_damage = 30
var tick_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One enemy takes 30 piercing damage and then takes 15 piercing damage per turn. During this time, their skills cost one more random energy, Reap is replaced by Figure-6 Hunter, and if the targeted enemy uses a new harmful skill, this effect will end. Channeled."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var cancels = []

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, initial_damage, DamageType.Type.PIERCING)
		var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM)
		cost_mod.set_source(self)
		cost_mod.channel = true
		cancels.append(cost_mod)
		var damage_eff = Effect.damage_effect(tick_damage, DamageType.Type.PIERCING, -1)
		damage_eff.set_source(self)
		damage_eff.channel = true
		cancels.append(damage_eff)
		var trigger_eff = Effect.trigger_effect(Trigger.always(break_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "If this character uses a new harmful skill, this effect will end.")
		trigger_eff.set_source(self)
		trigger_eff.channel = true
		cancels.append(trigger_eff)
		Character.add_hostile_effect(context, user, target, damage_eff)
		Character.add_hostile_effect(context, user, target, cost_mod)
		Character.add_hostile_effect(context, user, target, trigger_eff)
	
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	swap.channel = true
	cancels.append(swap)
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, cancel_eff)

func break_trigger(context):
	context['target'].effects.full_remove_effect_by_name("Witch Hunter", context['effect'].user)
	context['effect'].user.effects.full_remove_effect_by_name("Witch Hunter", context['effect'].user)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
