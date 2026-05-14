extends Node
class_name Character

@export var effects: EffectStorageComponent
@export var health: HealthComponent
@export var stats: StatComponent
@export var _name: NameComponent
@export var moveset: MovesetComponent
@export var targeter: TargeterComponent
var targeted = false
var waiting = true
var used_ability = null
var acted = false
var dead = false
var enemy = false
var banished = false
var used_ability_index = -1
var manual_toggle_missions = {}
var was_countered = false
var universe: CharacterConcept.Universe
@export var mastery_portrait: Texture2D
@export var mastery_name: String

@export var portrait_texture: Texture2D
@export var alt_portraits: Array[Texture2D]
var hp_last_turn = 100
var hp_last_last_turn = 100
var character_colors = []
var beginner = false
var team: TeamComponent
var character_name = ""
var mastery_portrait_on = false
var mastery_skin_on = false
var description = ""
var battle
var passive_description = ""
var path_name
var initialized = false
var bot_character = false
var bot_acted = false
var portrait_frame = "portrait_color_default"
var action_frame = "gamepanel_color_default"
var hat = "None"
var disguise_name = ""
var extra_button_label = ""
# Server-authoritative portrait override. The shadow resolves the active
# portrait (walking PORTRAIT_CHANGE / DISGUISE effects) and ships the result
# here, because passive clients have no runtime _effects for active_portrait()
# to walk. server_portrait_alt == -1 means "no alt"; server_portrait_disguise
# == "" means "no disguise". server_portrait_set is flipped on the first
# reconcile so local/bot paths (where _effects is populated locally) keep
# reading from effects instead of these overrides.
var server_portrait_alt: int = -1
var server_portrait_disguise: String = ""
var server_portrait_set: bool = false
signal cancel_action(character)
signal ability_selected(entity, ability)
signal character_selected(entity)
signal update()
signal finished_targeting()
signal request_aoe_targets(targeter, main_target, faction_specific)
signal hide_panel()
signal request_panel(panel, character)
signal targeting_changed(character)
signal request_random_targets(targeter)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func change_name(new_name):
	_name.change_name(new_name)

# Send a custom message to the action log, attributed to this character.
# The log row shows this character's portrait + name, followed by the text.
# If `demand` is true, the message is flagged as urgent (subject to whatever
# treatment the display layer gives demand-flagged events).
func log_message(text: String, demand: bool = false):
	if battle == null or text == "":
		return
	var event = BattleLogEvent.make(BattleLogEvent.Kind.SYSTEM).with_actor(self).with_extra("text", text)
	if demand:
		event.as_demand()
	if battle.has_method("emit_log_event"):
		battle.emit_log_event(event)

func is_unlocked(player):
	return true


func unlocked(player):
	return (path_name in CharacterDatabase.starter_squads()) or (path_name + "_unlock" in player.unlocks) or "all_unlock" in player.unlocks

func call_unique(user_path, function_name, args):
	if path_name == user_path:
		return get(function_name).call(args)
	else:
		return null

func get_custom_interface_panel():
	return false

func has_color(color):
	for skill in moveset.abilities:
		if skill._cost[color] > 0:
			return true

func manually_advance_mission(mission_num, progress):
	pass

func sleepy_frieren():
	return path_name == "frieren" and not marked_by("Mana Release")

func enemy_team():
	if team == battle.player.team:
		return battle.enemy.team
	else:
		return battle.player.team

func ally_team():
	if team == battle.player.team:
		return battle.player.team
	else:
		return battle.enemy.team

## Called before a stun is applied to this character. Return true to block the stun.
## Override in character scripts (e.g., gunha.gd) for character-specific stun interactions.
func on_stun_received(effect) -> bool:
	return false

## Called when a control effect (stun, blind, silence) is applied to this character.
## Override in character scripts (e.g., tokoyami.gd) for character-specific reactions.
func on_control_effect_received(effect):
	pass

## Called by silphymon_check to delegate actual Silphymon logic to hawkmon.gd.
## Override only in hawkmon.gd.
func notify_silphymon(effect):
	pass

func silphymon_check(effect):
	if path_name == "hawkmon":
		return
	for character in team.characters:
		if character.path_name != "hawkmon":
			continue
		character.notify_silphymon(effect)

func apply_effect(effect, target, prepend=false):
	effect.set_user(self)
	effect.set_target(target)
	if effect.invisible and marked_by("Crush Card Virus") and has_effect("Crush Card Virus", EffectType.Type.MARK).user != self:
		effect.invisible = false
	if effect.effect_type == EffectType.Type.ABILITY_SWAP:
		if effect.source not in moveset.base_abilities:
			return
	if effect.effect_type == EffectType.Type.STUN:
		if target.on_stun_received(effect):
			return
	if effect.effect_type == EffectType.Type.INVULN:
		check_invuln_mission_triggers(effect, target)

	target.effects.add_effect(effect, prepend)

	if effect.effect_type == EffectType.Type.STUN:
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('stun')
		if not target.shrug_off_type(EffectType.Type.STUN):
			check_stun_triggers(effect, target)
			target.on_control_effect_received(effect)
			silphymon_check(effect)
			target.check_stun_received_triggers(effect)
		target.check_cancels()
	elif effect.effect_type == EffectType.Type.DEF_NEGATE:
		check_shatter_mission_triggers(effect, target)
		if not target.shrug_off_type(EffectType.Type.DEF_NEGATE):
			silphymon_check(effect)
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('shatter')
	elif effect.effect_type == EffectType.Type.ISOLATE:
		if not target.shrug_off_type(EffectType.Type.ISOLATE):
			silphymon_check(effect)
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('isolate')
	elif effect.effect_type == EffectType.Type.SHIELD:
		check_shield_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.BLIND:
		if not target.shrug_off_type(EffectType.Type.BLIND):
			target.on_control_effect_received(effect)
			silphymon_check(effect)
			check_blind_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.TAUNT:
		if not target.shrug_off_type(EffectType.Type.TAUNT):
			silphymon_check(effect)
			check_taunt_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.BARRIER:
		check_nullify_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.SILENCE:
		if not target.shrug_off_type(EffectType.Type.SILENCE):
			silphymon_check(effect)
			target.on_control_effect_received(effect)
		check_silence_mission_triggers(effect, target)
		

func banish_character(context, banish_target, source, dur, wrapup = null):
	if banish_target.shrug_off_type(EffectType.Type.BANISH):
		return
	var banish_effect = Effect.banish_effect(dur)
	banish_effect.unique_render_id = 1
	banish_effect.set_source(source)
	if wrapup != null:
		banish_effect.wrapup_func = wrapup
	if banish_target in team.characters:
		Character.add_allied_effect(context, self, banish_target, banish_effect)
	else:
		Character.add_hostile_effect(context, self, banish_target, banish_effect)
	banish_target.banished = true
	if battle:
		battle.character_banished.emit(banish_target)
	banish_target.check_cancels()

