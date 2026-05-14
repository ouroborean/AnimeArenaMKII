extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Byakuya targets an enemy for 1 turn. If they don't use a new skill during this time, Byakuya will deal 15 Piercing damage to them and permanently lower their damage by 5 at the end of the next turn. This skill is invisible."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy on the following turn and gives them -5 damage permanently (Invisible)",
		"This will be cancelled if the target uses a skill"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var watch_trigger = Effect.trigger_effect(Trigger.always(remove_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a new skill, this effect will end.")
		watch_trigger.invisible = true
		watch_trigger.waiting = false
		watch_trigger.wrapup_func = default_counter_timeout
		watch_trigger.set_source(self)
		var fail_trigger = Effect.trigger_effect(Trigger.always(senka_trigger), EffectType.Type.TICKING_TRIGGER, 3, "Byakuya will deal 15 Piercing damage to this character and permanently lower their damage by 5.")
		fail_trigger.invisible = true
		fail_trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, fail_trigger)
		Character.add_hostile_effect(context, user, target, watch_trigger)

func remove_trigger(context):
	context['effect'].target.effects.full_remove_effect_by_name("Senka", context['effect'].user)
	var mark = Effect.mark(2, "Senka has been cancelled.")
	mark.set_source(self)
	Character.add_hostile_effect(context, context['effect'].user, context['effect'].target, mark)
		
func senka_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], base_damage, DamageType.Type.PIERCING)
	
	context['effect'].user.manually_advance_mission(9, 1)
	
	var weakness = Effect.damage_mod_effect(-5, -1)
	weakness.stackable = true
	weakness.per_stack = true
	weakness.display_stacks = true
	weakness.set_source(self)
	Character.add_hostile_effect(context, user, context['target'], weakness)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
