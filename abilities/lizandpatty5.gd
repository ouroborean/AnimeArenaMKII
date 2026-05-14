extends Ability

func describe(user):
	return "Deals 15 Piercing damage to target enemy and gives the ally wielding Liz 10 Shield. Can only be used if Liz is currently being wielded."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy.",
		"Gives the ally wielding Liz 10 Shield.",
		["Can only be used if Liz is currently being wielded.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
	var wielder = _find_wielder(user)
	if wielder != null:
		var shield = Effect.shield_effect(10, -1)
		shield.set_source(self)
		Character.add_allied_effect(context, user, wielder, shield)

func _find_wielder(user):
	# Wielder marks are sourced from Transform (effect_name "Transform: Demon
	# Twin Guns") with mag encoding sister identity: 0 = Liz, 1 = Patty, 2 =
	# both (Death the Kid dual-wield synergy — see kid5).
	for character in user.team.characters:
		var mark = character.has_effect("Transform: Demon Twin Guns", EffectType.Type.MARK, user)
		if mark != null and (mark.mag == 0 or mark.mag == 2):
			return character
	return null

func extra_usable(user):
	return _find_wielder(user) != null

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