func check_cancels(force = false):
	var cancel_controls = get_effects_by_type(EffectType.Type.CONTROL_CANCEL)
	var cancel_channels = get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)
	for cancel in cancel_controls:
		if is_stunned(cancel.source) or dead or banished or force:
			for eff in cancel.cancel_effects:
				if eff.removed:
					continue
				eff.end_effect()
			cancel.end_effect()
	for cancel in cancel_channels:
		if is_stunned(cancel.source) or dead or banished or force:
			for eff in cancel.cancel_effects:
				if eff.removed:
					continue
				eff.end_effect()
			cancel.end_effect()

func startup_passives(battle):
	for ability in moveset.abilities:
		if ability.classes["Passive"]:
			ability.execute(self, battle)

func is_banished():
	if shrug_off_type(EffectType.Type.BANISH):
		return false
	
	if len(effects.get_effects_by_type(EffectType.Type.BANISH)) > 0:
		return true
	
	return false



func active_portrait():
	if dead:
		return load("res://assets/images/dead.png")
	if banished:
		return load("res://assets/images/banished.png")
	var final_path = -1
	var disguise_path := ""

	# Prefer the server-resolved portrait choice when we're on a passive client
	# (no runtime _effects to walk). Local/bot battles never toggle
	# server_portrait_set, so they still resolve from effects directly.
	if server_portrait_set:
		final_path = server_portrait_alt
		disguise_path = server_portrait_disguise
	else:
		for swap in effects.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE):
			if not swap.source in moveset.base_abilities:
				continue
			final_path = swap.mag
		for disguise in effects.get_effects_by_type(EffectType.Type.DISGUISE):
			disguise_path = str(disguise.mag)

	if disguise_path != "":
		var character = Character.from_character_name(disguise_path)
		return character.portrait_texture

	if mastery_portrait_on or mastery_skin_on:
		return mastery_portrait

	if final_path == -1:
		return portrait_texture
	else:
		return alt_portraits[final_path]

func reflect_check(battle, ability):
	if stealthed():
		return false
	for ignore_counter in effects.get_effects_by_type(EffectType.Type.IGNORE_COUNTER):
		if ignore_counter.ability_targets == []:
			return false
		else:
			if ability.ability_name in ignore_counter.ability_targets:
				return false
			
	if ability.classes["Uncounterable"]:
		return false
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	for effect in effects.get_effects_by_type(EffectType.Type.REFLECT_USE):
		var context = QueryContext.from_counter_check(self, self, effect, battle)
		if Condition.action_countered(ability, effect).satisfied(context):
			effect.trigger.check(context)
			battle.log_reflect(self)
			effect.user.check_counter_triggers(effect, self)
			return true
	var original_targets = []
	for target in targeter.targets:
		original_targets.append(target)
	for target in original_targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
			var context = QueryContext.from_counter_check(self, target, effect, battle)
			if Condition.action_countered(ability, effect).satisfied(context):
				effect.trigger.check(context)
				effect.user.check_counter_triggers(effect, self)
				return true
	return false

func countered(battle, ability):
	if stealthed():
		return false
	for ignore_counter in effects.get_effects_by_type(EffectType.Type.IGNORE_COUNTER):
		if ignore_counter.ability_targets == []:
			return false
		else:
			if ability.ability_name in ignore_counter.ability_targets:
				return false
	if ability.classes["Uncounterable"]:
		return false
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	for effect in effects.get_effects_by_type(EffectType.Type.COUNTER_USE):
		var context = QueryContext.from_counter_check(self, self, effect, battle)
		if Condition.action_countered(ability, effect).satisfied(context):
			effect.trigger.check(context)
			if not dead:
				ability.counter_response_trigger.call(self)
			battle.log_counter(self)
			effect.user.check_counter_triggers(effect, self)
			return true
	for target in targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
			var context = QueryContext.from_counter_check(self, target, effect, battle)
			if Condition.action_countered(ability, effect).satisfied(context):
				effect.trigger.check(context)
				ability.counter_response_trigger.call(target)
				battle.log_counter(self)
				effect.user.check_counter_triggers(effect, self)
				return true
	return false


func generate_energy():
	var turn_energy = []
	var roll = battle.roll(0, 3, "Energy Gen Type")
	turn_energy.append(Energy.Type[Energy.Type.keys()[roll]])
	return turn_energy


func receive_ability_damage(ability, damage, dealer):
	if (dealer.path_name == "muichiro" or marked_by("Fourth Form: Shifting Flow Slash")): #TODO: add muichiro counter-state attribution
		if blind_check():
			receive_beheading(damage)
			return
					
				
	receive_damage(damage, dealer, ability)
	if damage > 0:
		check_damage_taken_triggers(ability, damage)


func receive_beheading(value):
	var muichiro = battle.find_enemy_by_path(self, "muichiro")
	if muichiro:
		var passive = false
		for skill in muichiro.moveset.abilities:
			if skill.classes["Passive"]:
				passive = skill
		if passive:
			var mark = Effect.mark(-1, "If this effect's magnitude is greater than this character's current HP, they will be executed.")
			mark.stackable = true
			mark.display_mag = true
			mark.stack_mag = true
			mark.invisible = true
			mark.mag = value
			mark.set_source(passive)
			Character.add_hostile_effect(QueryContext.from_game_state(muichiro, battle), muichiro, self, mark)
			check_beheading()

func check_beheading():
	if marked_by("Unexpected Beheading"):
		var beheading = has_effect("Unexpected Beheading", EffectType.Type.MARK)
		var stacks = beheading.mag
		if stacks >= health.hp:
			instant_kill(beheading.user, beheading.source)

func receive_effect_damage(effect, damage, dealer):
	if (dealer.path_name == "muichiro" or marked_by("Fourth Form: Shifting Flow Slash")): #TODO: add muichiro counter-state attribution
		if blind_check():
			receive_beheading(damage)
			return
	
	receive_damage(damage, dealer, effect)
	if damage > 0:
		check_damage_taken_triggers(effect, damage)

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	moveset.set_base_abilities(Movesets._moveset(), self)

func execute_attempt(threshold, executioner, source):
	if health.hp <= threshold:
		instant_kill(executioner, source)

func receive_damage(damage, dealer, source):
	if hp_hidden():
		var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
		freeze.user.manually_advance_mission(8, damage)
	health.modify_hp(-damage, dealer, source)
	if battle and damage > 0:
		battle.damage_dealt.emit(self, damage, source, dealer)
	check_health_change_triggers()

func damage_reversed():
	var reversals = get_effects_by_type(EffectType.Type.DAMAGE_REVERSE)
	if len(reversals) > 0:
		return true
	return false

func get_damage_cap():
	var damage_cap = 100
	if not shrug_off_type(EffectType.Type.DAMAGE_CAP):
		for effect in effects.get_effects_by_type(EffectType.Type.DAMAGE_CAP):
			if effect.mag < damage_cap:
				if effect.source.ability_name == "Kuriboh":
					effect.user.manually_advance_mission(8, 1)
				damage_cap = effect.mag
	return damage_cap

