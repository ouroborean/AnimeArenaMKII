extends Control
class_name MenuDisplayComponent

var current_menu
var menu_storage = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func set_menu(menu):
	current_menu = menu

func add_menu(menu_name, menu):
	if not menu_name in menu_storage.keys():
		add_child(menu)
		menu_storage[menu_name] = menu
		menu_storage[menu_name].visible=false
	
func hide_menu():
	if current_menu:
		current_menu.visible = false

func change_menu(menu_name):
	if menu_name in menu_storage.keys():
		hide_menu()
		menu_storage[menu_name].visible = true
		set_menu(menu_storage[menu_name])
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
