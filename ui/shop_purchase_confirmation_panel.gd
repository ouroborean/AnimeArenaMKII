extends PanelContainer
class_name ShopConfirmationPanel

var _unlock_name
var _price

signal close_panel()
signal confirmed_purchase(unlock_name, price)

static func from_reward(price, current_ap, display_name, unlock_name):
	var panel = load("res://ui/shop_purchase_confirmation_panel.tscn").instantiate()
	panel.ingest_details(price, current_ap, display_name, unlock_name)
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_details(price, current_ap, display_name, unlock_name):
	$MarginContainer/VBoxContainer/MarginContainer/Label.text = "Purchasing " + display_name
	$MarginContainer/VBoxContainer/MarginContainer2/Label.text = "Price: " + str(price) + " (" + str(current_ap - price) + " remaining)"
	_price = price
	_unlock_name = unlock_name

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func confirm_clicked():
	confirmed_purchase.emit(_unlock_name, _price)
	close_panel.emit()


func decline_clicked():
	close_panel.emit()
