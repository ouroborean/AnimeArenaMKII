extends Ability

var base_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Lucy deals 15 damage to all enemies and grants her team 10 points of damage reduction for one turn."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var duration = 2
	
	if user.marked_by("Gemini", user):
		duration += 2
	
	for target in user.targeter.targets:
		if not target in context['enemy_team'].characters:
			var dr = Effect.damage_reduction_effect(10, duration)
			dr.set_source(self)
			Character.add_allied_effect(context, user, target, dr)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			if duration == 4:
				var dmg_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
				dmg_eff.set_source(self)
				Character.add_hostile_effect(context, user, target, dmg_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 50)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
