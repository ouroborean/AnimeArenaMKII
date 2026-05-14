extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Yuji heals himself for 15 HP, permanently increases the initial damage dealt by Divergent Fist by 5, and permanently increases the minimum chance for Black Flash to activate by 15%."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_healing(context, user, 15)
	
	if user.has_effect("Black Flash", EffectType.Type.MARK):
		user.black_flash_minimum += 15
		var flash = user.has_effect("Black Flash", EffectType.Type.MARK)
		if flash.mag <= user.black_flash_minimum:
			user.manually_advance_mission(8, user.black_flash_minimum - flash.mag)
			flash.mag = user.black_flash_minimum
	var mark = Effect.mark(-1, "Divergent Fist will deal 5 more initial damage.")
	mark.set_source(self)
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.update.emit()

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 2.5)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
