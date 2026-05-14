extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Mine targets one enemy. For 3 turns, Mine's skills become Uncounterable and Bypassing, and they deal 10 more damage to that enemy."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var mark = Effect.mark(6, "Mine's skills are Uncounterable and Bypassing.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

	var ignore_counter = Effect.ignore_counter_effect(6)
	ignore_counter.set_source(self)
	Character.add_allied_effect(context, user, user, ignore_counter)

	for target in user.targeter.targets:
		var vuln = Effect.vulnerability_effect(10, 6, ["Roman Artillery - Pumpkin", "High Output Blast Blade"])
		vuln.set_source(self)
		Character.add_hostile_effect(context, user, target, vuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 60)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
