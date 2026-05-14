extends PanelContainer
class_name ExecutionOrderTooltip

var _order_id
var _payload

signal dragging_tooltip(tooltip)

static func from_ability(ability, order_id):
	var tooltip = load("res://ui/ability_order_tooltip.tscn").instantiate()
	tooltip.set_tooltip(ability.user.character_name.capitalize() + "'s " + ability.ability_name)
	tooltip.set_texture(ability.user.portrait_texture)
	tooltip.set_payload(ability)
	tooltip.set_order_id(order_id)
	return tooltip
	
static func from_effect(effect, order_id):
	var tooltip = load('res://ui/effect_order_tooltip.tscn').instantiate()
	var effect_type_string = EffectType.Type.keys()[effect.effect_type].capitalize()
	effect_type_string.replace("_", " ")
	tooltip.set_tooltip(effect.user.character_name.capitalize() + "'s " + effect_type_string + " effect from " + effect.source.ability_name)
	tooltip.set_texture(effect.tooltip)
	tooltip.set_payload(effect)
	tooltip.set_order_id(order_id)
	return tooltip
	
static func from_variant(variant, order_id):
	if variant is Ability:
		return ExecutionOrderTooltip.from_ability(variant, order_id)
	elif variant is Array:
		return ExecutionOrderTooltip.from_effect(variant[0], order_id)
	elif variant is Effect or variant is DisplayEffect:
		return ExecutionOrderTooltip.from_effect(variant, order_id)

func _get_drag_data(ev_position):
	var preview = ExecutionOrderTooltip.from_variant(_payload, _order_id)
	dragging_tooltip.emit(self)
	set_texture(null)
	var c = Control.new()
	c.add_child(preview)
	preview.position.x = -ev_position.x
	preview.position.y = -ev_position.y
	preview.z_index = 15
	set_drag_preview(c)
	return preview

func execution_position():
	return position.x / 54

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_payload(payload):
	_payload = payload

func set_order_id(order_id):
	_order_id = order_id

func set_tooltip(tooltip):
	tooltip_text = tooltip

func regenerate_texture():
	if _payload is Ability:
		set_texture(_payload.user.portrait_texture)
	elif _payload is Array:
		set_texture(_payload[0].tooltip)
	elif _payload is Effect or _payload is DisplayEffect:
		set_texture(_payload.tooltip)

func set_texture(texture):
	$MarginContainer/TextureRect.texture = texture

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
