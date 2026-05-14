extends HBoxContainer
class_name EffectContainer


@export var tooltip_display: EffectTooltipDisplay
var _character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func sync_effects(character):
	_character = character
	character.effects.effects_changed.connect(update)

func update():
	var clusters = _character.effects.get_effect_clusters(_character.effects.get_renderable_effects())
	tooltip_display.get_effect_tooltips(clusters)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
