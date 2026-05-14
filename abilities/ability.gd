extends Resource


@export var ability_name: String
@export_multiline var ability_description: String
@export var cooldown: int
@export var _cost = {
	"Green": 0,
	"Blue": 0,
	"White": 0,
	"Red": 0,
	"Random": 0
}
@export var classes = {
	"Physical": false,
	"Energy": false,
	"Mental": false,
	"Affliction": false,
	"Strategic": false,
	"Harmful": false,
	"Helpful": false,
	"Instant": false,
	"Action": false,
	"Control": false,
	"Channeled": false,
	"Uncounterable": false,
	"Bypassing": false,
	"Stealthed": false,
	"Blessed": false,
	"Passive": false,
	"Preserves Channel": false
}
@export var image: Texture
@export var _target_type: TargetType.Type
@export var selfless: bool
var user = null
var minimum_damage = 0
var modifier_value = 1
var cooldown_remaining = 0
var ability_blinded = false
var stunnable = true
var important = false
var invisible = false

func cost():
	var output_dict = {
		0: 0,
		1: 0,
		2: 0,
		3: 0,
		4: 0
	}
	
	for element in _cost:
		if _cost[element] != 0:
			output_dict[element] = _cost[element]
	
	#Check for effects that override the entire cost of the ability
	for effect in user.effects.get_effects_by_type(EffectType.Type.COST_CHANGE):
		if effect.ability_targets == []:
			output_dict = {
				0: 0,
				1: 0,
				2: 0,
				3: 0,
				4: 0
			}
			for key in effect.alternative_cost.keys():
				output_dict[key] = effect.alternative_cost[key]
		else:
			if ability_name in effect.ability_targets:
				output_dict = {
					0: 0,
					1: 0,
					2: 0,
					3: 0,
					4: 0
				}
				for key in effect.alternative_cost.keys():
					output_dict[key] = effect.alternative_cost[key]
	
	#Check for effects that modify costs up or down
	for effect in user.effects.get_effects_by_type(EffectType.Type.COST_MOD):
		if effect.ability_targets == []:
			output_dict[effect.cost_change_element] += effect.mag
			if output_dict[effect.cost_change_element] < 0:
				output_dict[effect.cost_change_element] = 0
		else:
			if ability_name in effect.ability_targets:
				output_dict[effect.cost_change_element] += effect.mag
				if output_dict[effect.cost_change_element] < 0:
					output_dict[effect.cost_change_element] = 0
	
	#Check for effects that change colors to other colors
	for effect in user.effects.get_effects_by_type(EffectType.Type.COLOR_CHANGE):
		if effect.ability_targets == []:
			var total_cost = output_dict[effect.cost_change_element]
			output_dict[effect.cost_change_element] -= total_cost
			output_dict[effect.mag] += total_cost
			if output_dict[effect.cost_change_element] < 0:
				output_dict[effect.cost_change_element] = 0
			if output_dict[effect.mag] < 0:
				output_dict[effect.mag] = 0
		else:
			if ability_name in effect.ability_targets:
				var total_cost = output_dict[effect.cost_change_element]
				output_dict[effect.cost_change_element] -= total_cost
				output_dict[effect.mag] += total_cost
				if output_dict[effect.cost_change_element] < 0:
					output_dict[effect.cost_change_element] = 0
				if output_dict[effect.mag] < 0:
					output_dict[effect.mag] = 0
	
	return output_dict

func reflect_trigger(context):
	var attacker = context['owner']
	if attacker.used_ability.target_type() != TargetType.Type.SINGLE:
		return
	attacker.targeter.targets.erase(context['target'])
	attacker.targeter.targets.append(context['effect'].mag)

func target_type():
	var tt = _target_type
	
	for effect in user.effects.get_effects_by_type(EffectType.Type.TARGET_CHANGE):
		if effect.ability_targets == []:
			tt = TargetType.Type.values()[effect.mag]
		else:
			if ability_name in effect.ability_targets:
				tt = TargetType.Type.values()[effect.mag]
	
	return tt

func describe(user):
	pass

func usable(user):
	#TODO: Holy fuck a lot goes here. You know the stuff
	var energy_pool = user.team.energy
	if not energy_pool.can_afford(cost()):
		return false
	if user.battle.waiting_for_turn:
		return false
	if cooldown_remaining > 0:
		return false
	if user.is_stunned(self):
		return false
	if user.used_ability != null or user.waiting:
		return false
	var relinquished_mark = user.marked_by("Relinquished")
	if relinquished_mark and ability_name in relinquished_mark.ability_targets:
		return false
	if not extra_usable(user):
		return false
	return true

func extra_usable(user):
	return true

func delay_execution(user, battle, length):
	var context = QueryContext.from_game_state(user, battle)
	var delayed_skill = Effect.delayed_skill_eff(self, user.targeter.targets, user.targeter.main_target, 1 + (2 * length))
	delayed_skill.set_source(self)
	Character.add_allied_effect(context, user, user, delayed_skill, true)
	
	for target in user.targeter.targets:
		var skill_marker = Effect.delay_target_marker(self, 1 + (2 * length))
		skill_marker.set_source(self)
		Character.add_allied_effect(context, user, target, skill_marker, true)

