extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, enemies have their strategic skills delayed for 1 turn and Nightmare Wavelength deals 20 more damage."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.has_effect("Scythe Transformation", EffectType.Type.PERCENT_DR, user):
		user.manually_advance_mission(10, 1)
	
	for target in user.targeter.targets:
		var delay_eff = Effect.delay_eff(1, 6, 1, ["Strategic"])
		delay_eff.set_source(self)
		
		Character.add_hostile_effect(context, user, target, delay_eff)
	var boost_eff = Effect.mark(5, "Nightmare Wavelength will deal 20 more damage.")
	boost_eff.set_source(self)
	Character.add_allied_effect(context, user, user, boost_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
