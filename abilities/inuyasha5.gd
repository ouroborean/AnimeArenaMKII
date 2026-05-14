extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Every 2 turns, Inuyasha's demon blood awakens or wanes for 2 turns",
		["While awakened, Inuyasha's Harmful skills deal 50% more damage and cost 1 more Random energy", Color.CADET_BLUE],
		["While waning, Inuyasha's Harmful skills deal half damage and cost 1 less Red energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "When this counter reaches 0, Inuyasha's demon blood will awaken or wane.")
	ticking.mag = 2
	ticking.display_mag = true
	ticking.set_source(self)
	Character.add_allied_effect(context, user, user, ticking)
	
	var dmg_trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "Blades of Blood will re-trigger for each time Inuyasha takes new damage, up to 2 extra times.")
	dmg_trigger.set_source(user.moveset.base_abilities[1])
	dmg_trigger.display_mag = true
	Character.add_allied_effect(context, user, user, dmg_trigger)

func damage_trigger(context):
	var trigger = user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER)
	trigger.mag += 1
	if trigger.mag >= 3:
		trigger.mag = 2

func tick_trigger(context):
	var tick = user.has_effect("Hanyo Cycle", EffectType.Type.TICKING_TRIGGER)
	tick.mag -= 1
	if tick.mag == 0:
		var roll = user.battle.roll(1, 2)
		tick.display_mag = false
		tick.description = func (eff): return "The cycle will begin again once Inuyasha's demon blood returns to normal."
		tick.mag = 5
		match roll:
			1:
				var mark = Effect.mark(5, "Inuyasha's demon blood has awakened.")
				mark.set_source(self)
				mark.mag = 1
				var cost_mod = Effect.cost_mod_effect(1, 5, Energy.Type.RANDOM, ["Wind Scar", "Iron Reaver Soul Stealer", "Blades of Blood"])
				cost_mod.set_source(self)
				Character.add_allied_effect(context, user, user, mark)
				Character.add_allied_effect(context, user, user, cost_mod)
			2:
				var mark = Effect.mark(5, "Inuyasha's demon blood has waned.")
				mark.set_source(self)
				mark.mag = 2
				var cost_mod = Effect.cost_mod_effect(-1, 5, Energy.Type.RED, ["Wind Scar", "Iron Reaver Soul Stealer", "Blades of Blood"])
				cost_mod.set_source(self)
				Character.add_allied_effect(context, user, user, mark)
				Character.add_allied_effect(context, user, user, cost_mod)
	elif tick.mag == 3:
		tick.display_mag = true
		tick.description = func (eff): return "When this counter reaches 0, Inuyasha's demon blood will awaken or wane."

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
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
