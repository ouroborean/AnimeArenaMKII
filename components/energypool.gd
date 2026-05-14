extends Node
class_name EnergyPool

var pool: Dictionary = {
	Energy.Type.GREEN: 0,
	Energy.Type.BLUE: 0,
	Energy.Type.WHITE: 0,
	Energy.Type.RED: 0
}

var promised_pool: Dictionary = {
	Energy.Type.GREEN: 0,
	Energy.Type.BLUE: 0,
	Energy.Type.WHITE: 0,
	Energy.Type.RED: 0,
	Energy.Type.RANDOM: 0
}
@export var display: EnergyDisplay

func reset_pool():
	pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0
	}
	promised_pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0,
		Energy.Type.RANDOM: 0
	}


func initialize_display(enemy=false):
	display.populate_rows()
	display.update_random_count(total_available())
	if enemy:
		display.visible = false

func deploy_energy_display(container):
	remove_child(display)
	display.visible = true
	container.add_child(display)

func total_available():
	var count = 0
	for key in pool:
		count += pool[key]
		count -= promised_pool[key]
	count -= promised_pool[Energy.Type.RANDOM]
	return count

func can_exchange():
	for key in pool:
		var key_count = 0
		key_count += pool[key]
		key_count -= promised_pool[key]
		if key_count >= 2 and total_available() >= 2:
			return true
	return false

func true_pool():
	var output = {}
	for key in pool:
		output[key] = pool[key] - promised_pool[key]
	return output

func can_afford(cost):
	var current_pool = true_pool()
	var total = total_available()
	for energy_type in cost:
		var type = energy_type
		var amount = cost[energy_type]
		if total < amount:
			return false
		if not type == Energy.Type.RANDOM:
			if current_pool[type] < amount:
				return false
			else:
				total -= amount
	return true

func clear_promised_pool():
	promised_pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0,
		Energy.Type.RANDOM: 0
	}



func receive_generic_allocation_offer(offer, replaying=false):
	if not replaying:
		for energy_type in pool:
			offer.append([energy_type, promised_pool[energy_type]])
	clear_promised_pool()
	for offer_set in offer:
		var element = offer_set[0]
		var count = offer_set[1]
		change_energy(element, -count)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func change_energy(element, val):
	element = int(element)
	# `pool` is keyed on GREEN/BLUE/WHITE/RED only — RANDOM is a cost token, not
	# a storable color. If something tries to add or drain RANDOM directly we
	# want to fail loudly instead of auto-vivifying `pool[4]` into a fake
	# negative bucket. Callers that need to spend RANDOM should go through
	# receive_generic_allocation_offer (which the random panel resolves into
	# specific colors) or change_promised_energy.
	if element == Energy.Type.RANDOM:
		push_error("EnergyPool.change_energy called with RANDOM type — route through receive_generic_allocation_offer instead")
		return
	if val > 0:
		gain_energy(element, val)
	else:
		lose_energy(element, val)
	display.change_energy(element, true_pool()[element])
	display.update_random_count(total_available())

func change_promised_energy(element, val):
	if val > 0:
		gain_promised_energy(element, val)
	else:
		lose_promised_energy(element, val)
	if element != Energy.Type.RANDOM:
		display.change_energy(element, true_pool()[element])
	display.update_random_count(total_available())

func gain_promised_energy(element, val):
	promised_pool[element] += val
	
func lose_promised_energy(element, val):
	promised_pool[element] += val

func gain_energy(element, val):
	pool[element] += val

func lose_energy(element, val):
	element = int(element)
	
	pool[element] += val
	
func promise_energy(element, val):
	promised_pool[element] += val

func open_energy_exchange():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
