extends PanelContainer
class_name MissionDescriptionPanel

@export var objective_description_container: VBoxContainer
@export var mission_texture: TextureRect
@export var mission_title_label: Label
@export var mission_rank_req_label: Label
@export var mission_description_label: Label
@export var mission_reward_container: VBoxContainer

signal close_mission_list_panel()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func reset():
	pass

static func from_mission(mission, player):
	var panel = load("res://ui/mission_description_panel.tscn").instantiate()
	panel.ingest_mission_details(mission, player)
	return panel

func ingest_mission_details(mission, player):
	mission_texture.texture = mission.image
	mission_title_label.text = mission._name
	mission_rank_req_label.text = "Rank Required: " + Rank.Type.keys()[mission.rank_requirement]
	mission_description_label.text = mission.description
	$MarginContainer/HBoxContainer/InfoColumn/MissionRewardMargin/VBoxContainer/RewardName.text = mission.rewards[0]
	var tooltip = RewardTooltip.from_texture(mission.rewards[1])
	mission_reward_container.add_child(tooltip)
	unpack_mission_objectives(mission.objectives, player)

func unpack_mission_objectives(objectives, player):
	for objective in objectives:
		var objective_label = Label.new()
		if player.mission_data[objective.mission_id][objective.obj_id] >= objective.max_progress:
			objective_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			objective_label.add_theme_color_override("font_color", Color.WHITE)
		objective_label.add_theme_font_size_override("font_size", 12)
		objective.current_progress = player.mission_data[objective.mission_id][objective.obj_id]
		objective_label.text = objective.description.call(objective)
		objective_description_container.add_child(objective_label)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_x_button_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		print("Clicked GUI Close")
		close_mission_list_panel.emit()
