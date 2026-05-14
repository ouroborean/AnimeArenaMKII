extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, Nagisa will ignore all Harmful effects and damage. Any character who uses a skill on them during this time will be Silenced for 2 turns."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var non_damage = Effect.ignore_non_damage_effect(2)
	var damage = Effect.ignore_damage_effect(2)
	non_damage.invisible=true
	damage.invisible=true
	damage.wrapup_func = default_counter_timeout
	non_damage.set_source(self)
	damage.set_source(self)
	Character.add_allied_effect(context, user, user, non_damage)
	Character.add_allied_effect(context, user, user, damage)
	var trigger = Effect.trigger_effect(Trigger.always(test_me_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "Any character who uses a Harmful skill on Nagisa will be Silenced for 2 turns.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func test_me_trigger(context):
	var attacker = context['owner']
	var nagisa = context['target']
	nagisa.manually_advance_mission(9, 1)
	var silence = Effect.silence_effect(5)
	silence.set_source(self)
	Character.add_hostile_effect(context, nagisa, attacker, silence)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
