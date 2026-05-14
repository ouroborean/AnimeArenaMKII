extends MarginContainer
class_name EnergyDisplay

var trackers = {}
signal open_exchange_panel()

static func from_elements(elements):
	var display = load("res://ui/energy_display.tscn").instantiate()
	display.populate_rows()
	return display


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func populate_rows():
	for child in $VBoxContainer/EnergyDisplayPanel/MarginContainer/Rows.get_children():
		child.queue_free()
	var row_set = [
		Energy.Type.GREEN,
		Energy.Type.BLUE,
		Energy.Type.WHITE,
		Energy.Type.RED,
		Energy.Type.RANDOM,
	]
	add_row(row_set)
	
func change_energy(element, val):
	element = int(element)
	if element in trackers:
		trackers[element].change_energy(val)

func update_random_count(val):
	if trackers == {}:
		return
	if Energy.Type.RANDOM in trackers:
		trackers[Energy.Type.RANDOM].change_energy(val)

func get_total_from_trackers():
	var total = 0
	for i in range(4):
		total += trackers[i].energy
	return total

func add_row(row_set):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for element in row_set:
		var tracker = EnergyTracker.from_element(element)
		trackers[element] = tracker
		row.add_child(tracker)
	$VBoxContainer/EnergyDisplayPanel/MarginContainer/Rows.add_child(row)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_panel_container_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		open_exchange_panel.emit()


func _on_exchange_mouse_entered():
	$VBoxContainer/PanelContainer.modulate = Color.hex(0xffffff88)
	play_sound("hover")


func _on_exchange_mouse_exited():
	$VBoxContainer/PanelContainer.modulate = Color.WHITE
