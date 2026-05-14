extends Node
class_name Effect

@export var _name: NameComponent

var effect_type: EffectType.Type
var user = null
var target = null
var trigger
var source
var removed = false
var damage_type = null
var duration = 0
var mag = 0
var stacks = 1
var cancel_effects = []
var stackable = false
var invisible = false
var refresh = false
var description = "A sample effect tooltip."
var tooltip
var element = Element.Type.GENERIC
var id
var health_drain = false
var unique_render_id = 0
var ability_targets = []
var character_targets = []
var exclusion_targets = []
var class_targets = []
var type_targets = []
var storage = {}
var character_target
var cost_change_element
var alternative_cost = {}
var wrapup_func = wrap_up
var shield_func = shield_callback
var barrier_func = barrier_callback
var redirect_func = redirect_callback
var conditional_func = conditional_callback
var tick_during_banish = false
var system = false
var remove_on_death = true
var bleed = false
var serum = false
var action = false
var cancel = false
var channel = false
var cleansable = true
var triggered = false
var trigger_once = false
var remove_once_triggered = false
var full_remove_once_triggered = false
var last_turn_only = false
var ability_only = false
# When true on a MARK effect, blocks ability use on the marked character.
# If `ability_targets` is non-empty, only the named abilities are sealed;
# otherwise all of the character's skills are sealed. This is NOT a stun —
# stun-shrugging effects (Gunha's Guts, etc.) do not interact with it.
var skill_seal = false
var display_mag = false
var display_stacks = false
var stack_mag = false
var per_stack = false
var bypassing = false
var use_source_damage = false
var delay_targets
var delay_main_target
var delay_skill
var waiting = false
var fresh_stack = false
var breaker
var twin_priority = 3
signal effect_expired(effect)
signal effect_updated(effect)

static func default_invuln_desc():
	var desc = func (eff):
		return "This character is invulnerable."
	return desc

func stack_count():
	if fresh_stack:
		return stacks
	else:
		return stacks

func wrap_up(context):
	pass

func shield_callback(context):
	pass

func barrier_callback(context):
	pass

func redirect_callback(context):
	pass

func conditional_callback(eff):
	return false

func triggerable():
	return not triggered or not trigger_once

func trigger_check(effect_storage):
	if triggered:
		if remove_once_triggered:
			effect_storage.remove_effect(source.ability_name, effect_type, user)
		elif full_remove_once_triggered:
			effect_storage.full_remove_effect_by_name(source.ability_name, user)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func origin_match(eff: Effect):
	return eff.effect_type == effect_type and eff.source.ability_name == source.ability_name and eff.id == id

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

static func damage_effect(damage: int, damage_type: DamageType.Type = DamageType.Type.NORMAL, dur=1, use_source = true):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE
	effect.damage_type = damage_type
	effect.use_source_damage = use_source
	effect.mag = damage
	effect.description = func desc(eff):
		return "This character will take " + str(eff.mag) + " " + DamageType.Type.keys()[eff.damage_type].capitalize() + " damage."
	
	#TODO check for damage boosties?
	effect.set_duration(dur)
	return effect

