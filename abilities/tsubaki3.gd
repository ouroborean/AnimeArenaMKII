extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target ally gains 20 Shield",
		["If that ally is wielding Tsubaki: For 1 turn, if they use a new skill, that skill will be replaced by Tsubaki Mode: Uncanny Sword for 1 turn", Color.AQUAMARINE],
		["If the target is Black Star, Tsubaki also gains 15 Shield", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shield = Effect.shield_effect(20, 2)
		shield.set_source(self)
		var trigger = Effect.trigger_effect(Trigger.always(use_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a skill, it will be replaced by Tsubaki Mode: Uncanny Sword")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, target, shield)
		
		if target.marked_by("Tsubaki Mode: Kusarigama"):
			Character.add_allied_effect(context, user, target, trigger)
	
		if target.path_name == "blackstar":
			var sub_shield = Effect.shield_effect(15, 2)
			sub_shield.set_source(self)
			Character.add_allied_effect(context, user, user, sub_shield)
		
	
			
			
func use_trigger(context):
	var wielder = context['target']
	var used_skill = context['source']
	var used_skill_index = wielder.moveset.get_active_abilities(wielder).find(used_skill)
	var copy_effect = Effect.copy_effect(user.moveset.base_abilities[5], used_skill_index, 3, wielder)
	copy_effect.set_source(self)
	Character.add_allied_effect(context, user, wielder, copy_effect)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
