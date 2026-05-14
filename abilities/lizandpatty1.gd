extends Ability

func describe(user):
	return "Target ally wields the active Thompson Sister. This effect lasts until Transform: Demon Twin Guns is used on a new target, at which point it ends on the previous target. The Thompson Sisters gain 10 Damage Reduction, and if the targeted ally uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target. Allies wielding Liz have their Green costs changed to Random. Allies wielding Patty have their Blue costs changed to Random."

func split_desc():
	return [
		"Target ally wields the active Thompson Sister.",
		["Lasts until used on a new target, then ends on the previous target.", Color.DIM_GRAY],
		"The Thompson Sisters gain 10 Damage Reduction.",
		["If the targeted ally uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target.", Color.CADET_BLUE],
		["Allies wielding Liz have their Green costs changed to Random.", Color.DIM_GRAY],
		["Allies wielding Patty have their Blue costs changed to Random.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive = user.moveset.base_abilities[6]

	var active_sister = "Liz"
	var active_mark = user.has_effect("Brooklyn Devils", EffectType.Type.MARK, user)
	if active_mark != null and active_mark.mag == 1:
		active_sister = "Patty"
	var other_sister = "Patty" if active_sister == "Liz" else "Liz"

	# Only one wielder at a time per Thompson: wipe any prior Transform instance
	# that THIS Thompson created (mark + color change + harmful trigger + the DR
	# on Thompson). Passing `user` scopes removal so an enemy Thompson's
	# transforms are not cleared.
	for ch in battle.all_characters():
		ch.effects.full_remove_effect_by_name("Transform: Demon Twin Guns", user)

	for target in user.targeter.targets:
		apply_wielder_package(user, target, active_sister, -1, context)

	var dr = Effect.damage_reduction_effect(10, -1)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)

	passive.set_active_sister(user, other_sister, context)

# Shared helper used by Transform's execute and CE's wrapups. The wielder mark,
# color change, and harmful-use trigger are all sourced from this ability so
# they share effect_name "Transform: Demon Twin Guns" and the same icon, and
# clean up together when full_remove_effect_by_name runs. Sister identity lives
# in the wielder mark's mag (0 = Liz, 1 = Patty, 2 = both — only when the
# target is Death the Kid). refresh=true so that re-applying on the same
# target replaces the old package.
func apply_wielder_package(thompson, target, sister: String, duration: int, context):
	if target == null:
		return

	# Special Death the Kid synergy: Kid wields both sisters at once, gets both
	# color changes, and WC: Liz replaces Transform on Thompson's ability bar
	# for the duration. See kid5 for the full rundown of this interaction.
	if target.path_name == "kid":
		_apply_dual_wielder_package(thompson, target, duration, context)
		return

	var sister_mag = 0 if sister == "Liz" else 1

	var wield_mark = Effect.mark(duration, "This character is wielding " + sister + ".")
	wield_mark.set_source(self)
	wield_mark.refresh = true
	wield_mark.mag = sister_mag
	Character.add_allied_effect(context, thompson, target, wield_mark)

	var changed_color = Energy.Type.GREEN if sister == "Liz" else Energy.Type.BLUE
	var color_change = Effect.color_change_effect(Energy.Type.RANDOM, changed_color, duration)
	color_change.set_source(self)
	color_change.refresh = true
	Character.add_allied_effect(context, thompson, target, color_change)

	var harmful_trigger = Effect.trigger_effect(
		Trigger.always(harmful_use_trigger),
		EffectType.Type.HARMFUL_USE_TRIGGER,
		duration,
		"If this character uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target."
	)
	harmful_trigger.set_source(self)
	harmful_trigger.refresh = true
	Character.add_allied_effect(context, thompson, target, harmful_trigger)

# Death the Kid dual-wielder package. Transform's execute always runs
# full_remove_effect_by_name across every character before calling this, so
# we don't need refresh=true — both color changes can coexist as independent
# appends because the storage only merges when refresh is set on the existing
# effect. mag == 2 signals the dual-wield state to _find_wielder lookups.
# The slot 0 swap is installed by set_active_sister on the passive right after
# this returns (and again on every sister flip), so both WC skills stay
# available to Kid without duplicating whichever WC the passive exposes at
# slot 2.
func _apply_dual_wielder_package(thompson, kid, duration: int, context):
	var wield_mark = Effect.mark(duration, "This character is wielding both Liz and Patty.")
	wield_mark.set_source(self)
	wield_mark.mag = 2
	Character.add_allied_effect(context, thompson, kid, wield_mark)

	var color_liz = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.GREEN, duration)
	color_liz.set_source(self)
	Character.add_allied_effect(context, thompson, kid, color_liz)

	var color_patty = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.BLUE, duration)
	color_patty.set_source(self)
	Character.add_allied_effect(context, thompson, kid, color_patty)

	var harmful_trigger = Effect.trigger_effect(
		Trigger.always(harmful_use_trigger),
		EffectType.Type.HARMFUL_USE_TRIGGER,
		duration,
		"If this character uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target."
	)
	harmful_trigger.set_source(self)
	Character.add_allied_effect(context, thompson, kid, harmful_trigger)

# Re-installs Transform's slot 0 ability swap to the WC that is NOT the one the
# passive is exposing at slot 2 this turn. Passive leaves slot 2 as native
# WC: Patty (slot 2) when Liz is active and swaps it to WC: Liz (slot 4) when
# Patty is active — so we pick the opposite for slot 0. Called from
# set_active_sister so the pairing flips with every sister change.
func refresh_kid_transform_swap(thompson, context):
	for swap in thompson.get_ability_swap_effects():
		if swap.source == self and int(swap.mag[1]) == 0:
			thompson.effects.erase_effect(swap)

	var active = thompson.has_effect("Brooklyn Devils", EffectType.Type.MARK, thompson)
	var patty_active = active != null and active.mag == 1
	var wc_slot = 2 if patty_active else 4

	var transform_swap = Effect.ability_swap_effect(wc_slot, 0, thompson, -1)
	transform_swap.set_source(self)
	Character.add_allied_effect(context, thompson, thompson, transform_swap)

func harmful_use_trigger(context):
	var thompson = context['owner']
	var wielder = context['target']
	if wielder == null:
		return
	var primary = wielder.targeter.main_target
	if primary == null:
		return
	var stored = thompson.used_ability
	thompson.used_ability = self
	Character.resolve_damage(context, primary, 10, DamageType.Type.NORMAL)
	thompson.used_ability = stored

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
