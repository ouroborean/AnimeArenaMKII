extends MarginContainer
class_name ShopButton

var _unlock_name


# This unlock type could be an ENUM but for now it's just gonna be a string
# either "character", "portrait", or "gamepanel"
var _unlock_type
var _unlock_image
var _display_name
var _price

signal button_clicked(price, unlock_name, display_name)

static func from_reward_info(unlock_name, unlock_type, unlock_image, display_name, price):
	var button = load("res://ui/shop_button.tscn").instantiate()
	button.set_details(unlock_name, unlock_type, unlock_image, display_name, price)
	return button

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_details(unlock_name, unlock_type, unlock_image, display_name, price):
	_unlock_name = unlock_name
	_unlock_type = unlock_type
	_unlock_image = unlock_image
	_display_name = display_name
	_price = price
	if unlock_type == "gamepanel":
		$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.custom_minimum_size = Vector2(240, 0)
	elif unlock_type == "character":
		$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.custom_minimum_size = Vector2(50, 0)
	elif unlock_type == "portrait":
		$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.custom_minimum_size = Vector2(80, 0)
	elif unlock_type == "background":
		$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.custom_minimum_size = Vector2(160, 0)
	elif unlock_type == "playercard":
		$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.custom_minimum_size = Vector2(160, 0)
	$PanelContainer/VBoxContainer/MarginContainer3/Label.text = str(_price) + " AP"
	$PanelContainer/VBoxContainer/MarginContainer/Label.text = _display_name
	$PanelContainer/VBoxContainer/MarginContainer2/TextureRect.texture = _unlock_image

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func on_event(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		button_clicked.emit(_price, _unlock_name, _display_name)
