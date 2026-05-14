extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Affliction damage to one enemy for 2 turns. During this time, they are Silenced."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var blooded = user.marked_by("Bloody Knife", user)
	
	if blooded:
		health_drain = true
	var stacks = 0
	if user.marked_by("Friendly Smile", user):
		stacks = user.effects.has_effect("Friendly Smile", EffectType.Type.MARK).stack_count()
		user.manually_advance_mission(10, stacks)
		user.effects.full_remove_effect_by_name("Friendly Smile", user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var damage = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 3 + (stacks * 2))
		damage.set_source(self)
		if blooded:
			damage.health_drain = true
		Character.add_hostile_effect(context, user, target, damage)
		var silence = Effect.silence_effect(3 + (stacks * 2))
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)
	health_drain = false
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 55)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