func get_damage_cap_receive():
	var cap = 100
	if not shrug_off_type(EffectType.Type.DAMAGE_CAP_RECEIVE):
		for effect in effects.get_effects_by_type(EffectType.Type.DAMAGE_CAP_RECEIVE):
			if effect.mag < cap:
				cap = effect.mag
	return cap

func get_random_saturn_crystal_target(enemy_target = false):
	var targets = []
	
	if enemy_target:
		for character in battle.all_characters():
			if not character in team.characters and not (character.dead or character.banished):
				targets.append(character)
		if len(targets) == 0:
			return null
		var random_target = targets[battle.roll(0, len(targets) - 1)]
		return random_target
	else:
		for character in battle.all_characters():
			if character in team.characters and not (character.dead or character.banished) and not (character == self):
				targets.append(character)
		for target in targets:
			if target.marked_by("Silence Glaive Surprise"):
				return target
		if len(targets) == 0:
			return null
		var random_target = targets[battle.roll(0, len(targets) - 1)]
		return random_target


func deal_ability_damage(ability, damage, target, damage_type, redirected=false):
	var mod_damage = damage
	
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for effect in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_damage = 0
	
	#TODO: Damage Reduction and Destructible Defense
	
	mod_damage = check_damage_nullification(ability, mod_damage, self)
	
	if get_damage_cap() != 100:
		var damage_cap = get_damage_cap()
		if damage_cap == 15 and has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP):
			var reduced = mod_damage - damage_cap

			var kaiba = has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP).user
			kaiba.manually_advance_mission(7, reduced)
			if kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba):
				kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba).mag += reduced
		if mod_damage > damage_cap:
			mod_damage = damage_cap

	var receive_cap = target.get_damage_cap_receive()
	if mod_damage > receive_cap:
		mod_damage = receive_cap

	if damage_reversed():
		var reversals = get_effects_by_type(EffectType.Type.DAMAGE_REVERSE)
		Character.resolve_effect_healing(QueryContext.from_game_state(reversals[0].user, battle), reversals[0], target, mod_damage)
		return
	
	if damage_type == DamageType.Type.AFFLICTION:
		if target.path_name == "erza":
			if target.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"]):
				return
	
	if target.path_name == "esdeath":
		if marked_by("Empire's Strongest"):
			mod_damage -= 10
		elif marked_by("Weiss Schnabel"):
			mod_damage -= 5
	
	
	if (target.marked_by("Saturn Crystal") or target.marked_by("Silence Wall")) and not redirected:
		var walled = false
		if target.marked_by("Silence Wall"):
			var mark = target.has_effect("Silence Wall", EffectType.Type.MARK)
			var saturn = mark.user
			
			var redirect_target = saturn.get_random_saturn_crystal_target(true)
			if redirect_target == null:
				redirect_target = saturn
			mod_damage = int(mod_damage / 2)
			if redirect_target:
				saturn.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
			walled = true
		if target.marked_by("Saturn Crystal") and not walled:
			var mark = target.has_effect("Saturn Crystal", EffectType.Type.MARK)
			var redirect_target = target.get_random_saturn_crystal_target()
			if redirect_target:
				mod_damage = int(mod_damage / 2)
				if target.marked_by("Ruinous Scythe"):
					target.give_effect_healing(mark, mod_damage, redirect_target)
				else:
					target.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
	
	if not (damage_type == DamageType.Type.AFFLICTION or damage_type == DamageType.Type.BLEED):
		mod_damage = check_damage_against_barriers(ability, mod_damage, self)
		mod_damage = check_damage_against_shielding(ability, mod_damage, target)
	
		if not damage_type == DamageType.Type.PIERCING and not target.def_broken() and not damage_type == DamageType.Type.TRUE:
			mod_damage = check_damage_against_damage_reduction(ability, mod_damage, target)
			mod_damage = check_damage_against_percent_damage_reduction(ability, mod_damage, target)
	if not redirected:
		mod_damage = check_damage_redirect(ability.user, mod_damage, target, damage_type)
	
	if target.has_effect("Natural Assassin", EffectType.Type.NAGISA_DR) and is_silenced():
		mod_damage -= 5
	
	if mod_damage >= target.health.hp and target.marked_by("Heavenly Intervention"):
		mod_damage = 0
		var mark = target.has_effect("Heavenly Intervention", EffectType.Type.MARK)
		var lyserg = mark.user
		var timeout_mark = Effect.empty(2, "Heavenly Intervention has been triggered.")
		timeout_mark.set_source(mark.source)
		Character.add_allied_effect(QueryContext.from_game_state(lyserg, lyserg.battle), lyserg, lyserg, timeout_mark)
		target.effects.erase_effect(mark)
		lyserg.deal_effect_damage(mark, 35, self, DamageType.Type.NORMAL)
		
	target.receive_ability_damage(ability, mod_damage, self)
	
	if mod_damage > 0:
		
		if ability.health_drain:
			var context = QueryContext.from_game_state(self, battle)
			receive_healing(mod_damage, self, ability)
			
		if path_name == "inuyasha":
			if has_effect("Hanyo Cycle", EffectType.Type.MARK):
				match has_effect("Hanyo Cycle", EffectType.Type.MARK).mag:
					0:
						pass
					1:
						manually_advance_mission(7, mod_damage)
					2:
						manually_advance_mission(6, mod_damage)
		check_damage_dealt_triggers(ability, target, mod_damage, damage_type)

func deal_effect_damage(effect, damage, target, damage_type, redirected =false):
	var mod_damage = damage
		
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_damage = 0
	#TODO: Damage Reduction and Destructible Defense
	
	mod_damage = check_damage_nullification(effect, mod_damage, self)
	
	if get_damage_cap() != 100:
		var damage_cap = get_damage_cap()
		if damage_cap == 15 and has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP):
			var reduced = mod_damage - damage_cap

			var kaiba = has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP).user
			kaiba.manually_advance_mission(7, reduced)
			if kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba):
				kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba).mag += reduced
		if mod_damage > get_damage_cap():
			mod_damage = get_damage_cap()

	var receive_cap = target.get_damage_cap_receive()
	if mod_damage > receive_cap:
		mod_damage = receive_cap

	if damage_type == DamageType.Type.AFFLICTION:
		if target.path_name == "erza":
			if target.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"]):
				return
	
	if target.path_name == "esdeath":
		if marked_by("Empire's Strongest"):
			mod_damage -= 10
		elif marked_by("Weiss Schnabel"):
			mod_damage -= 5
	
	if (target.marked_by("Saturn Crystal") or target.marked_by("Silence Wall")) and not redirected:
		var walled = false
		if target.marked_by("Silence Wall"):
			var mark = target.has_effect("Silence Wall", EffectType.Type.MARK)
			var saturn = mark.user
			
			var redirect_target = saturn.get_random_saturn_crystal_target(true)
			if redirect_target == null:
				redirect_target = saturn
			mod_damage = int(mod_damage / 2)
			if redirect_target:
				saturn.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
			walled = true
		if target.marked_by("Saturn Crystal") and not walled:
			var mark = target.has_effect("Saturn Crystal", EffectType.Type.MARK)
			var redirect_target = target.get_random_saturn_crystal_target()
			if redirect_target:
				mod_damage = int(mod_damage / 2)
				if target.marked_by("Ruinous Scythe"):
					target.give_effect_healing(mark, mod_damage, redirect_target)
				else:
					target.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
	
	
	if not (damage_type == DamageType.Type.AFFLICTION or damage_type == DamageType.Type.BLEED):
		mod_damage = check_damage_against_barriers(effect, mod_damage, self)
		mod_damage = check_damage_against_shielding(effect, mod_damage, target)
		
		if not damage_type == DamageType.Type.PIERCING and not target.def_broken() and not damage_type == DamageType.Type.TRUE:
			mod_damage = check_damage_against_damage_reduction(effect, mod_damage, target)
			mod_damage = check_damage_against_percent_damage_reduction(effect, mod_damage, target)
			
	if not redirected:
		mod_damage = check_damage_redirect(effect.user, mod_damage, target, damage_type)
	
	if target.has_effect("Natural Assassin", EffectType.Type.NAGISA_DR) and is_silenced():
		mod_damage -= 5
	
	target.receive_effect_damage(effect, mod_damage, self)
	
	if mod_damage > 0:
		
		if effect.health_drain:
			var context = QueryContext.from_game_state(self, battle)
			Character.resolve_effect_healing(context, effect, self, mod_damage)
		
		check_damage_dealt_triggers(effect, target, mod_damage, damage_type)

