extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ryohei gains a stack of To The Extreme!!, empowering his skills. For the rest of the game, whenever Ryohei receives 20 total damage, he gains a stack of To The Extreme!!"

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(extreme_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "Every 20 total damage Ryohei receives, he gains a stack of To The Extreme!!, empowering his abilities.")
	trigger.set_source(self)
	var mark = Effect.mark(-1, func (eff): return "Ryohei has " + str(eff.stacks) + " stacks of To the Extreme!! (" + str(eff.mag) + "/20)")
	mark.stackable = true
	mark.stacks = 1
	mark.set_source(self)
	var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.display_stacks = true
	damage_mod.unique_render_id = 5
	damage_mod.set_source(self)
	var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(mark.stacks) + " more turns.")
	empty.set_source(self)
	empty.stackable = true
	empty.unique_render_id = 5
	empty.display_stacks = true
	var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
	cost_mod.set_source(self)
	cost_mod.stackable = true
	cost_mod.unique_render_id = 5
	cost_mod.per_stack = true
	cost_mod.display_stacks = true
	Character.add_allied_effect(context, user, user, damage_mod)
	Character.add_allied_effect(context, user, user, empty)
	Character.add_allied_effect(context, user, user, cost_mod)
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, mark)

func extreme_trigger(context):
	var ryohei = context['effect'].target
	var mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	mark.mag += context['value']
	while mark.mag >= 20:
		mark.mag -= 20
		mark.stacks += 1
		var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
		damage_mod.stackable = true
		damage_mod.per_stack = true
		damage_mod.display_stacks = true
		damage_mod.unique_render_id = 5
		damage_mod.set_source(self)
		var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(mark.stacks) + " more turns.")
		empty.set_source(self)
		empty.stackable = true
		empty.unique_render_id = 5
		empty.display_stacks = true
		var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
		cost_mod.set_source(self)
		cost_mod.stackable = true
		cost_mod.per_stack = true
		cost_mod.unique_render_id = 5
		cost_mod.display_stacks = true
		Character.add_allied_effect(context, ryohei, ryohei, damage_mod)
		Character.add_allied_effect(context, ryohei, ryohei, empty)
		Character.add_allied_effect(context, ryohei, ryohei, cost_mod)
		
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 250)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("To the Extreme!!", user)
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
