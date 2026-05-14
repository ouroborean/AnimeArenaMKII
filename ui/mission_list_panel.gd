extends PanelContainer
class_name MissionListPanel

signal close_mission_list_panel()

@export var list_container: GridContainer
var _missions

signal request_new_panel(panel)

static func from_mission_list(missions, player):
	var mission_list = load('res://ui/mission_list_panel.tscn').instantiate()
	mission_list.set_missions(missions, player)
	return mission_list

static func from_mission_categories(category_dict, player):
	var mission_list = load('res://ui/mission_list_panel.tscn').instantiate()
	mission_list.set_category_panels(category_dict, player)
	return mission_list

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_missions(missions, player):
	_missions = missions
	for mission in _missions:
		var panel = MissionShortcutPanel.from_mission(mission, player)
		panel.mission_shortcut_clicked.connect(mission_shortcut_clicked)
		list_container.add_child(panel)

func set_category_panels(category_dict, player):
	for category in category_dict["categories"]:
		print("Adding category " + category['name'])
		var mission_list = []
		for mission in category["missions"]:
			var panel = MissionShortcutPanel.from_mission(mission, player)
			panel.mission_shortcut_clicked.connect(mission_shortcut_clicked)
			mission_list.append(mission)
			
		var category_panel = MissionShortcutPanel.from_mission_category(mission_list, category['name'], category['image'], player)
		category_panel.mission_shortcut_clicked.connect(mission_shortcut_clicked)
		list_container.add_child(category_panel)

func mission_shortcut_clicked(panel):
	request_new_panel.emit(panel)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_x_button_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Clicked GUI Close")
		close_mission_list_panel.emit()