func check_damage_nullification(source, damage, attacker):
	if shrug_off_type(EffectType.Type.DAMAGE_NULLIFICATION):
		return int(damage)
	var nulls = attacker.get_damage_nullification_effects()
	for null_eff in nulls:
		damage *= 1.0 - null_eff.mag
	return int(damage)

func check_damage_against_barriers(source, damage, attacker):
	var barriers = attacker.get_barrier_effects()
	for barrier in barriers:
		var context = QueryContext.from_effect_end(barrier)
		if damage > 0:
			barrier.barrier_func.call(context)
			attacker.check_damage_absorb_triggers(source)
			if source is Ability and source.ability_name == "Blade of the Dragon King":
				var damage_mod = Effect.damage_mod_effect(10, -1, ["Blade of the Dragon King"])
				damage_mod.set_source(source)
				damage_mod.display_mag = true
				damage_mod.stackable = true
				damage_mod.stack_mag = true
				add_allied_effect(QueryContext.from_game_state(attacker, attacker.battle), attacker, attacker, damage_mod)
			
		if damage >= barrier.mag:
			barrier.breaker = self
			check_effect_breaking(barrier)
			damage -= barrier.mag
			barrier.mag = 0
			attacker.effects.consume_effect(barrier)
		else:
			barrier.change_mag(-damage)
			return 0
	return damage

func check_damage_against_shielding(source, damage, target):
	if target.ignoring_effect_type(EffectType.Type.SHIELD):
		return damage
	var shields = target.get_shield_effects()
	for shield in shields:
		var context = QueryContext.from_effect_end(shield)
		if damage > 0:
			shield.shield_func.call(context)
			target.check_damage_absorb_triggers(source)
			if source is Ability and source.ability_name == "Blade of the Dragon King":
				var damage_mod = Effect.damage_mod_effect(10, -1, ["Blade of the Dragon King"])
				damage_mod.set_source(source)
				damage_mod.display_mag = true
				damage_mod.stackable = true
				damage_mod.stack_mag = true
				add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		if damage >= shield.mag:
			shield.breaker = self
			check_effect_breaking(shield)
			damage -= shield.mag
			shield.mag = 0
			target.effects.consume_effect(shield)
		else:
			shield.change_mag(-damage)
			return 0
	return damage

func check_effect_breaking(eff):
	var context = QueryContext.from_effect_end(eff)
	eff.wrapup_func.call(context)
	if eff.user.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK):
		eff.user.gain_corruption()
	if eff.source.ability_name == "Metal Armor":
		if eff.target.has_effect("Metal Armor", EffectType.Type.BLIND):
			eff.target.effects.erase_effect(eff.target.has_effect("Metal Armor", EffectType.Type.BLIND))
	if eff.source.ability_name == "Sparkling Wide Pressure":
		eff.user.call_unique("jupiter", "gain_shield_break", [context])
	if eff.source.ability_name == "A Knight That Protects":
		eff.user.call_unique("mash", "break_vow", [context])
	if eff.source.ability_name.begins_with("Elemental HERO"):
		eff.user.call_unique("jaden", "break_hero", [context])


func has_effect(eff_name, eff_type, user=null):
	return effects.has_effect(eff_name, eff_type, user)

# True iff at least one ally (excluding self) is alive, on-board, AND not
# rendered untargetable by another team-wide untargetable system. Today the
# discounting effects are Jeanne's "Iron Maiden" mark (self-sourced) and
# Sukuna's "Sealed King" mark (self-sourced); an ally with either is treated
# as if they weren't there for this check. Used by characters whose own
# untargetable state must collapse when no targetable teammate remains.
func has_targetable_living_ally():
	for ally in team.characters:
		if ally == self:
			continue
		if ally.dead or ally.banished:
			continue
		if ally.effects.has_effect("Iron Maiden", EffectType.Type.MARK, ally):
			continue
		if ally.effects.has_effect("Sealed King", EffectType.Type.MARK, ally):
			continue
		return true
	return false

func check_damage_against_damage_reduction(source, damage, target):
	var dr_effects = target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
	
	for dr in dr_effects:
		var dr_used = 0
		if source is Ability and source.ability_name == "Blade of the Dragon King":
			var damage_mod = Effect.damage_mod_effect(10, -1, ["Blade of the Dragon King"])
			damage_mod.set_source(source)
			damage_mod.display_mag = true
			damage_mod.stackable = true
			damage_mod.stack_mag = true
			add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		if dr.mag >= damage:
			dr_used = damage
		else:
			dr_used = dr.mag
		damage -= dr.mag
		if dr_used > 0:
			dr.user.check_ally_damage_reducing_mission_triggers(dr, target, dr_used)
		if damage <= 0:
			return 0
	return damage
	
func check_damage_against_percent_damage_reduction(source, damage, target):
	var dr_effects = target.get_effects_by_type(EffectType.Type.PERCENT_DR)
	for dr in dr_effects:
		damage *= ( (100.0 - dr.mag) / 100.0)
		if source is Ability and source.ability_name == "Blade of the Dragon King":
			var damage_mod = Effect.damage_mod_effect(10, -1, ["Blade of the Dragon King"])
			damage_mod.set_source(source)
			damage_mod.display_mag = true
			damage_mod.stackable = true
			damage_mod.stack_mag = true
			add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		
	
	return int(damage)

func check_damage_redirect(source, damage, target, damage_type):
	var redirect_effects = target.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT)
	for redirect in redirect_effects:
		var context = QueryContext.from_effect_end(redirect)
		var redirected_damage = damage * redirect.mag
		damage -= redirected_damage
		if not target.is_ignoring_damage(true):
			source.deal_effect_damage(redirect, redirected_damage, redirect.character_target, damage_type, true)
	return damage
		

