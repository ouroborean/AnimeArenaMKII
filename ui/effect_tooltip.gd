extends PanelContainer
class_name EffectTooltip

var _effect_cluster: Array
@export var texture: TextureRect
var display_panel: EffectTooltipHoverPanel

signal tooltip_expired()
signal show_panel_request(panel)
signal hide_panel()

var hovered = false

static func from_effect_cluster(effect):
	var eff_tooltip = load("res://ui/effect_tooltip.tscn").instantiate()
	eff_tooltip.set_effect_cluster(effect)
	return eff_tooltip

func set_effect_cluster(effect):
	_effect_cluster = effect
	texture.texture = effect[0].tooltip
	for eff in _effect_cluster:
		if eff.display_mag:
			$TooltipMargin/TooltipMagDisplay.text = str(eff.mag)
		elif eff.display_stacks:
			$TooltipMargin/TooltipMagDisplay.text = str(eff.stacks)


func get_panel():
	_effect_cluster[0].user.battle.show_panel(self, EffectTooltipHoverPanel.from_effects(_effect_cluster))
	

func receive_effect_expired(effect):
	queue_free()
	tooltip_expired.emit()

# Called when the node enters the scene tree for the first time.
func play_entrance_animation():
	# Use custom_minimum_size for pivot since layout size may not be resolved yet
	pivot_offset = custom_minimum_size / 2.0
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)\
		.set_ease(Tween.EASE_OUT)

func _ready():
	pass
	
func _on_mouse_entered():
	if not hovered:
		get_panel()
		hovered = true
	



func _on_mouse_exited():
	hovered = false
