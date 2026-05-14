extends PanelContainer
class_name RandomPanel

@export var row_container: VBoxContainer
@export var title: Label
var energy_pool
var generic_owed
var rows = []
var accept_button
var dragging_order_tooltip


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

signal random_paid(execution_order, random_history)
signal cancel_panel()
signal enough_offered()
signal deal_has_changed()
signal request_sound(sound_name)

static func from_info(team, generic_required, execution_order):
	var panel = load("res://ui/random_panel.tscn").instantiate()
	panel.generic_owed = generic_required
	panel.title.text = "Offer " + str(int(generic_required)) + " Generic Energy"
	panel.energy_pool = team.energy
	for element in team.get_active_energy_types():
		var row = RandomPanelRow.from_info(element, team.energy.true_pool()[element])
		if generic_required == 0:
			row.disable_offer()
		row.offer_changed.connect(panel.update_random_offer)
		panel.enough_offered.connect(row.disable_offer)
		panel.deal_has_changed.connect(row.allow_offer)
		panel.row_container.add_child(row)
		panel.rows.append(row)
	
	panel.initialize_end_buttons()
	
	panel.toggle_accept_button()
	if execution_order == {}:
		panel.hide_execution_order()
	else:
		panel.initialize_execution_order(execution_order)
	
	return panel

func get_total_offer():
	var offer = []
	for row in rows:
		offer.append(row.report_offer_count())
	energy_pool.receive_generic_allocation_offer(offer)
	return offer

func initialize_end_buttons():
	var accept = load("res://ui/random_accept_button.tscn").instantiate()
	accept.button_clicked.connect(accept_button_clicked)
	accept_button = accept
	var cancel = load("res://ui/random_cancel_button.tscn").instantiate()
	cancel.button_clicked.connect(cancel_button_clicked)
	var sep = HSeparator.new()
	row_container.add_child(sep)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 25)
	row_container.add_child(row)
	row.add_child(accept)
	row.add_child(cancel)

func hide_execution_order():
	$MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer.visible = false

func initialize_execution_order(execution_order):
	for order_id in execution_order.keys():
		var tooltip = ExecutionOrderTooltip.from_variant(execution_order[order_id], int(order_id))
		tooltip.dragging_tooltip.connect(set_dragging_tooltip)
		$MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.add_child(tooltip)

func set_dragging_tooltip(tooltip):
	dragging_order_tooltip = tooltip

func release_dragged_tooltip():
	dragging_order_tooltip.regenerate_texture()
	dragging_order_tooltip = null

func check_reorder_position(pos):
	var local_x = pos.x - $MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.global_position.x
	var current_index = int(local_x / 54)
	if current_index < 0:
		current_index = 0
	if current_index >= len($MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.get_children()):
		current_index = len($MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.get_children()) - 1
	if dragging_order_tooltip.execution_position() != current_index:
		shuffle_tooltips(current_index)

func get_final_execution_order():
	var execution_order = []
	var tooltips = $MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.get_children()
	for tooltip in tooltips:
		execution_order.append(tooltip._order_id)
	return execution_order

func shuffle_tooltips(new_index):
	$MarginContainer/VBoxContainer/MarginContainer/ExecutionOrderContainer/OrderDisplayPanel/Margin/OrderDisplayContainer.move_child(dragging_order_tooltip, new_index)

func accept_button_clicked():
	play_sound("click")
	
	random_paid.emit(get_final_execution_order(), get_total_offer())
	queue_free()

func cancel_button_clicked():
	play_sound("click")
	cancel_panel.emit()
	queue_free()


func update_random_offer(val):
	play_sound("click")
	generic_owed -= val
	if generic_owed <= 0:
		enough_offered.emit()
	else:
		deal_has_changed.emit()
	toggle_accept_button()
	update_label()

func toggle_accept_button():
	if generic_owed <= 0:
		accept_button.show()
	else:
		accept_button.hide()

func update_label():
	if generic_owed <= 0:
		title.text = "Press Confirm"
	else:
		title.text = "Offer " + str(int(generic_owed)) + " Generic Energy"

# Called when the node enters the scene tree for the first time.
func _ready():
	set_process_input(true)
	update_label()

func _input(ev):
	if ev is InputEventMouseButton:
		if ev.button_index == 1 and ev.pressed == false and dragging_order_tooltip != null:
			release_dragged_tooltip()
	if dragging_order_tooltip != null and ev is InputEventMouseMotion:
		check_reorder_position(ev.position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