func give_ability_healing(ability, healing, target):
	
	var mod_healing = healing
	#TODO check for healing mitigation
	if target.heal_blocked():
		return
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_healing = 0
	if target.dead or target.banished:
		return
	
	target.receive_ability_healing(ability, mod_healing, self)
	
func give_effect_healing(effect, healing, target):
	
	var mod_healing = healing
	#TODO check for healing mitigation
	if target.heal_blocked():
		return
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_healing = 0
	if target.dead or target.banished:
		return
	
	target.receive_effect_healing(effect, mod_healing, self)
	
func receive_ability_healing(ability, healing, healer):
	var mod_healing = healing
	if not shrug_off_type(EffectType.Type.HEAL_CUT):
		var heal_cuts = effects.get_effects_by_type(EffectType.Type.HEAL_CUT)
		for heal_cut in heal_cuts:
			mod_healing = int(mod_healing * (heal_cut.mag / 100.0))
	
	receive_healing(mod_healing, healer, ability)

func receive_effect_healing(effect, healing, healer):
	
	var mod_healing = healing
	if not shrug_off_type(EffectType.Type.HEAL_CUT):
		var heal_cuts = effects.get_effects_by_type(EffectType.Type.HEAL_CUT)
		for heal_cut in heal_cuts:
			mod_healing = int(mod_healing * (heal_cut.mag / 100.0))
	
	receive_healing(mod_healing, healer, effect)


func receive_healing(healing, healer, source):
	
	for heal_receive_mod in effects.get_effects_by_type(EffectType.Type.HEALING_RECEIVED_MOD):
		var fail = false
		if heal_receive_mod.ability_targets != []:
			if source is Effect:
				if not source.source.ability_name in heal_receive_mod.ability_targets:
					fail = true
			elif source is Ability:
				if not source.ability_name in heal_receive_mod.ability_targets:
					fail = true
		if not fail:
			healing += heal_receive_mod.mag
	if healing > (get_modified_max_hp()) - health.hp:
		healing = (get_modified_max_hp()) - health.hp
	if dead or banished:
		return
	if hp_hidden():
		var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
		freeze.user.manually_advance_mission(8, healing)
	health.modify_hp(healing, healer, source)
	if battle and healing > 0:
		battle.healing_done.emit(self, healing, source, healer)
	if healing > 0:
		staunch_bleeding()
		healer.check_healing_given_triggers(source, self, healing)
	check_health_change_triggers()

func staunch_bleeding():
	var output = []
	for damage_eff in effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if damage_eff.damage_type == DamageType.Type.BLEED:
			output.append(damage_eff)
	
	for bleed in output:
		effects.erase_effect(bleed)

func get_effects_by_type(effect_type):
	return effects.get_effects_by_type(effect_type)

func is_taunted():
	var taunt_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	if len(taunt_effects) > 0:
		return true
	return false

func get_damage_effects():
	return effects.get_effects_by_type(EffectType.Type.DAMAGE)

func get_healing_effects():
	return effects.get_effects_by_type(EffectType.Type.HEALING)

func get_ticking_triggers():
	return effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER)

func get_shield_effects():
	return effects.get_effects_by_type(EffectType.Type.SHIELD)
	
func get_barrier_effects():
	return effects.get_effects_by_type(EffectType.Type.BARRIER)
	
func get_cooldown_mods():
	return effects.get_effects_by_type(EffectType.Type.COOLDOWN_MOD)

func get_damage_nullification_effects():
	return effects.get_effects_by_type(EffectType.Type.DAMAGE_NULLIFICATION)

func get_ability_swap_effects():
	return effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP)

func get_delay_effects():
	return effects.get_effects_by_type(EffectType.Type.DELAY)
	
func get_delayed_skills():
	return effects.get_effects_by_type(EffectType.Type.DELAYED_SKILL)

func is_skill_currently_delayed(skill):
	for delayed_skill in get_delayed_skills():
		if delayed_skill.delay_skill == skill:
			return true
	return false

func def_broken():
	var def_negates = get_effects_by_type(EffectType.Type.DEF_NEGATE)
	if shrug_off_type(EffectType.Type.DEF_NEGATE):
		return false
	if len(def_negates) > 0:
		return true
	return false

func true_ignoring():
	return len(get_effects_by_type(EffectType.Type.IGNORE_NON_DAMAGE)) > 0

func marked_by(effect_name, user = null):
	return has_effect(effect_name, EffectType.Type.MARK, user)

func ignoring_effect_type(effect_type):
	var ignore_effects = get_effects_by_type(EffectType.Type.IGNORE_EFFECT)
	for effect in ignore_effects:
		if effect.mag == effect_type:
			return true
	return false

func check_stun_triggers(stun, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_STUN)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(stun, eff, target)
		eff.trigger.check(context)


func stealthed():
	for effect in effects.get_effects_by_type(EffectType.Type.STEALTH):
		return true
	return false

func stealth_check(effect):
	if effect.stealthable() and stealthed() and is_hostile(effect.user):
		return true
	return false

func check_stun_received_triggers(stun):
	if stun is Effect:
		stun = stun.source
	if shrug_off_type(EffectType.Type.STUN):
		return false
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.STUN_RECEIVED_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		var context=QueryContext.from_trigger_source(stun, eff, self)
		eff.trigger.check(context)

func check_invuln_mission_triggers(invuln, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_INVULN)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(invuln, eff, target)
		eff.trigger.check(context)

func check_blind_mission_triggers(blind, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_BLIND)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(blind, eff, target)
		eff.trigger.check(context)

func check_taunt_mission_triggers(taunt, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_TAUNT)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(taunt, eff, target)
		eff.trigger.check(context)

func check_shield_mission_triggers(shield, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SHIELD)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(shield, eff, target)
		eff.trigger.check(context)
	
func check_nullify_mission_triggers(nullify, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_NULLIFY)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(nullify, eff, target)
		eff.trigger.check(context)
		
func check_silence_mission_triggers(silence, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SILENCE)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(silence, eff, target)
		eff.trigger.check(context)

func check_shatter_mission_triggers(shatter, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SHATTER)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(shatter, eff, target)
		eff.trigger.check(context)
	
func check_hostile_damage_reducing_mission_triggers(reduction, target, amount):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_WEAKNESS_ABSORB)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(reduction, eff, target, amount)
		eff.trigger.check(context)

func check_ally_damage_reducing_mission_triggers(reduction, target, amount):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_DR_ABSORB)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(reduction, eff, target, amount)
		eff.trigger.check(context)

func check_counter_triggers(counter, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_COUNTER)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(counter, eff, target)
		eff.trigger.check(context)

func check_game_end_triggers(won, battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_GAME_END)
	for eff in trigger_effects:
		var context = QueryContext.from_game_state(self, battle)
		context.won = won
		eff.trigger.check(context)