static func stealth_effect(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.STEALTH
	effect.description = func desc (eff):
		return "This character's skills will not trigger enemy effects."
	effect.set_duration(dur)
	return effect

static func immortality_effect(dur = 1):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IMMORTALITY
	effect.description = func desc (eff):
		return "This character cannot be killed."
	effect.set_duration(dur)
	return effect

static func health_cap_effect(mag, dur: int = 1):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HEALTH_CAP
	effect.description = func desc (eff):
		return "This character's maximum health is capped at " + str(mag) + "."
	effect.set_duration(dur)
	effect.mag = mag
	return effect

static func healing_effect(healing: int, dur: int):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HEALING
	effect.mag = healing
	effect.description = func desc(eff):
		return "This character will heal " + str(eff.mag) + " health."
	effect.set_duration(dur)
	
	return effect

static func trigger_effect(trig: Trigger, trigger_type: EffectType.Type, dur=1, desc=""):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = trigger_type
	if trigger_type in EffectType.use_or_receive_triggers():
		effect.waiting = true
	effect.set_duration(dur)
	effect.trigger = trig
	if desc is String:
		effect.description = func desc(eff):
			return desc
	else:
		effect.description = desc
	
	return effect

static func control_cancel(dur, ability_name, cancel_effects):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.CONTROL_CANCEL
	effect.set_duration(dur)
	effect.cancel_effects = cancel_effects
	effect.description = func desc(eff):
		return "This character is controlling " + ability_name + ". If they are stunned, it will be cancelled."
	
	return effect

static func channel_cancel(dur, ability_name, cancel_effects):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.CHANNEL_CANCEL
	effect.set_duration(dur)
	effect.cancel_effects = cancel_effects
	effect.description = func desc(eff):
		return "This character is channeling " + ability_name + ". If they are stunned or use a new skill, it will be cancelled."
	
	return effect

static func sharpshooter(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.SHARPSHOOTER
	effect.set_duration(dur)
	effect.description = func desc(eff):
		return "This character cannot Miss or be Dodged."
	return effect

static func redirect_effect(mag, char_target, dur):
	
	var effect = load("res://components/effect_component.tscn").instantiate()
	
	effect.effect_type = EffectType.Type.DAMAGE_REDIRECT
	effect.set_duration(dur)
	effect.mag = mag
	effect.character_target = char_target
	
	effect.description = func desc(eff):
		return "This Hero will redirect " + str(eff.mag * 100) + "% of damage taken to " + eff.character_target.character_name.capitalize()
	
	return effect

static func damage_null_effect(mag, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE_NULLIFICATION
	effect.set_duration(dur)
	effect.mag = mag
	effect.description = func (eff):
		return "This character will deal " + str(int(mag*100)) + "% less damage."
	return effect

static func counter_effect(counter_trigger, eff_type, dur=1, desc="", counter_types = [], counter_exclude_types = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = eff_type
	effect.set_duration(dur)
	effect.trigger = counter_trigger
	effect.class_targets = counter_types
	effect.exclusion_targets = counter_exclude_types
	if desc is String:
		effect.description = func desc(eff):
			return desc
	else:
		effect.description = desc
	return effect

static func ignore_counter_effect(dur=1, ability_targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IGNORE_COUNTER
	effect.ability_targets = ability_targets
	var description = "This character's skills "
	
	if ability_targets != []:
		description = ""
		for target in ability_targets:
			description += target
			if ability_targets.find(target) == len(ability_targets) - 2:
				description += " and "
			elif ability_targets.find(target) < len(ability_targets) - 1:
				description += ", "
			else:
				description += " "
	description += " will ignore Counter and Reflect skills."
	effect.description = func (eff): return description
	
	effect.set_duration(dur)
	return effect
		

static func reflect_effect(reflect_trigger, eff_type, reflect_target, dur=1, desc="", counter_types = [], counter_exclude_types = [], count = -1):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = eff_type
	effect.set_duration(dur)
	effect.mag = reflect_target
	effect.trigger = reflect_trigger
	effect.class_targets = counter_types
	effect.exclusion_targets = counter_exclude_types
	effect.stacks = count
	if desc is String:
		effect.description = func desc(eff):
			return desc
	else:
		effect.description = desc
	return effect
	
static func counter_notification_effect(ability):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.COUNTER_TRIGGER_NOTIFICATION
	effect.set_duration(2)
	effect.description = func (eff):
		return "This character was countered by " + ability.ability_name + "."

	return effect

static func false_stun(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.FALSE_STUN
	effect.description = func (eff):
		return "Effects and skills will consider this character to be stunned."
	effect.set_duration(dur)
	return effect
	

static func banish_effect(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.BANISH
	effect.description = func (eff):
		return "This character is banished."
	effect.set_duration(dur)
	return effect

static func invisible_expiration_effect(ability, dur = 1):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.INVISIBLE_EXPIRATION
	effect.set_duration(dur)
	effect.description = func (eff):
		return ability.ability_name + " has ended."

	return effect

static func damage_mod_effect(mag, dur, targets=[], class_targets=[], exclusion_targets = [], type_targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE_MOD
	
	var mag_word = " more"
	if mag < 0:
		
		mag_word = " less"
	effect.type_targets = type_targets
	var type_word = ""
	
	var target_word = "This character"
	if targets != []:
		effect.ability_targets = targets
		target_word = ""
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += ""
		target_word += " will deal " + str(abs(mag)) + mag_word + " damage."
	elif class_targets != [] or exclusion_targets != []:
		effect.class_targets = class_targets
		effect.exclusion_targets = exclusion_targets
		target_word += " will deal " + str(abs(mag)) + mag_word + " "
		for target in class_targets:
			
			target_word += DamageType.get_damage_type_name(target, true)
			if class_targets.find(target) == len(class_targets) - 2:
				target_word += " or "
			elif class_targets.find(target) < len(class_targets) - 1:
				target_word += ", "
			else:
				target_word += " "
		for target in exclusion_targets:
			target_word += "non-" + DamageType.get_damage_type_name(target, true)
			if class_targets.find(target) == len(class_targets) - 2:
				target_word += " and "
			elif class_targets.find(target) < len(class_targets) - 1:
				target_word += ", "
			else:
				target_word += " "
		target_word += " damage."
	else:
		target_word += " will deal " + str(abs(mag)) + mag_word + " damage."
	effect.description = func desc(eff):
		
		return target_word
	
	effect.set_duration(dur)
	effect.mag = mag
	return effect

static func ignore_healing(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IGNORE_HEALING
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character will ignore all healing effects."
	return effect

static func damage_cap(cap, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE_CAP
	effect.mag = cap
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character cannot deal more than " + str(eff.mag) + " damage in a single hit."
	return effect

static func damage_cap_receive(cap, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE_CAP_RECEIVE
	effect.mag = cap
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character cannot receive more than " + str(eff.mag) + " damage in a single hit."
	return effect

static func cooldown_mod(mag, dur, targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.COOLDOWN_MOD
	effect.mag = mag
	effect.set_duration(dur)
	var mod_string = "increased by "
	if mag < 0:
		mod_string = "decreased by "
	
	var target_string = ""
	if targets != []:
		effect.ability_targets = targets
		for target in targets:
			target_string += target
			if targets.find(target) == len(targets) - 2:
				target_string += " and "
			elif targets.find(target) < len(targets) - 1:
				target_string += ", "
			else:
				target_string += " "
			
			target_string += "'s cooldown "
			if len(targets) > 1:
				target_string += "are "
			else:
				target_string += "is "
			target_string += mod_string + str(abs(mag)) + "." 
			
	else:
		target_string = "This character's cooldowns are " + mod_string + str(abs(mag)) + "."
		
	effect.description = func (eff):
		return target_string
	
	return effect

static func blind_effect(dur, targets=[], exclude=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.BLIND
	
	var target_word = "This character"
	if targets != [] or exclude != targets:
		target_word += "'s "
		effect.ability_targets = targets
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
			
		effect.exclusion_targets = exclude
		for target in exclude:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
		target_word += "skills are blinded."
	else:
		if len(exclude) > 1 and len(targets) > 1:
			target_word += " are "
		else:
			target_word += " is "
		target_word += "blinded."
	
	var desc = func (eff):
		return target_word
	
	effect.description = desc
	effect.set_duration(dur)
	return effect

static func paralyze_effect(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.PARALYZE
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character's cooldowns are paralyzed."
	return effect
	

static func portrait_change_effect(portrait_num, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.PORTRAIT_CHANGE
	effect.system = true
	effect.mag = portrait_num
	effect.set_duration(dur)
	return effect

static func healing_mod_effect(mag, dur, targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HEALING_MOD
	
	var mag_word = " more"
	if mag < 0:
		mag_word = " less"
	
	var target_word = "This character "
	if targets != []:
		effect.ability_targets = targets
		target_word = ""
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
	
	effect.description = func desc(eff):
		return target_word + "will give " + str(mag) + mag_word + " healing."
	
	effect.set_duration(dur)
	effect.mag = mag
	return effect

static func copy_effect(copied_skill, replace_slot, dur, user):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.SKILL_COPY
	effect.mag = replace_slot
	var path = copied_skill.get_script().get_path()
	var mod_path = path.substr(16, len(path) - 3 - 16)
	effect.ability_targets = Ability.from_database(mod_path)
	effect.ability_targets.user = user
	effect.set_duration(dur)
	effect.description = func (eff):
		return user.character_name + " has copied " + effect.ability_targets.ability_name + "."
	return effect


static func ignore_damage_effect(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IGNORE_DAMAGE
	effect.description = func desc(eff):
		return "This character is ignoring all incoming damage."
	effect.set_duration(dur)
	return effect

static func miss_effect(mag, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.MISS_CHANCE
	effect.mag = mag
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character has a " + str(mag) + "% chance to miss with their harmful skills."
	return effect
	
static func dodge_effect(mag, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DODGE_CHANCE
	effect.mag = mag
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character has a " + str(mag) + "% chance to fully dodge new harmful skills."
	return effect

static func ignore_effect_effect(dur, effect_type, helpful_only=false):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IGNORE_EFFECT
	effect.mag = effect_type
	effect.description = func desc(eff):
		var effect_type_string = EffectType.Type.keys()[effect_type].capitalize()
		effect_type_string.replace("_", " ")
		return "This character will ignore " + effect_type_string + " effects."
	
	effect.set_duration(dur)
	return effect

static func ignore_non_damage_effect(dur, exclusion_condition = null):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.IGNORE_NON_DAMAGE
	effect.description = func desc(eff):
		return "This character will ignore non-damage effects."
	
	pass
	
	if exclusion_condition != null:
		effect.conditional_func = exclusion_condition
	else:
		effect.conditional_func = effect.conditional_callback
	
	effect.set_duration(dur)
	return effect

static func cost_mod_effect(mag, dur, element, targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.COST_MOD
	var mag_word = " more"
	var mag_num = str(mag)
	if mag < 0:
		mag_word = " less"
		mag_num = str(mag * -1)
	
	var target_word = "This character's skills "
	if targets != []:
		effect.ability_targets = targets
		target_word = ""
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
	effect.cost_change_element = element
	effect.description = func desc(eff):
		return target_word + "cost " + mag_num + mag_word + " " + Energy.Type.keys()[element].capitalize() + " energy."
	
	effect.set_duration(dur)
	effect.mag = mag
	return effect

static func color_change_effect(inc_color, replaced_color, dur, targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.COLOR_CHANGE
	
	effect.mag = inc_color
	var target_word = "This character's skills "
	if targets != []:
		effect.ability_targets = targets
		target_word = ""
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
	effect.cost_change_element = replaced_color
	effect.description = func desc(eff):
		return target_word + "cost " + Energy.Type.keys()[inc_color].capitalize() + " instead of " + Energy.Type.keys()[replaced_color].capitalize() + " energy."
	
	effect.set_duration(dur)
	return effect

static func cost_change_effect(cost = {}, dur=-1, targets=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.COST_CHANGE
	effect.alternative_cost = cost
	var target_word = "This character's skills "
	if targets != []:
		effect.ability_targets = targets
		target_word = ""
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += " "
	
	var new_cost_word = "no "
	if len(cost.keys()) != 0:
		new_cost_word = ""
		for element in cost.keys():
			new_cost_word += str(cost[element]) + " "
			new_cost_word += Energy.Type.keys()[element].capitalize()
			if cost.keys().find(element) == len(cost.keys()) - 2:
				new_cost_word += " and "
			elif cost.keys().find(element) < len(cost.keys()) - 1:
				new_cost_word += ", "
			else:
				new_cost_word += " "
	
	
	effect.description = func desc(eff):
		return target_word + "will cost " + new_cost_word + "energy."
	
	effect.set_duration(dur)
	return effect

static func target_change_effect(target_type, dur, abi_targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.TARGET_CHANGE
	effect.mag = target_type
	effect.set_duration(dur)
	var target_string = "This character's skills "
	var copula = "are"
	
	if abi_targets != []:
		effect.ability_targets = abi_targets
		if len(abi_targets) == 1:
			copula = "is"
		target_string = ""
		for target in abi_targets:
			target_string += target
			if abi_targets.find(target) == len(abi_targets) - 2:
				target_string += " and "
			elif abi_targets.find(target) < len(abi_targets) - 1:
				target_string += ", "
			else:
				target_string += " "
	
	match target_type:
		TargetType.Type.SINGLE:
			target_string += copula + " now single target."
		TargetType.Type.ALL:
			target_string += "will now affect all targets."
		TargetType.Type.ALL_FACTION:
			target_string += "will now affect all allies or all enemies."
		TargetType.Type.SELF:
			target_string += copula + " now self-target."
	
	effect.description = func (eff):
		return target_string
	return effect

static func ability_swap_effect(slot_swap_in, slot_replace, user, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.ABILITY_SWAP
	effect.set_duration(dur)
	effect.mag = Vector2(slot_swap_in, slot_replace)
	
	effect.description = func (eff):
		return user.moveset.base_abilities[slot_replace].ability_name + " has been replaced by " + user.moveset.base_abilities[slot_swap_in].ability_name + "."

	return effect

static func shield_effect(shield_mag, dur, display_shield = true):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.SHIELD
	effect.mag = shield_mag
	effect.set_duration(dur)
	effect.stackable = display_shield
	effect.stack_mag = display_shield
	effect.display_mag = display_shield
	effect.description = func (eff):
		return "This character has " + str(eff.mag) + " points of Shield."
	return effect

static func silence_effect(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.SILENCE
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character is silenced."
	return effect

static func stat_mod_effect(stat_target: StatType.Type, mag, dur=1):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.PRIMARY_STAT_MOD
	effect.stat_target = stat_target
	if mag > 0.0:
		effect.description = func desc(eff):
			return "This character's " + StatType.Type.keys()[eff.stat_target].capitalize() + " has been increased by " + str(eff.mag * 100) + "%."
	else:
		effect.description = func desc(eff):
			return "This character's " + StatType.Type.keys()[eff.stat_target].capitalize() + " has been decreased by " + str((eff.mag * -1) * 100) + "%."
	effect.mag = mag
	effect.set_duration(dur)
	
	return effect

static func damage_reduction_effect(mag, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DAMAGE_REDUCTION
	effect.mag = mag
	effect.description = func (eff):
		return "This character has " + str(eff.mag) + " damage reduction."
	
	effect.set_duration(dur)
	
	return effect
	
static func vulnerability_effect(mag, dur, targets = [], class_targets = [], exclusion_targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.VULNERABILITY
	effect.mag = mag
	var target_word = "This character"
	if targets != []:
		effect.ability_targets = targets
		target_word += " will receive " + str(abs(mag)) + " more damage from "
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += "."
		
	elif class_targets != [] or exclusion_targets != []:
		effect.class_targets = class_targets
		effect.exclusion_targets = exclusion_targets
		target_word += " will receive " + str(abs(mag)) + " more "
		for target in class_targets:
			target_word += DamageType.get_damage_type_name(target, true)
			if class_targets.find(target) == len(class_targets) - 2:
				target_word += " or "
			elif class_targets.find(target) < len(class_targets) - 1:
				target_word += ", "
			else:
				target_word += " "
		for target in exclusion_targets:
			target_word += "non-" + DamageType.get_damage_type_name(target, true)
			if class_targets.find(target) == len(class_targets) - 2:
				target_word += " and "
			elif class_targets.find(target) < len(class_targets) - 1:
				target_word += ", "
			else:
				target_word += " "
		target_word += "damage."
	else:
		target_word += " will receive " + str(abs(mag)) + " more damage."
	effect.description = func desc(eff):
		
		return target_word
	
	
	effect.set_duration(dur)
	
	return effect

static func from(eff_type: EffectType.Type, kwargs=[]):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = eff_type
	
	for package in kwargs:
		if package == "description" and kwargs[package] is String:
			effect.description = func (eff):
				return kwargs[package]
			continue
		effect.set(package, kwargs[package])
	
	return effect

static func xanxus_storage_effect():
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.XANXUS_STORAGE
	effect.set_duration(-1)
	effect.storage = {
		"stun": 0,
		"piercing": 0,
		"normal": 0,
		"affliction": 0,
		"half": 0,
		"silence": 0,
		"isolate": 0,
		"counter": 0,
		"shatter": 0
	}
	effect.cleansable = false
	effect.description = func (eff):
		return "Xanxus is growing angrier with each new type of harmful effect he receives."
	
	
	return effect

static func stun_effect(dur=1, class_targets = [], exclude_targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.STUN
	effect.set_duration(dur)
	effect.exclusion_targets = exclude_targets
	effect.ability_targets = class_targets
	effect.remove_on_death = false
	var target_string = "This character"
	
	if exclude_targets != [] or class_targets != []:
		target_string += "'s "
		if exclude_targets != []:
			for target in exclude_targets:
				target_string += "Non-" + target
				if exclude_targets.find(target) == len(exclude_targets) - 2:
					target_string += " and "
				elif exclude_targets.find(target) < len(exclude_targets) - 1:
					target_string += ", "
				else:
					target_string += " "
		
		if class_targets != []:
			for target in class_targets:
				target_string += target
				if class_targets.find(target) == len(class_targets) - 2:
					target_string += " and "
				elif class_targets.find(target) < len(class_targets) - 1:
					target_string += ", "
				else:
					target_string += " "
		target_string += "skills are stunned."
	else:
		target_string += " is stunned."
		
	effect.description = func desc(eff):
		return target_string
	return effect

static func barrier_effect(barrier_mag, dur, display = true):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.BARRIER
	effect.mag = barrier_mag
	effect.stackable = true
	effect.stack_mag = true
	effect.display_mag = display
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character has " + str(eff.mag) + " points of Nullify."
	return effect

static func invuln_effect(dur=1, class_targets = [], exclude_targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.INVULN
	effect.set_duration(dur)
	effect.exclusion_targets = exclude_targets
	effect.class_targets = class_targets
	
	var target_string = "This character is invulnerable"
	
	if exclude_targets != [] or class_targets != []:
		target_string += " to "
		if exclude_targets != []:
			for target in exclude_targets:
				target_string += "Non-" + target
				if exclude_targets.find(target) == len(exclude_targets) - 2:
					target_string += " and "
				elif exclude_targets.find(target) < len(exclude_targets) - 1:
					target_string += ", "
				else:
					target_string += " "
		
		if class_targets != []:
			for target in class_targets:
				target_string += target
				if class_targets.find(target) == len(class_targets) - 2:
					target_string += " and "
				elif class_targets.find(target) < len(class_targets) - 1:
					target_string += ", "
				else:
					target_string += " "
		target_string += "skills"
	
	target_string += "."
	effect.description = func desc(eff):
		return target_string
	return effect

static func def_negate(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DEF_NEGATE
	effect.description = func(eff):
		return "This character is Shattered."
	effect.set_duration(dur)
	return effect

static func disguise(target_path):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DISGUISE
	effect.set_duration(-1)
	effect.invisible = true
	effect.description = func(eff):
		return "This character is disguised."
	effect.mag = target_path
	return effect

static func percent_dr(mag, dur, unpierceable = false):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.PERCENT_DR
	effect.mag = mag
	effect.description = func (eff):
		return "This character has " + str(mag) + "% Damage Reduction."
	effect.set_duration(dur)
	return effect
	
static func delay_eff(mag, dur, count=1, classes = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DELAY
	effect.mag = mag
	effect.set_duration(dur)
	
	effect.stackable = true
	effect.stacks = count
	effect.ability_targets = classes
	
	effect.description = func (eff):
		
		var desc_string = "This character's next "
		var skill_string = "skill"
		if eff.stack_count() != 1:
			skill_string = "skills"
			desc_string += str(eff.stacks) + " "
		
		if eff.ability_targets != []:
			for target in eff.ability_targets:
				desc_string += target
				if eff.ability_targets.find(target) == len(eff.ability_targets) - 2:
					desc_string += " or "
				elif eff.ability_targets.find(target) < len(eff.ability_targets) - 1:
					desc_string += ", "
				else:
					desc_string += " "
		var turn_count_string = " turn"
		if eff.mag > 1:
			turn_count_string = " turns"
		desc_string +=  skill_string + " will be delayed by " + str(eff.mag) + turn_count_string + "."
		return desc_string
	
	return effect

static func delay_receive_eff(mag, dur, count=1, classes = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DELAY_RECEIVE
	effect.mag = mag
	effect.set_duration(dur)
	
	effect.stackable = true
	effect.stacks = count
	effect.ability_targets = classes
	
	effect.description = func (eff):
		
		var desc_string = "The next "
		var skill_string = "skill"
		if eff.stack_count() != 1:
			skill_string = "skills"
			desc_string += str(eff.count) + " "
		
		if eff.ability_targets != []:
			for target in eff.ability_targets:
				desc_string += target
				if eff.ability_targets.find(target) == len(eff.ability_targets) - 2:
					desc_string += " or "
				elif eff.ability_targets.find(target) < len(eff.ability_targets) - 1:
					desc_string += ", "
				else:
					desc_string += " "
		var turn_count_string = " turn"
		if eff.mag > 1:
			turn_count_string = " turns"
		desc_string +=  skill_string + " that target this character will be delayed by " + str(eff.mag) + turn_count_string + "."
		return desc_string
	
	return effect

static func heal_cut(mag, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HEAL_CUT
	
	effect.mag = mag
	effect.set_duration(dur)
	
	effect.description = func (eff):
		return "This character will receive " + str(eff.mag) + "% less healing."
	
	return effect

static func delay_target_marker(skill, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DELAY_MARKER
	effect.cleansable = false
	effect.set_duration(dur)
	effect.description = func (eff):
		return skill.ability_name + " will be used on this character."
	
	return effect

static func empty(dur, desc=""):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.EMPTY
	effect.set_duration(dur)
	if desc is String:
		effect.description = func (eff):
			return desc
	else:
		effect.description = desc
	return effect

static func mark(dur, desc=""):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.MARK
	effect.set_duration(dur)
	if desc is String:
		effect.description = func (eff):
			return desc
	else:
		effect.description = desc
	
	return effect

static func isolate(dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.ISOLATE
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character is Isolated."
	return effect

static func taunt_effect(dur, user):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.TAUNT
	effect.set_duration(dur)
	effect.description = func (eff):
		return "This character has been Taunted by " + user.character_name + "."
	return effect

static func delayed_skill_eff(skill, targets, main_target, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.DELAYED_SKILL
	effect.cleansable = false
	effect.set_duration(dur)
	effect.delay_targets = []
	for target in targets:
		effect.delay_targets.append(target)
	effect.delay_main_target = effect.delay_targets[0]
	effect.delay_skill = skill
	effect.description = func (eff):
		return "This character will use " + skill.ability_name + "."
	
	return effect

static func healing_received_mod_effect(mag, duration, targets = []):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HEALING_RECEIVED_MOD
	effect.set_duration(duration)
	effect.mag = mag
	
	var target_word = "This character will receive " + str(abs(mag)) + " more healing"
	if targets != []:
		effect.ability_targets = targets
		target_word += " from "
		for target in targets:
			target_word += target
			if targets.find(target) == len(targets) - 2:
				target_word += " and "
			elif targets.find(target) < len(targets) - 1:
				target_word += ", "
			else:
				target_word += "."
	else:
		target_word += "."
	effect.description = func(eff):
		return target_word
	
	return effect

static func erza_armor_effect(armor_path, armor_name, dur):
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.ERZA_ARMOR
	effect.set_duration(dur)
	var desc = ""
	match armor_path:
		"clear_heart":
			desc = "Erza will ignore stuns and counters, and Titania's Rampage will cost 1 Random energy."
		"heavens_wheel":
			desc = "Erza will ignore Affliction damage, and Circle Blade will cost 1 Random energy."
		"nakagamis":
			desc = "The next skill Erza uses will get -1 Cooldown permanently, and Nakagami's Starlight will cost 1 Random energy."
	effect.description = func (eff): return desc
	effect.mag = armor_name
	
	return effect

static func hisoka_health_freeze_effect():
	var effect = load("res://components/effect_component.tscn").instantiate()
	effect.effect_type = EffectType.Type.HISOKA_HEALTH_FREEZE
	effect.set_duration(6)
	effect.description = func (eff): return "Changes to this character's HP are invisible to your opponent."
	effect.invisible = true
	return effect
	

func effect_name():
	if effect_type == EffectType.Type.ERZA_ARMOR:
		return mag
	return source.ability_name

func set_element(ele):
	element = ele
	tooltip = load("res://assets/tooltips/" + Element.Type.keys()[element].to_lower() + "_energy.png")

func set_duration(dur):
	duration = dur

func set_user(char):
	user = char

func set_source(nsource):
	user = nsource.user
	tooltip = nsource.return_image_with_mastery(nsource.user)
	source = nsource
	
func set_target(ntarget):
	target = ntarget

func change_mag(val):
	mag += val
	effect_updated.emit(self)

func consume_stack(val):
	stacks -= val
	if stacks <= 0:
		end_effect(EndingType.Type.CONSUMED)
	effect_updated.emit(self)

func tick_effect():
	var tick_rate = 1
	if duration == -1:
		return
	#TODO check for buff tick advancement?
	duration -= tick_rate
	effect_updated.emit(self)
	if duration <= 0:
		end_effect()

func stealthable():
	var stealth_type = effect_type in EffectType.stealthable_triggers()
	if not stealth_type:
		return false
	return true
	

func set_effect_description(desc):
	description = desc

func end_effect(ending_type = EndingType.Type.CANCELLED):
	#TODO do various things depending on the ending_type
	var context = QueryContext.from_effect_end(self)
	if ending_type == EndingType.Type.CANCELLED:
		wrapup_func.call(context)
	effect_expired.emit(self)
