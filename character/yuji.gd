extends Character

var black_flash_minimum = 10

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	character_name = "Itadori Yuuji"
	path_name = "yuji"
	description = "Itadori Yuji, an up-and-coming jujutsu sorcerer. The tenuous vessel of the special grade cursed object Ryomen Sukuna, Yuji has an unbelievable capacity for cursed energy and a potential that he is only just beginning to explore."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func check_black_flash(args):
	var target = args[0]
	var flash = has_effect("Black Flash", EffectType.Type.MARK)
	if flash:
		var chance = flash.mag
		var roll = battle.roll(1, 100)
		if roll <= chance:
			manually_advance_mission(6, 1)
			var context = QueryContext.from_game_state(self, battle)
			Character.resolve_effect_damage(context, flash, target, 15, DamageType.Type.TRUE)
			var stun = Effect.stun_effect(2, ["Harmful"])
			stun.set_source(moveset.abilities[4])
			Character.add_hostile_effect(context, self, target, stun)
			flash.mag = black_flash_minimum
		else:
			flash.mag += 15
			manually_advance_mission(8, 10)
			if flash.mag >= 100:
				flash.mag = 100
	update.emit()

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