func check_damage_dealt_triggers(damage_source, target, damage, damage_type):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, target, damage)
		context.damage_type = damage_type
		eff.trigger.check(context)
	var mission_trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_DAMAGE)
	for mission_eff in mission_trigger_effects:
		if mission_eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, mission_eff, target, damage)
		context.damage_type = damage_type
		mission_eff.trigger.check(context)
	for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
		if stealth_check(eff):
			continue
		if damage_type == DamageType.Type.NORMAL:
			eff.user.wrath_check("normal")
		elif damage_type == DamageType.Type.PIERCING:
			eff.user.wrath_check("piercing")
		elif damage_type == DamageType.Type.AFFLICTION:
			eff.user.wrath_check("affliction")

func check_health_change_triggers():
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HEALTH_CHANGE_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)
	for effect in effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
		if health.hp < 50:
			effect.target.wrath_check("half")
	check_beheading()
		
func check_damage_taken_triggers(damage_source, damage):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if damage_source.user.stealth_check(eff):
			continue
		#if eff.triggered:
			#continue
		if damage_source is Effect and eff.ability_only:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, self, damage)
		eff.trigger.check(context)
	

func check_healing_given_triggers(healing_source, target, healing):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HEALING_GIVEN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(healing_source, eff, target, healing)
		eff.trigger.check(context)
	var mission_trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_HEAL)
	for mission_eff in mission_trigger_effects:
		if mission_eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(healing_source, mission_eff, target, healing)
		mission_eff.trigger.check(context)
		
func check_damage_absorb_triggers(damage_source):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ABSORB_TRIGGER)
	for eff in trigger_effects:
		if damage_source.user.stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, self)
		eff.trigger.check(context)

func cancel_channels():
	var cancel_channels = get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)
	for cancel in cancel_channels:
		for eff in cancel.cancel_effects:
			if eff.removed:
				continue
			eff.end_effect()
		cancel.end_effect()


func check_ability_use_triggers(battle, ability, force=false):
	
	if has_effect("Tortured Resonance", EffectType.Type.COST_MOD):
		if has_effect("Tortured Resonance", EffectType.Type.COST_MOD).user in team.characters:
			has_effect("Tortured Resonance", EffectType.Type.COST_MOD).user.manually_advance_mission(7, 1)
	
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
			
		var context = QueryContext.from_trigger_source(ability, eff, self)
		eff.trigger.check(context)
	if dead:
		return
	used_ability = ability
	if ability.classes["Harmful"]:
		check_harmful_use_triggers(battle, ability, force)
	if ability.classes["Helpful"]:
		check_helpful_use_triggers(battle, ability)

	for target in targeter.targets:
		target.check_ability_receive_triggers(battle, ability, force)

func check_ability_receive_triggers(battle, received_ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ACTION_RECEIVE_TRIGGER)
	
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if eff.waiting and received_ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
	if dead:
		return
	if received_ability.classes["Harmful"]:
		check_harmful_receive_triggers(battle, received_ability, force)
	if received_ability.classes["Helpful"]:
		check_helpful_receive_triggers(battle, received_ability)

func check_harmful_use_triggers(battle, ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HARMFUL_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if ability.classes["Harmful"] and eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)
	
func check_helpful_use_triggers(battle, ability):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HELPFUL_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		if ability.classes["Helpful"] and eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_harmful_receive_triggers(battle, received_ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HARMFUL_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.user in received_ability.user.team.characters and not eff.source.ability_name == "Snake Fire":
			continue
		if eff.triggered and not force:
			continue
		if received_ability.classes["Harmful"] and received_ability == eff.source and eff.waiting:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
	
func check_helpful_receive_triggers(battle, received_ability):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HELPFUL_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.user not in received_ability.user.team.characters:
			continue
		if eff.triggered:
			continue
		if received_ability.classes["Helpful"] and received_ability == eff.source and eff.waiting:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
		
func check_end_of_turn_triggers(battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.END_OF_TURN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_start_of_turn_triggers(battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.START_OF_TURN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context) 

func check_death_triggers(killer):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ON_DEATH_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		context['owner'] = killer
		eff.trigger.check(context)

func check_kill_triggers(source, killed):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_KILL)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(source, eff, killed)
		context['source'] = source
		eff.trigger.check(context)

func check_counter_use_effects(interacter, battle):
	var counters = effects.get_effects_by_type(EffectType.Type.COUNTER_USE)
	for eff in counters:
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_counter_receive_effects(interacter, battle):
	var counters = effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE)
	for eff in counters:
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func get_mod_stat(stat):
	return stats.get_mod_stat(self, stat)

func get_base_stat(stat):
	return stats.get_base_stat(stat)

func ability_clicked(ability):
	#TODO: Maybe some of that "can I can I" stuff goes here?
	ability_selected.emit(self, ability)

func character_clicked():
	character_selected.emit(self)

func acted_clicked():
	if used_ability != null:
		refund_chosen_ability()
		refresh()
		
		update.emit()
		cancel_action.emit(self)

func refund_chosen_ability():
	team.refund_ability(used_ability)

func gain_random_energy():
	var energy_type = battle.roll(0, 3)
	team.change_energy(energy_type, 1)

func gain_bonus_energy(element):
	team.change_energy(element, 1)

func lose_energy(drainer, val=1):
	#TODO: on-drain triggers go here
	team.lose_energy(val, battle)

func can_be_affected(user, effect):
	return true

func cap_health(context, capper, duration, source):
	
	var cap_amount = health.hp
	var health_cap = Effect.health_cap_effect(cap_amount, duration)
	health_cap.set_source(source)
	Character.add_hostile_effect(context, capper, self, health_cap)

func get_modified_max_hp():
	var health_caps = effects.get_effects_by_type(EffectType.Type.HEALTH_CAP)
	var smallest_cap = health.max_hp
	for cap in health_caps:
		if cap.mag < smallest_cap:
			smallest_cap = cap.mag
	return smallest_cap
	
func heal_blocked():
	var heal_negates = effects.get_effects_by_type(EffectType.Type.IGNORE_HEALING)
	if shrug_off_type(EffectType.Type.IGNORE_HEALING):
		return false
	if len(heal_negates) > 0:
		return true
	return false

func has_stuns():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.STUN)
	var stun_immunities = effects.get_effects_by_type(EffectType.Type.STUN_IMMUNITY)
	var false_stun_effects = effects.get_effects_by_type(EffectType.Type.FALSE_STUN)
	if len(false_stun_effects) > 0:
		return true
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	if shrug_off_type(EffectType.Type.STUN):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true

func has_silences():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.SILENCE)
	if shrug_off_type(EffectType.Type.SILENCE):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true
		
func has_taunts():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true

func shrug_off_type(effect_type):
	return ignoring_effect_type(effect_type) or (true_ignoring() and effect_type != EffectType.Type.DAMAGE)

