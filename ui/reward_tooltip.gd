extends PanelContainer
class_name RewardTooltip

static func from_texture(texture):
	var tooltip = load("res://ui/reward_tooltip.tscn").instantiate()
	tooltip.set_texture(texture)
	#TODO: Maybe reward link stuff goes here?
	return tooltip

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_texture(texture):
	$MarginContainer/TextureRect.texture = texture

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
