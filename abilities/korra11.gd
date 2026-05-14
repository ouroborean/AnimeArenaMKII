extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Passive: If Korra uses a skill from the same element 5 times she will activate the avatar state for 4 turns: If Fire: Deals 10 affliction damage to any enemy that uses a new skill on her, If Earth: Grants 40 permanent Shield, If Water: gives 20 damage reduction, If Air: makes Korra ignore all non-damage harmful effects. While active, Earth Control and Water Control swap to 'Energybending' and 'Gate Open'. This can only occur once per game."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var fire_desc = func (eff):
		return "Korra has used " + str(eff.mag) + " Fire skills."
	var fire_mark = Effect.mark(-1, fire_desc)
	fire_mark.invisible = true
	fire_mark.display_mag = true
	fire_mark.set_source(user.moveset.base_abilities[0])
	var air_desc = func (eff):
		return "Korra has used " + str(eff.mag) + " Air skills."
	var air_mark = Effect.mark(-1, air_desc)
	air_mark.invisible = true
	air_mark.display_mag = true
	air_mark.set_source(user.moveset.base_abilities[1])
	var earth_desc = func (eff):
		return "Korra has used " + str(eff.mag) + " Earth skills."
	var earth_mark = Effect.mark(-1, earth_desc)
	earth_mark.invisible = true
	earth_mark.display_mag = true
	earth_mark.set_source(user.moveset.base_abilities[2])
	var water_desc = func (eff):
		return "Korra has used " + str(eff.mag) + " Water skills."
	var water_mark = Effect.mark(-1, water_desc)
	water_mark.invisible = true
	water_mark.display_mag = true
	water_mark.set_source(user.moveset.base_abilities[3])
	var trigger = Effect.trigger_effect(Trigger.always(avatar_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "If Korra uses a skill from the same element 5 times, she will enter a corresponding Avatar state.")
	trigger.set_source(self)
	trigger.waiting = false
	
	
	
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, fire_mark)
	Character.add_allied_effect(context, user, user, air_mark)
	Character.add_allied_effect(context, user, user, earth_mark)
	Character.add_allied_effect(context, user, user, water_mark)
	

func avatar_trigger(context):
	var used_ability = context['source']
	var user = context['owner']
	var mark_word = ""
	if used_ability.ability_name == "Fire Control" or used_ability.ability_name == "Fire Fist":
		mark_word = "Fire"
	elif used_ability.ability_name == "Air Control" or used_ability.ability_name == "Air Wave":
		mark_word = "Air"
	elif used_ability.ability_name == "Earth Control" or used_ability.ability_name == "Earth Area Attack":
		mark_word = "Earth"
	elif used_ability.ability_name == "Water Control" or used_ability.ability_name == "Water Arm Stun":
		mark_word = "Water"
	var effect = user.effects.has_effect(mark_word + " Control", EffectType.Type.MARK, user)
	effect.change_mag(1)
	if effect.mag >= 5:
		user.effects.remove_effect("Fire Control", EffectType.Type.MARK, user)
		user.effects.remove_effect("Air Control", EffectType.Type.MARK, user)
		user.effects.full_remove_effect_by_name("Earth Control", user)
		user.effects.full_remove_effect_by_name("Water Control", user)
		user.effects.remove_effect("Korra Avatar State", EffectType.Type.ACTION_USE_TRIGGER, user)
		var swap1 = Effect.ability_swap_effect(8, 2, user, 9)
		swap1.set_source(self)
		var swap2 = Effect.ability_swap_effect(9, 3, user, 9)
		swap2.set_source(self)
		var portrait = Effect.portrait_change_effect(0, 9)
		portrait.set_source(self)
		Character.add_allied_effect(context, user, user, portrait)
		
		
		Character.add_allied_effect(context, user, user, swap1)
		Character.add_allied_effect(context, user, user, swap2)
		
		if mark_word == "Fire":
			var trigger_eff = Effect.trigger_effect(Trigger.always(fire_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 8, "Korra will deal 10 Affliction damage to any enemy that uses a new skill on her.")
			trigger_eff.set_source(self)
			Character.add_allied_effect(context, user, user, trigger_eff)
		elif mark_word == "Air":
			var ignore_eff = Effect.ignore_non_damage_effect(9)
			ignore_eff.set_source(self)
			Character.add_allied_effect(context, user, user, ignore_eff)
		elif mark_word == "Water":
			var damage_red = Effect.damage_reduction_effect(20, 8)
			damage_red.set_source(self)
			Character.add_allied_effect(context, user, user, damage_red)
		elif mark_word == "Earth":
			var shield = Effect.shield_effect(40, 8)
			shield.set_source(self)
			Character.add_allied_effect(context, user, user, shield)

func fire_trigger(context):
	var attacker = context['owner']
	Character.resolve_effect_damage(context, context['effect'], attacker, 10, DamageType.Type.AFFLICTION)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
