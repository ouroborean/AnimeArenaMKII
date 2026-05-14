extends PanelContainer
class_name MissionShortcutPanel

signal mission_shortcut_clicked(panel)

var _panel

static func from_mission(mission, player):
	var shortcut_panel = load("res://ui/mission_shortcut_panel.tscn").instantiate()
	shortcut_panel.ingest_mission(mission, player)
	return shortcut_panel

static func from_mission_category(mission_list, category_name, category_image, player):
	var shortcut_panel = load("res://ui/mission_shortcut_panel.tscn").instantiate()
	shortcut_panel.from_details(mission_list, category_name, category_image, player)
	return shortcut_panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func from_details(mission_list, category_name, category_image, player):
	var mission_list_panel = MissionListPanel.from_mission_list(mission_list, player)
	_panel = mission_list_panel
	$MissionShortcutMargin/VBoxContainer/MissionTitle.text = category_name
	$MissionShortcutMargin/VBoxContainer/MissionImage.texture = category_image
	$MissionShortcutMargin/VBoxContainer/MissionRank.visible = false

func ingest_mission(mission, player):
	var mission_panel = MissionDescriptionPanel.from_mission(mission, player)
	_panel = mission_panel
	$MissionShortcutMargin/VBoxContainer/MissionTitle.text = mission._name
	$MissionShortcutMargin/VBoxContainer/MissionImage.texture = mission.image
	$MissionShortcutMargin/VBoxContainer/MissionRank.text = "Rank Required: " + Rank.Type.keys()[mission.rank_requirement].capitalize()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_link_label_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Clicked shortcut link!")
		mission_shortcut_clicked.emit(_panel)