func is_stunned(ability):
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	var stun_effects = effects.get_effects_by_type(EffectType.Type.STUN)
	if not ability.stunnable:
		return false
	if shrug_off_type(EffectType.Type.STUN):
		return false
	if len(stun_effects) < 1:
		return false
	for effect in stun_effects:
		for ability_class in effect.exclusion_targets:
			if ability.classes[ability_class]:
				return false
		if len(effect.ability_targets) == 0:
			return true
		for ability_class in effect.ability_targets:
			if ability.classes[ability_class]:
				return true
	
	return false

func is_hostile(character):
	return not character in team.characters

func is_invuln(ability = null):
	var invuln_effects = effects.get_effects_by_type(EffectType.Type.INVULN)
	var def_negate = effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)
	if ability and ability.user:
		if ability.user.marked_by("Tsubaki Mode: Kusarigama"):
			return false
	if len(def_negate) > 0:
		return false
	if len(invuln_effects) > 0:
		if ability == null:
			return true
	for eff in invuln_effects:
		if eff.exclusion_targets != []:
			for target in eff.exclusion_targets:
				if ability.classes[target]:
					return false
		if eff.class_targets == []:
			return true
		else:
			for target in eff.class_targets:
				if ability.classes[target]:
					return true
	return false

func is_ignoring_damage(ability_source):
	var dmg_negate_effects = effects.get_effects_by_type(EffectType.Type.IGNORE_DAMAGE)
	#TODO: Add helpful negate check?
	if len(dmg_negate_effects) > 0:
		for eff in dmg_negate_effects:
			if not eff.ability_only or ability_source:
				if eff.remove_once_triggered:
					eff.target.effects.consume_effect(eff)
				elif eff.full_remove_once_triggered:
					eff.target.effects.consume_effect(eff, true)
				return true
		
	return false

func is_silenced():
	var silence_effects = effects.get_effects_by_type(EffectType.Type.SILENCE)
	if shrug_off_type(EffectType.Type.SILENCE):
		return false
	if len(silence_effects) > 0:
		return true
	return false

func is_isolated():
	var isolate_effects = effects.get_effects_by_type(EffectType.Type.ISOLATE)
	if shrug_off_type(EffectType.Type.ISOLATE):
		return false
	if len(isolate_effects) > 0:
		return true
	return false

func get_stun_immunities():
	var output = []
	var eff_ignores = effects.get_effects_by_type(EffectType.Type.IGNORE_EFFECT)
	for eff in eff_ignores:
		if eff.mag == EffectType.Type.STUN:
			output.append(eff)
	return output

func is_immortal():
	var immortality_effects = effects.get_effects_by_type(EffectType.Type.IMMORTALITY)
	if len(immortality_effects) > 0:
		return true
	return false

func dodge_check(_targeter):
	var dodge_effects = effects.get_effects_by_type(EffectType.Type.DODGE_CHANCE)
	var sharpshooter_effects = _targeter.effects.get_effects_by_type(EffectType.Type.SHARPSHOOTER)
	if len(sharpshooter_effects) > 0:
		return false
	var greatest_dodge_chance = 0
	if len(dodge_effects) < 1:
		return false
	for effect in dodge_effects:
		var mag = effect.mag
		if effect.source.ability_name == "Seventh Form: Obscuring Clouds":
			if _targeter.blind_check():
				mag = mag * 2
			if path_name == "muichiro" and has_effect("Fifth Form: Sea of Clouds and Haze", EffectType.Type.MARK):
				mag = mag * 2
		
		if mag > greatest_dodge_chance:
			greatest_dodge_chance = mag
	var dodge_roll = battle.roll(1, 100)
	if dodge_roll <= greatest_dodge_chance:
		return true
	return false
	
func miss_check():
	if shrug_off_type(EffectType.Type.MISS_CHANCE):
		return
	var miss_effects = effects.get_effects_by_type(EffectType.Type.MISS_CHANCE)
	var sharpshooter_effects = effects.get_effects_by_type(EffectType.Type.SHARPSHOOTER)
	if len(sharpshooter_effects) > 0:
		return
	var greatest_miss_chance = 0
	for effect in miss_effects:
		if effect.mag > greatest_miss_chance:
			greatest_miss_chance = effect.mag
	var miss_roll = battle.roll(1, 100)
	if miss_roll <= greatest_miss_chance:
		targeter.clear_targets()

func accuracy_check(ability):
	if ability.accurate:
		return
	miss_check()
	var potentials = []
	for target in targeter.targets:
		potentials.append(target)
	for target in potentials:
		var hostile = Condition.is_hostile(self, target)
		if hostile.satisfied(QueryContext.from_game_state(self, battle)):
			if target.dodge_check(self):
				targeter.remove_target(target)

func paralyzed():
	if shrug_off_type(EffectType.Type.PARALYZE):
		return false
	var paralysis = effects.get_effects_by_type(EffectType.Type.PARALYZE)
	
	if len(paralysis) > 0:
		return true
	return false

func shatter_barrier(breaker):
	var total_broken = 0
	var nullify_effects = get_barrier_effects()
	for nullify in nullify_effects:
		nullify.breaker = breaker
		check_effect_breaking(nullify)
		total_broken += nullify.mag
		nullify.mag = 0
		effects.consume_effect(nullify)
	return total_broken

func shatter_shields(breaker):
	var total_broken = 0
	var shield_effects = get_shield_effects()
	for shield in shield_effects:
		shield.breaker = breaker
		check_effect_breaking(shield)
		total_broken += shield.mag
		shield.mag = 0
		effects.consume_effect(shield)
	return total_broken

func instant_kill(killer, source):
	
	if marked_by("Embrace Pain"):
		return
	
	die(killer, source)

func die(killer=null, source=null):
	# Passive multiplayer clients hold no runtime _effects (only DisplayEffects
	# rebuilt from wire payloads), so is_immortal() — which walks _effects —
	# returns false even when the server saved the character via immortality.
	# That false negative would drive die() into the death branch, set
	# dead=true, and call refresh(true) — which latches waiting=true and
	# leaves the survivor un-actionable on the next turn even after the
	# snapshot reconciles dead back to false.
	#
	# The server is authoritative for death: DAMAGE events update HP, and
	# the DIED wire event sets dead=true via the event-replay handler in
	# battle_manager.gd. Running die() locally on the passive client would
	# also double-emit character_died and double-fire death/kill triggers
	# that the server already evaluated. Short-circuit here.
	if battle != null and "passive" in battle and battle.passive:
		return
	if not dead:
		if marked_by("Post-Mortem Nen"):
			effects.full_remove_effect_by_name("Post-Mortem Nen")
			var duration = 3
			if waiting:
				duration = 2
			var immortality = Effect.immortality_effect(duration)
			immortality.set_source(moveset.base_abilities[4])
			Character.add_allied_effect(QueryContext.from_game_state(self, battle), self, self, immortality)
		if is_immortal():
			health.set_health(1)
			update.emit()
		else:
			if health.hp > 0:
				health.set_health(0)
			if killer != null:
				if source is Ability:
					source.on_kill(self)
				killer.check_kill_triggers(source, self)
			check_death_triggers(killer)
			cleanse_death_effects()
			update.emit()
			dead = true
			if battle:
				battle.character_died.emit(self)
				if battle.has_method("log_death"):
					battle.log_death(self)
		refresh(dead)

