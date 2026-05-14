extends Ability
var base_healing = 50
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Soul heals 50 health and permanently increases the bonus damage effect from Scythe Transformation by 5. Soul must deal 100 damage before each use of this skill."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)	
	Character.resolve_healing(context, user, 50)
	user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user).mag -= 100
	user.effects.has_effect("Consume Soul", EffectType.Type.MARK, user).stacks += 1
		
func extra_usable(user):
	return user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) != null and user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user).mag >= 100

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.4)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
	
