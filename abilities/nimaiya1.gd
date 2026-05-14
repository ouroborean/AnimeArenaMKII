extends Ability
var base_damage = 10
var extra_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 True damage to target enemy, then 5 True damage for each other time this skill has been used during this battle. Bypasses."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	
	if user.has_effect("Sheath Dodger", EffectType.Type.INVULN):
		user.manually_advance_mission(7, 1)
	
	for target in user.targeter.targets:
		#Deals 5 True damage to the enemy
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		#Repeats once for every stack it has
		if user.has_effect("Unblockable Strike", EffectType.Type.MARK, user):
			for i in user.has_effect("Unblockable Strike", EffectType.Type.MARK, user).stacks:
				Character.resolve_damage(context, target, extra_damage, DamageType.Type.TRUE)
		#Gains a stack
	var use_counter = Effect.mark(-1, func (eff): return "Oetsu will strike " + str(eff.stacks) + " additional times with Unblockable Strike.")
	use_counter.set_source(self)
	use_counter.stackable = true
	use_counter.display_stacks = true
	Character.add_allied_effect(context, user, user, use_counter)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.0, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
