extends PanelContainer
class_name EnergyExchangePanel

var DEFAULT_EXCHANGE_RATE = 2
var random_required = DEFAULT_EXCHANGE_RATE

@export var function_row: HBoxContainer

var offer = {
	Energy.Type.GREEN: 0,
	Energy.Type.BLUE: 0,
	Energy.Type.WHITE: 0,
	Energy.Type.RED: 0
}


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

var requested_type: Energy.Type
signal hide_plus()
signal hide_minus()
signal show_plus()
signal show_minus()
signal exchange_complete(offer, request)
signal exchange_cancelled()

static func new_panel(true_pool):
	var panel = load("res://ui/energy_exchange_panel.tscn").instantiate()
	for energy_type in true_pool.keys():
		var row = ExchangeRow.from_energy_type(energy_type, true_pool[energy_type])
		row.change_offer.connect(panel.offer_changed)
		panel.hide_plus.connect(row.hide_offer)
		panel.hide_minus.connect(row.hide_remove)
		panel.show_plus.connect(row.show_offer)
		panel.show_minus.connect(row.show_remove)
		panel.add_row(row)
	panel.update_required()
	panel.add_buttons()
	panel.toggle_row_buttons()
	return panel

func add_row(row):
	$MarginContainer/VBoxContainer/MarginContainer3/VBoxContainer.add_child(row)

func update_required():
	if random_required > 0:
		$MarginContainer/VBoxContainer/Label.text = "Offer 2 Energy of the same color"
		$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.DIM_GRAY
	else:
		$MarginContainer/VBoxContainer/Label.text = "Press Confirm"
		$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.WHITE



func add_buttons():
	$MarginContainer/VBoxContainer/MarginContainer2.remove_child(function_row)
	$MarginContainer/VBoxContainer/MarginContainer2.add_child(function_row)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func get_total_offered():
	var total = 0
	for key in offer.keys():
		total += offer[key]
	return total

func toggle_row_buttons():
	if random_required == DEFAULT_EXCHANGE_RATE:
		hide_minus.emit()
	else:
		show_minus.emit()
	if random_required == 0:
		hide_plus.emit()
	else:
		show_plus.emit()

func offer_changed(etype, val):
	print("Offer changed!")
	offer[etype] += val
	random_required -= val
	update_required()
	toggle_row_buttons()

func continue_pressed(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		if random_required == 0:
			play_sound("click")
			exchange_complete.emit(offer, requested_type)

func cancel_pressed(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		exchange_cancelled.emit()
		queue_free()
		
func set_requested_type(etype):
	requested_type = etype

func toggle_selected_type(button):
	play_sound('click')
	for child in $MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow.get_children():
		if child != button:
			child.custom_minimum_size = Vector2(15, 15)
			continue
		child.custom_minimum_size = Vector2(25, 25)


func set_red(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		set_requested_type(Energy.Type.RED)
		toggle_selected_type($MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/RedButton)
	
func set_green(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		set_requested_type(Energy.Type.GREEN)
		toggle_selected_type($MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/GreenButton)

func set_blue(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		set_requested_type(Energy.Type.BLUE)
		toggle_selected_type($MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/BlueButton)

func set_white(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		set_requested_type(Energy.Type.WHITE)
		toggle_selected_type($MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/WhiteButton)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_continue_button_mouse_entered():
	if random_required > 0:
		return
	play_sound("hover")
	$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.hex(0xff2d21ff)

func _on_continue_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.WHITE

func _on_cancel_button_mouse_entered():
	play_sound("hover")
	$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.hex(0xff2d21ff)

func _on_cancel_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer2/FunctionButtonRow/ContinueButton.modulate = Color.WHITE

func _on_green_button_mouse_entered():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/GreenButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_green_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/GreenButton.modulate = Color.WHITE

func _on_blue_button_mouse_entered():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/BlueButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_blue_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/BlueButton.modulate = Color.WHITE

func _on_white_button_mouse_entered():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/WhiteButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_white_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/WhiteButton.modulate = Color.WHITE

func _on_red_button_mouse_entered():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/RedButton.modulate = Color.hex(0xffffff88)
	play_sound("hover")

func _on_red_button_mouse_exited():
	$MarginContainer/VBoxContainer/MarginContainer/ColorButtonRow/RedButton.modulate = Color.WHITE
