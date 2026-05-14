extends Node
class_name EffectStorageComponent

var _effects: Array[Effect]
# Passive multiplayer clients populate this with DisplayEffect instances built
# from incoming wire EffectPayloads. Display effects are rendered the same as
# runtime effects (via get_renderable_effects + get_effect_clusters) but are
# never touched by game-logic functions like cleanse / has_effect / tick, so
# they coexist safely with the empty _effects array on a passive client.
var _display_effects: Array = []
signal effect_added(effect)
signal effect_removed(effect)
signal effects_changed()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func add_effect(effect: Effect, prepend=false):
	effect.effect_expired.connect(erase_effect)
	effect.effect_updated.connect(announce_change)
	var eff_match = has_effect(effect.effect_name(), effect.effect_type, effect.user)
	if eff_match:
		#TODO handle stacking/refreshing logic
		if eff_match.stackable:
			if effect.stack_mag:
				eff_match.mag += effect.mag
			eff_match.stacks += effect.stack_count()
			if eff_match.effect_type in EffectType.use_or_receive_triggers():
				eff_match.fresh_stack = true
		elif eff_match.refresh:
			remove_effect(eff_match.effect_name(), eff_match.effect_type, effect.user)
			if prepend:
				_effects.insert(0, effect)
			else:
				_effects.append(effect)
		else:
			if prepend:
				_effects.insert(0, effect)
			else:
				_effects.append(effect)
		effect_added.emit(effect)
		announce_change()
	else:
		if prepend:
			_effects.insert(0, effect)
		else:
			_effects.append(effect)
		effect_added.emit(effect)
		announce_change()

func has_effect(eff_name, eff_type, user=null):
	for eff in _effects:
		if eff_name == eff.effect_name() and eff_type == eff.effect_type and (user == eff.user or user == null):
			return eff
	return null

func remove_effect(eff_name, eff_type, user=null):
	var eff_match = has_effect(eff_name, eff_type, user)
	if eff_match:
		erase_effect(eff_match)

func cleanse_all_enemy_effects(character):
	var context = QueryContext.from_game_state(character, character.battle)
	var count = 0
	var hostile_effect = func (eff):
		var condition = (character in eff.user.team.characters) or not eff.cleansable or not (eff.effect_type in EffectType.silenced_effects())
		if not condition:
			count += 1
		return condition
	_effects = _effects.filter(hostile_effect)
	
	announce_change()
	return count

func cleanse_all_ally_effects(character):
	var context = QueryContext.from_game_state(character, character.battle)
	var count = 0
	var hostile_effect = func (eff):
		var condition = not (character in eff.user.team.characters) or not eff.cleansable or not (eff.effect_type in EffectType.silenced_effects())
		if not condition:
			count += 1
		return condition
	_effects = _effects.filter(hostile_effect)
	
	announce_change()
	return count

func get_all_death_cleansable_effects(user):
	var output = []
	for effect in _effects:
		if effect.user == user and effect.remove_on_death and not effect.system:
			output.append(effect)
	return output

func get_all_effects_by_name(eff_name, user=null):
	var output = []
	for effect in _effects:
		if effect.source.ability_name == eff_name and (user == effect.user or user == null):
			output.append(effect)
	return output

func eff_special_removal_criteria(eff):
	return eff.source.ability_name != "Dragon's Sin of Wrath"

func clear_non_system_effects(character):
	var context = QueryContext.from_game_state(character, character.battle)
	
	var system = func (eff):
		return eff.system and eff.source.ability_name != "Dragon's Sin of Wrath"
	_effects = _effects.filter(system)
	announce_change()

func cleanse_hostile_afflictions(character):
	var context = QueryContext.from_game_state(character, character.battle)
	
	var hostile_affliction = func (eff):
		var hostile = Condition.is_hostile(character, eff.user)
		var affliction = Condition.has_ability_class("Affliction", eff.source)
		var multi = Condition.multi([hostile, affliction])
		
		return not multi.satisfied(context) or not eff.cleansable
	_effects = _effects.filter(hostile_affliction)
	
	announce_change()

func effect_count(eff_name, eff_type, user=null):
	var count = 0
	for eff in _effects:
		if eff_name == eff.effect_name() and eff_type == eff.effect_type and (user == eff.user or user == null):
			count += 1
	return count

func erase_effect(eff):
	_effects.erase(eff)
	eff.removed = true
	effect_removed.emit(eff)
	announce_change()

func consume_effect(eff, full = false):
	eff.end_effect(EndingType.Type.CONSUMED)
	if full:
		full_remove_effect_by_name(eff.source.ability_name, eff.user)

func full_remove_effect_by_name(eff_name, user=null):
	var has_name = func (eff):
		return not(eff_name == eff.effect_name() and (user == eff.user or user == null))
	_effects = _effects.filter(has_name)
	announce_change()


func full_remove_effect_by_type(eff_type, user=null):
	var effects = get_effects_by_type(eff_type)
	for eff in effects:
		if user == eff.user or user == null:
			erase_effect(eff)
			announce_change()

func get_effects_by_type(eff_type):
	var output = []
	for effect in _effects:
		if eff_type == effect.effect_type:
			output.append(effect)
	return output

func add_display_effect(display_effect) -> void:
	for existing in _display_effects:
		if existing.id == display_effect.id:
			return
	_display_effects.append(display_effect)
	effect_added.emit(display_effect)
	announce_change()

func remove_display_effect_by_id(effect_id: String) -> void:
	for i in range(_display_effects.size()):
		if _display_effects[i].id == effect_id:
			var removed_eff = _display_effects[i]
			removed_eff.removed = true
			_display_effects.remove_at(i)
			effect_removed.emit(removed_eff)
			announce_change()
			return

func get_display_effect_by_id(effect_id: String):
	for de in _display_effects:
		if de.id == effect_id:
			return de
	return null

func clear_display_effects() -> void:
	_display_effects.clear()
	announce_change()

# Returns the union of runtime and display effects for UI consumption. On a
# normal (non-passive) client _display_effects is empty so this is identical
# to _effects; on a passive client _effects is empty so it returns the wire-
# driven view.
func get_renderable_effects() -> Array:
	var combined: Array = []
	combined.append_array(_effects)
	combined.append_array(_display_effects)
	return combined

func get_effect_clusters(effects):
	var cluster_dict = {}
	for effect in effects:
		if effect.invisible and effect.user.enemy:
			if effect.source.classes["Physical"] and effect.user.enemy_team().character_in_team("toph"):
				"Toph sensed an invisible effect"
			else:
				continue
		if effect.system:
			continue
		if [effect.effect_name() + str(effect.unique_render_id), effect.user] not in cluster_dict:
			cluster_dict[ [effect.effect_name() + str(effect.unique_render_id), effect.user] ] = [effect]
		else:
			cluster_dict[ [effect.effect_name() + str(effect.unique_render_id), effect.user] ].append(effect)
			
	return cluster_dict

func pretty_print():
	print("\tCurrent effects: ")
	for effect in _effects:
		print("\t\t" + effect.effect_name() + "- Type: " + str(effect.effect_type))

func tick_all_effects_durations():
	var reference_list = []
	for effect in _effects:
		effect.waiting = false
		effect.fresh_stack = false
		effect.triggered = false
		reference_list.append(effect)
	for effect in reference_list:
		effect.tick_effect()

func announce_change(eff=null):
	effects_changed.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
