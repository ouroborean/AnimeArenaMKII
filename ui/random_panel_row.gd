extends MarginContainer
class_name RandomPanelRow

var element
var owned_count
var offered_count = 0
var offer_disabled = false
signal offer_changed(val)

static func from_info(nelement, energy):
	var row = load("res://ui/random_panel_row.tscn").instantiate()
	row.set_element(nelement)
	row.owned_count = energy
	row.update_row()
	return row



func set_element(nelement):
	element = nelement
	$HBoxContainer/ElementSymbol.texture = Energy.get_symbol(element)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func report_offer_count():
	return [element, offered_count]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update_row():
	$HBoxContainer/OwnedCount.text = str(int(owned_count))
	$HBoxContainer/OfferedCount.text = str(int(offered_count))

func remove_button_clicked():
	if offered_count > 0:
		offered_count -= 1
		owned_count += 1
		offer_changed.emit(-1)
		update_row()

func disable_offer():
	offer_disabled = true

func allow_offer():
	offer_disabled = false

func offer_button_clicked():
	if owned_count > 0 and not offer_disabled:
		offered_count += 1
		owned_count -= 1
		offer_changed.emit(1)
		update_row()
