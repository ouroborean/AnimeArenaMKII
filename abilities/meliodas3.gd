extends Ability
var base_amp = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Meliodas targets an enemy for one turn. If that enemy uses a harmful Energy or Affliction skill, it will be reflected to them. Invisible until triggered."

func split_desc():
	return [
		"For 2 turns, Meliodas ignores non-damage effects and cannot use skills",
		["When this effect expires, Meliodas can use it for no cost to deal 30 Piercing damage to target enemy", Color.ORANGE_RED],
		["+30 damage per Harmful skill received while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.marked_by("Revenge Counter") and user.has_effect("Revenge Counter", EffectType.Type.MARK).mag > 0:
		for target in user.targeter.targets:
			var mag = user.has_effect("Revenge Counter", EffectType.Type.MARK).mag
			Character.resolve_damage(context, target, 30 * mag, DamageType.Type.PIERCING)
	else:
		var non_damage = Effect.ignore_non_damage_effect(4)
		non_damage.set_source(self)
		non_damage.invisible = true
		Character.add_allied_effect(context, user, user, non_damage)
		var mark = Effect.mark(4, "Meliodas cannot use skills.")
		mark.set_source(self)
		mark.invisible = true
		Character.add_allied_effect(context, user, user, mark)
		var receive_trigger = Effect.trigger_effect(Trigger.always(trigger_func), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 4, "For each Harmful skill Meliodas receives, Revenge Counter will deal +30 damage.")
		receive_trigger.set_source(self)
		receive_trigger.mag = 1
		receive_trigger.invisible = true
		receive_trigger.display_mag = true
		receive_trigger.wrapup_func = prep_trigger
		Character.add_allied_effect(context, user, user, receive_trigger)
	
func prep_trigger(context):
	var storage = context.effect
	var mark = Effect.mark(2, "Meliodas can use Revenge Counter to deal " + str(storage.mag * 30) + " Piercing damage to target enemy.")
	mark.set_source(self)
	mark.mag = storage.mag
	Character.add_allied_effect(context, user, user, mark)
	var cost_change = Effect.cost_change_effect({}, 2, ["Revenge Counter"])
	cost_change.set_source(self)
	Character.add_allied_effect(context, user, user, cost_change)
	var target_change = Effect.target_change_effect(TargetType.Type.SINGLE, 2, ["Revenge Counter"])
	target_change.set_source(self)
	Character.add_allied_effect(context, user, user, target_change)
	

func trigger_func(context):
	context.effect.mag += 1

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Revenge Counter") or (user.has_effect("Revenge Counter", EffectType.Type.MARK) and user.has_effect("Revenge Counter", EffectType.Type.MARK).mag > 0)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Revenge Counter") and user.has_effect("Revenge Counter", EffectType.Type.MARK).mag > 0:
		default_hostile_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
