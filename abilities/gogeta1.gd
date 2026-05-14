extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "On the following turn, Gogeta deals 50 damage to target enemy. During this time, this skill is replaced by Bluff Kamehameha. This effect is Channeled."

func split_desc():
	return [
		"Deals 50 damage to target enemy next turn (Channeled)",
		["Swaps to Bluff Kamehameha", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	
	if user.has_effect("Bluff Kamehameha", EffectType.Type.COST_MOD):
		user.manually_advance_mission(10, 1)
	
	for target in user.targeter.targets:
		var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 3, "This character will take 50 damage.")
		ticking.set_source(self)
		cancels.append(ticking)
		Character.add_hostile_effect(context, user, target, ticking)
	var swap = Effect.ability_swap_effect(4, 0, user, 3)
	swap.set_source(self)
	cancels.append(swap)
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, cancel_eff)

func tick_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 50, DamageType.Type.NORMAL)
	var mark = Effect.mark(1, "")
	mark.system = true
	mark.set_source(self)
	Character.add_hostile_effect(context, user, context['target'], mark, true)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
