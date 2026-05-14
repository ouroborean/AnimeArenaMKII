extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, any enemy that uses a new Harmful skill on Gogeta will receive 20 damage. This effect is invisible."

func split_desc():
	return [
		"Deals 20 damage to any enemy that uses a Harmful skill on Gogeta for 1 turn (Invisible)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect("Bluff Kamehameha", EffectType.Type.COST_MOD):
		user.manually_advance_mission(10, 1)
	var trigger = Effect.trigger_effect(Trigger.always(stance_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "Gogeta will deal 20 damage to any enemy that uses a Harmful skill on him.")
	trigger.set_source(self)
	trigger.invisible = true
	Character.add_allied_effect(context, user, user, trigger)

func stance_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['owner'], 20, DamageType.Type.NORMAL)

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
