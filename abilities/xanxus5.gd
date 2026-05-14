extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Passive: The first time Xanxus receives normal damage, Scoppio d'Ira permanently deals 5 more damage, Martello di Flamma costs 1 less Random energy, and Sky Flame Deflection has 1 less cooldown. The same is true for receiving Piercing damage, receiving Affliction damage, being stunned, being countered, being shattered, being isolated, and being reduced below half health."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var wrath_eff = Effect.xanxus_storage_effect()
	wrath_eff.set_source(self)
	Character.add_allied_effect(context, user, user, wrath_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
