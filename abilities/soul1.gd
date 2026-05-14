extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, target ally wields Soul. During this time, Soul gains 10 Damage Reduction, and the targeted ally deals 5 more non-Affliction damage and has their Red costs changed to Random costs."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var soul_count = 0
	if user.has_effect("Consume Soul", EffectType.Type.MARK, user):
		soul_count = user.has_effect("Consume Soul", EffectType.Type.MARK, user).stacks
	user.manually_advance_mission(9, 1)
	for target in user.targeter.targets:
		var wield_eff = Effect.mark(6, "This character is wielding Soul.")
		wield_eff.set_source(self)
		var boost_eff = Effect.damage_mod_effect(5 * (soul_count + 1), 6, [], [], [DamageType.Type.AFFLICTION])
		boost_eff.set_source(self)
		var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.RED, 6)
		color_change.set_source(self)
		
		Character.add_allied_effect(context, user, target, wield_eff)
		Character.add_allied_effect(context, user, target, boost_eff)
		Character.add_allied_effect(context, user, target, color_change)

	var percent_dr = Effect.damage_reduction_effect(10, 6)
	percent_dr.set_source(self)
	Character.add_allied_effect(context, user, user, percent_dr)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var partner = false
	for character in context['ally_team'].characters:
		if character.path_name == "maka":
			partner = true
	
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if not character.is_isolated() and not (character.dead or character.banished) and not character == context['owner'] and (not partner or character.path_name == "soul"):
			variations.append([100, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var partnered = Condition.has_effect(user, "Partner: Maka", EffectType.Type.MARK, user)
	if not partnered.satisfied(context):
		default_allied_target_function(user, battle)
	else:
		for character in user.team.characters:
			if character.path_name == "maka":
				check_allied_target(user, character, context)
