extends Node
class_name TeamComponent

@export var max_members = 3
@export var energy: EnergyPool

var characters: Array

signal energy_changed(val, element)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func add_character(character):
	if not character in characters and len(characters) < max_members:
		character.team = self
		characters.append(character)

func character_in_team(path, alive=true):
	for character in characters:
		if path == character.path_name and not character.dead or character.banished:
			return true
	return false

func remove_character(character):
	characters.erase(character)

func reset_energy_pool():
	energy.queue_free()
	energy = load("res://components/energypool.tscn").instantiate()

func instantiate_energy_pool():
	energy.queue_free()
	energy = load("res://components/energypool.tscn").instantiate()


func pretty_print():
	for character in characters:
		character.pretty_print()

func refund_ability(ability):
	for element in ability.cost():
		energy.change_promised_energy(element, -ability.cost()[element])

func pay_for_ability(ability):
	for element in ability.cost():
		energy.change_promised_energy(element, ability.cost()[element])

func change_energy(element, val):
	energy.change_energy(element, val)

func lose_energy(val, battle):
	for i in range(val):
		var drained = false
		while not drained:
			if energy.total_available() <= 0:
				return
			var roll = battle.roll(0, 3, "Valid energy loss type")
			if energy.pool[roll] >= 1:
				energy.change_energy(roll, -1)
				drained = true

func get_active_energy_types():
	var used_elements = [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]
	return used_elements

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