func cleanse_death_effects():
	for character in battle.all_characters():
		for effect in character.effects.get_all_death_cleansable_effects(self):
			character.effects.erase_effect(effect)

func pretty_print():
	print(_name.show())
	stats.pretty_print(self)
	effects.pretty_print()
	moveset.pretty_print()
	
func refresh(death = false):
	waiting = dead
	targeter.reset()
	check_cancels()
	bot_acted = false
	if not death:
		acted = false
	used_ability=null
	update.emit()

func team_update():
	for character in team.characters:
		character.update.emit()

func set_targeted():
	targeted = true
	update.emit()


func set_untargeted():
	targeted = false
	update.emit()


func blind_check():
	if shrug_off_type(EffectType.Type.BLIND):
		return false
	var blind_effects = effects.get_effects_by_type(EffectType.Type.BLIND)
	#TODO: Add ignore check
	for blind_effect in blind_effects:
		for exclusion_target in blind_effect.exclusion_targets:
			if used_ability != null and used_ability.classes[exclusion_target]:
				continue
		if len(blind_effect.ability_targets) < 1:
			return true
		for class_target in blind_effect.ability_targets:
			if used_ability != null and used_ability.classes[class_target]:
				return true
		
		
	return false

func resolve_taunt():
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	var taunt_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	var relevant_taunt = taunt_effects[0]
	var targets = []
	for target in targeter.targets:
		targets.append(target)
	for target in targets:
		if not target in team.characters:
			targeter.remove_target(target)
	targeter.targets.append(relevant_taunt.user)
	if not targeter.main_target in team.characters:
		targeter.main_target = relevant_taunt.user

func other_character_clicked(character):
	update.emit()
	if not targeter.targeting:
		return
	
	targeter.add_target(character)
	targeter.main_target = character
	used_ability = targeter.targeting_ability
	var ttype = targeter.targeting_ability.target_type()
	if blind_check():
		if ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION or ttype == TargetType.Type.SELF:
			pass
		else:
			targeter.targeting_ability.ability_blinded = true
			ttype = TargetType.Type.ALL
	if ttype == TargetType.Type.ALL:
		request_aoe_targets.emit(self, character, false, used_ability.and_targeter)
	elif ttype == TargetType.Type.ALL_FACTION:
		request_aoe_targets.emit(self, character, true, used_ability.and_targeter)
	elif used_ability.and_targeter:
		request_aoe_targets.emit(self, character, false, true)
	team.pay_for_ability(used_ability)
	waiting = true
	targeter.end_targeting()
	finished_targeting.emit()

func gain_mark(user, source, duration, desc, stackable=false):
	var context = QueryContext.from_game_state(user, user.battle)
	var mark = Effect.mark(duration, desc)
	mark.set_source(source)
	mark.stackable = stackable
	if stackable:
		mark.display_stacks = true
	if user in team.characters:
		Character.add_allied_effect(context, user, self, mark)
	else:
		Character.add_hostile_effect(context, user, self, mark)

func get_mark_stacks(eff_name):
	if has_effect(eff_name, EffectType.Type.MARK):
		return has_effect(eff_name, EffectType.Type.MARK).stacks
	else:
		return 0

func request_hover_panel(panel, tooltip):
	
	request_panel.emit(panel, tooltip)
	
func request_hide_panel():
	hide_panel.emit()

func hp_hidden():
	var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
	if freeze:
		if freeze.user.enemy:
			return true
	return false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_action(bot_difficulty):
	var context = QueryContext.from_game_state(self, battle)
	var abilities = moveset.get_active_abilities(self)
	var priority_sets = []
	for ability in abilities:
		priority_sets.append(ability.get_target_variation_priorities(context, bot_difficulty))
	for priority_set in priority_sets:
		priority_set[0] += randi_range(-bot_difficulty, bot_difficulty)
	var sort_func = func (a, b):
		return a[0] > b[0]
	priority_sets.sort_custom(sort_func)
	return priority_sets[0]

static func from_character_name(char_name):
	var character = load("res://character/" + char_name + ".tscn").instantiate()
	character.initialize()
	return character

static func add_allied_effect(context, user, target, effect, bypassing = false):
	if user.is_silenced() and not user.shrug_off_type(EffectType.Type.SILENCE):
		if effect.effect_type in EffectType.silenced_effects():
			return
	if Condition.can_apply_allied_effect(user, target, effect, bypassing).satisfied(context):
		effect.id = context.id
		user.apply_effect(effect, target)
		if context.battle and context.battle.has_method("log_effect_applied"):
			context.battle.log_effect_applied(user, target, effect)

static func add_hostile_effect(context, user, target, effect, bypassing = false):
	if user.is_silenced() and not user.shrug_off_type(EffectType.Type.SILENCE):
		if effect.effect_type in EffectType.silenced_effects():
			return
	if target.shrug_off_type(effect.effect_type):
		return
	if Condition.can_apply_hostile_effect(user, target, effect, bypassing).satisfied(context):
		effect.id = context.id
		user.apply_effect(effect, target)
		if context.battle and context.battle.has_method("log_effect_applied"):
			context.battle.log_effect_applied(user, target, effect)

static func resolve_damage(context, target, pre_mod_damage, damage_type):
	var owner = context['owner']
	if not owner.used_ability:
		return
	var mod_damage = owner.used_ability.get_true_damage(owner, target, pre_mod_damage, null, damage_type)
	if mod_damage < owner.used_ability.minimum_damage:
		mod_damage = owner.used_ability.minimum_damage
	if not target.is_ignoring_damage(true):
		context.battle.log_damage(owner, target, mod_damage, damage_type, owner.used_ability)
		owner.deal_ability_damage(owner.used_ability, mod_damage, target, damage_type)
	else:
		context.battle.log_invuln_block(owner, target, owner.used_ability)

static func resolve_effect_damage(context, eff, target, pre_mod_damage, damage_type):
	var mod_damage = eff.source.get_true_damage(eff.user, target, pre_mod_damage, eff, damage_type)
	if not target.is_ignoring_damage(false):
		context.battle.log_damage(eff.user, target, mod_damage, damage_type, eff.source, eff)
		eff.user.deal_effect_damage(eff, mod_damage, target, damage_type)
	else:
		context.battle.log_invuln_block(eff.user, target, eff.source)

static func resolve_healing(context, target, pre_mod_healing):
	var owner = context['owner']
	var mod_healing = owner.used_ability.get_true_healing(owner, target, pre_mod_healing)
	if not target.is_isolated():
		context.battle.log_healing(owner, target, mod_healing, owner.used_ability)
		owner.give_ability_healing(owner.used_ability, mod_healing, target)

static func resolve_effect_healing(context, eff, target, pre_mod_healing):
	var mod_healing = eff.source.get_true_healing(context['owner'], target, pre_mod_healing)
	if not target.is_isolated():
		context.battle.log_healing(eff.user, target, mod_healing, eff.source, eff)
		eff.user.give_effect_healing(eff, mod_healing, target)
