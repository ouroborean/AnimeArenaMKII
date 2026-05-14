extends Control
class_name EnergyTracker

@export var energy_type: Energy.Type = Energy.Type.RANDOM
var energy = 0

static func from_element(element):
	var tracker = load("res://ui/energy_tracker.tscn").instantiate()
	tracker.update_count(0)
	tracker.assign_element(element)
	return tracker

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func change_energy(val):
	energy = val
	update_count(energy)

func assign_element(element):
	var tooltip = Energy.get_symbol(element)
	if element == Energy.Type.RANDOM:
		tooltip = load("res://assets/images/total_energy.png")
	$HBoxContainer/TextureRect.texture = tooltip

func update_count(val):
	$HBoxContainer/Label.text = "x" + str(int(val))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
