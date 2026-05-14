extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna deals 5 damage to all characters. This effect deals damage to an additional random enemy each time Sealed King has been activated this game."

func split_desc():
	return [
		"Deals 5 damage to all other characters each turn",
		"+5 damage each turn",
		"Can only be used once",
		"Requires Malevolent Shrine"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var user_tick = Effect.trigger_effect(Trigger.always(self_tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Sukuna cannot use Cleave and Dismantle.")
	user_tick.set_source(self)
	Character.add_allied_effect(context, user, user, user_tick)
	user_tick.twin_priority = 0
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.NORMAL)
		var tick = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "This character will take 5 Piercing damage.")
		tick.set_source(self)
		Character.add_hostile_effect(context, user, target, tick)
	


func self_tick_trigger(context):
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Cleave and Dismantle"])
	damage_mod.set_source(self)
	damage_mod.display_stacks = true
	damage_mod.stack_mag = true
	damage_mod.stackable = true
	Character.add_allied_effect(context, user, user, damage_mod)


func tick_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 5, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Malevolent Shrine") and not user.has_effect("Cleave and Dismantle", EffectType.Type.TICKING_TRIGGER, user)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 150)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