func is_delayed():
	var highest_mag = 0
	for delay_eff in user.get_delay_effects():
		if delay_eff.ability_targets == []:
			if delay_eff.stackable:
				delay_eff.consume_stack(1)
			if delay_eff.mag > highest_mag:
				highest_mag = delay_eff.mag

		else:
			for target in delay_eff.ability_targets:
				if classes[target]:
					if delay_eff.stackable:
						delay_eff.consume_stack(1)
					if delay_eff.mag > highest_mag:
						highest_mag = delay_eff.mag
					break
	return highest_mag

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)

func modify_damage_by_stats(damager, target, damage, offense_stat, defense_stat):
	var mod_damage = damage
	mod_damage = damager.stats.modify_outgoing_damage_by_stat(mod_damage, offense_stat, damager)
	mod_damage = target.stats.modify_incoming_damage_by_stat(mod_damage, defense_stat, target)
	return mod_damage

func start_cooldown():
	
	var mods = user.get_cooldown_mods()
	var cooldown_mod = 0
	for mod in mods:
		if mod.ability_targets == []:
			if mod.per_stack:
				cooldown_mod += (mod.mag * mod.stack_count())
			else:
				cooldown_mod += mod.mag
		else:
			if ability_name in mod.ability_targets:
				if mod.per_stack:
					cooldown_mod += (mod.mag * mod.stack_count())
				else:
					cooldown_mod += mod.mag
	
	cooldown_remaining = cooldown + 1 + cooldown_mod

func get_true_damage(damager, target, damage):
	var mod_damage = damage
	#Get specific damage boosting effects from the user
	#TODO: Add "no boost" check
	var damage_boosties = damager.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD)
	
	for boost in damage_boosties:
		if boost.class_targets != []:
			var fail = true
			for class_target in boost.class_targets:
				if classes[class_target]:
					fail = false
			if fail:
				continue
		if boost.exclusion_targets != []:
			var fail = false
			for class_target in boost.exclusion_targets:
				if classes[class_target]:
					fail = true
			if fail:
				continue
		if boost.ability_targets == []:
			if boost.per_stack:
				mod_damage += (boost.mag * boost.stack_count()) * modifier_value
			else:
				mod_damage += boost.mag * modifier_value
		else:
			if damager.used_ability.ability_name in boost.ability_targets:
				if boost.per_stack:
					mod_damage += (boost.mag * boost.stack_count()) * modifier_value
				else:
					mod_damage += boost.mag * modifier_value
	if mod_damage < 0:
		mod_damage = 0
		
	
	var vulnerabilities = target.effects.get_effects_by_type(EffectType.Type.VULNERABILITY)
	for vuln in vulnerabilities:
		if vuln.class_targets != []:
			var fail = true
			for class_target in vuln.class_targets:
				if classes[class_target]:
					fail = false
			if fail:
				continue
		if vuln.exclusion_targets != []:
			var fail = false
			for class_target in vuln.exclusion_targets:
				if classes[class_target]:
					fail = true
			if fail:
				continue
		if vuln.ability_targets == []:
			if vuln.per_stack:
				mod_damage += (vuln.mag * vuln.stack_count())
			else:
				mod_damage += vuln.mag
		else:
			if damager.used_ability.ability_name in vuln.ability_targets:
				if vuln.per_stack:
					mod_damage += (vuln.mag * vuln.stack_count())
				else:
					mod_damage += vuln.mag
	
	mod_damage = extra_damage_calc(damager, target, mod_damage)
	return mod_damage

func extra_damage_calc(damager, target, damage):
	return damage

func and_target(character):
	return false

func get_true_healing(healer, target, healing):
	var mod_healing = healing
	
	#TODO: Get specific healing boosts
	
	return mod_healing

func get_true_shielding(shielder, target, shielding):
	var mod_shielding = shielding
	
	#TODO: get specific shielding boosts
	
	return mod_shielding

func check_hostile_target(user, target, context, bypassing=false):
	if Condition.can_hostile_target(user, target, self, bypassing).satisfied(context):
		target.set_targeted()

func check_allied_target(user, target, context, bypassing=false):
	if Condition.can_allied_target(user, target, bypassing).satisfied(context):
		target.set_targeted()

func default_hostile_target_function(user, battle, bypassing=false):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		check_hostile_target(user, character, context, bypassing)

func default_allied_target_function(user, battle, bypassing = false):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if selfless and character == user:
			continue
		check_allied_target(user, character, context, bypassing)

func default_self_target_function(user, battle, bypassing = false):
	var context = QueryContext.from_game_state(user, battle)
	check_allied_target(user, user, context, bypassing)

func default_counter_timeout(context):
	var effect = Effect.invisible_expiration_effect(self)
	effect.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['target'], effect)

func default_defend(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var eff = Effect.invuln_effect(2)
	eff.set_source(self)
	Character.add_allied_effect(context, user, user, eff)

func default_counter_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	
	var notification_effect = Effect.counter_notification_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, notification_effect)
	
	counter_eff_target.effects.remove_effect(context['effect'].source.ability_name, context['effect'].effect_type, context['effect'].user)
