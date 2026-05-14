extends Ability

var base_damage = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 5 Piercing damage to target enemy, then 5 Piercing damage to a random target for each stack of Card Throw on Hisoka. Gives Hisoka 1 stack of Card Throw. When Hisoka gains his 5 stack of Card Throw, this skill is replaced by Flamboyant Execution for 1 turn."

func split_desc():
	return [
		"Deals 5 Piercing damage to target enemy, then 5 Piercing damage to a random target for each stack of Card Throw on Hisoka",
		["Gives Hisoka 1 stack of Card Throw", Color.DIM_GRAY],
		["When Hisoka gains his 5 stack of Card Throw, this skill is replaced by Flamboyant Execution for 1 turn", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	# 1. Deal initial damage to the primary target
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	
	# 2. Check for existing stacks of Card Throw
	var card_throw_eff = user.has_effect("Card Throw", EffectType.Type.MARK, user)
	var stacks = 0
	if card_throw_eff:
		stacks = card_throw_eff.stacks
	
	# 3. Deal random damage based on CURRENT stacks (before adding the new one)
	if stacks > 0:
		var potential_targets = []
		for enemy in context['enemy_team'].characters:
			if not (enemy.dead or enemy.banished or enemy.is_invuln(self)):
				potential_targets.append(enemy)
		
		if potential_targets.size() > 0:
			for i in range(stacks):
				var roll = battle.roll(0, potential_targets.size() - 1)
				var chosen_enemy = potential_targets[roll]
				Character.resolve_damage(context, chosen_enemy, base_damage, DamageType.Type.PIERCING)

	# 4. Apply new stack of Card Throw
	var mark = Effect.mark(-1, "Hisoka will target a random extra target with Card Throw.")
	mark.set_source(self)
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	
	# 5. Check if we reached 5 stacks (stacks + the one we just added)
	if stacks + 1 >= 5:
		# Duration 2 ensures it lasts through the enemy turn and is available for Hisoka's next turn
		# The last argument '0' refers to the index of "Flamboyant Execution" in Hisoka's alternate/extra skills list.
		var swap = Effect.ability_swap_effect(5, 0, user, 3)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	return true
	
func custom_behavior(context):
	# AI logic: High priority if we have many stacks (high damage potential)
	var variations = []
	var user = context['owner']
	var stacks = 0
	if user.has_effect("Card Throw", EffectType.Type.MARK, user):
		stacks = user.has_effect("Card Throw", EffectType.Type.MARK, user).stacks
	
	# Base weight 50, +10 for every stack he has
	variations += behavior_single_target_damage(context, 50 + (10 * stacks))
	
	return variations
	
func target(user, battle):
	default_hostile_target_function(user, battle)
