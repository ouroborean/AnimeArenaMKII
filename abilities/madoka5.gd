extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Passive: Whenever one of Madoka's Shield or Nullify effects is fully absorbed, this effect gains one stack. If Madoka reaches 15 stacks of this effect, she is instantly killed."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive_mark = Effect.mark(-1, "Whenever one of Madoka's Shield or Nullify effects is fully broken, this effect gains one stack. If Madoka reaches 15 stacks of this effect, she is instantly killed.")
	passive_mark.set_source(self)
	passive_mark.mag = 0
	passive_mark.display_mag = true
	Character.add_allied_effect(context, user, user, passive_mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
