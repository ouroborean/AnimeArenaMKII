extends Ability
var used = false
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Hinata applies a permanent, invisible mark to another ally. If an enemy stuns that ally or lowers their HP below 30, Hinata will permanently taunt that enemy. Afterward, this skill will be permanently replaced by Gentle Step: Twin Lions Fist."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If an enemy lowers this character's HP below 30, Hinata will permanently taunt that enemy and My Turn To Protect will be replaced by Gentle Step: Twin Lions Fist.")
		trigger.set_source(self)
		trigger.invisible = true
		var stun_trigger = Effect.trigger_effect(Trigger.always(stun_trigger), EffectType.Type.STUN_RECEIVED_TRIGGER, -1, "If an enemy stuns this character, Hinata will permanently taunt that enemy and My Turn To Protect will be replaced by Gentle Step: Twin Lions Fist.")
		stun_trigger.set_source(self)
		stun_trigger.invisible = true
		Character.add_allied_effect(context, user, target, trigger)
		Character.add_allied_effect(context, user, target, stun_trigger)
		used = true

func damage_trigger(context):
	var hinata = user
	var eff = context['effect']
	var enemy = context['owner']
	if hinata in enemy.team.characters:
		return
	if context['target'].health.hp < 30:
		
		var taunt = Effect.taunt_effect(-1, hinata)
		taunt.set_source(self)
		var new_context = QueryContext.from_game_state(hinata, hinata.battle)
		Character.add_hostile_effect(new_context, hinata, enemy, taunt)
		var swap = Effect.ability_swap_effect(4, 3, hinata, -1)
		swap.set_source(self)
		Character.add_allied_effect(new_context, hinata, hinata, swap)
		context['target'].effects.full_remove_effect_by_name("My Turn To Protect", hinata)
	

func stun_trigger(context):
	var hinata = user
	var eff = context['effect']
	var enemy = context['owner']
	if hinata in enemy.team.characters:
		return
	var taunt = Effect.taunt_effect(-1, hinata)
	taunt.set_source(self)
	var new_context = QueryContext.from_game_state(hinata, hinata.battle)
	Character.add_hostile_effect(new_context, hinata, enemy, taunt)
	var swap = Effect.ability_swap_effect(4, 3, hinata, -1)
	swap.set_source(self)
	Character.add_allied_effect(new_context, hinata, hinata, swap)
	context['target'].effects.full_remove_effect_by_name("My Turn To Protect", hinata)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not used
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_selfless_helpful(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
