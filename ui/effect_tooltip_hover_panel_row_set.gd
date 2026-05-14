extends PanelContainer
class_name EffectTooltipRow

@export var duration: Label
@export var desc: Label

var effect_source: Effect

static func from_effect(effect):
	var hover_row_set = load("res://ui/effect_tooltip_hover_panel_row_set.tscn").instantiate()
	hover_row_set.update_from_effect(effect)
	effect.effect_updated.connect(hover_row_set.update_from_effect)
	return hover_row_set


func update_from_effect(effect):
	set_duration_text(effect.duration)
	set_description_text(effect.description.call(effect))
	effect_source = effect

func set_duration_text(duration_remaining):
	
	if duration_remaining <= -1:
		duration.text = "Permanent"
		return
	if int(duration_remaining / 2) <= 1:
		duration.text = "Ends this turn"
	else:
		duration.text = str(int(duration_remaining / 2)) + " turns remaining"
	
	
func set_description_text(description):
	desc.text = description

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
