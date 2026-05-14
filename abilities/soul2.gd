extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 affliction damage to one enemy and Soul. If an ally is wielding Soul, the damage is split between them."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var wielded = Condition.has_effect(user, "Scythe Transformation", EffectType.Type.DAMAGE_REDUCTION, user)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		
		var mod_damage = base_damage
		if user.marked_by("Nightmare Sonata", user):
			mod_damage += 20
		
		if wielded.satisfied(context):
			for character in user.team.characters:
				if character.effects.has_effect("Scythe Transformation", EffectType.Type.MARK, user):
					Character.resolve_damage(context, character, mod_damage / 2, DamageType.Type.AFFLICTION)
			Character.resolve_damage(context, user, mod_damage / 2, DamageType.Type.AFFLICTION)
		else:
			Character.resolve_damage(context, user, mod_damage, DamageType.Type.AFFLICTION)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 45)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
