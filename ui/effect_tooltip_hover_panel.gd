extends PanelContainer
class_name EffectTooltipHoverPanel
@export var row_container: VBoxContainer
@export var name_label: Label

var _canvas
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

var _effects

static func from_effects(effects):
	var panel = load("res://ui/effect_tooltip_hover_panel.tscn").instantiate()
	panel._effects = effects
	panel.name_label.text = effects[0].effect_name()
	print("Creating hover panel with height of " + str(panel.size.y))
	return panel

func update_from_effect(effect):
	set_description_text(effect)
	set_duration_text(effect.duration)
	

func set_duration_text(duration_remaining):
	var duration = load('res://ui/duration_label.tscn').instantiate()
	if duration_remaining > 0:
		duration_remaining = int(duration_remaining / 2.0)
	if duration_remaining == -1:
		duration.set_text("Permanent")
	elif duration_remaining < 1:
		duration.set_text("Ends this turn")
	else:
		duration.set_text(str(duration_remaining) + " turns left")
	row_container.add_child(duration)
	
func set_description_text(effect):
	var description
	if effect.source.user.mastery_skin_on:
		description = effect.source.replace_mastery_terms(effect.user, effect.description.call(effect))
	else:
		description = effect.description.call(effect)
	var desc = load('res://ui/description_label.tscn').instantiate()
	desc.desc.text = description
	row_container.add_child(desc)

func show_panel(canvas, tooltip):
	
	for effect in _effects:
		update_from_effect(effect)
	
	
	_canvas = canvas
	_canvas.add_child(self)
	
	var x_offset = 0
	if tooltip.global_position.x > 400:
		x_offset = 240
	var y_offset = 0
	if size.y > 570 - tooltip.global_position.y:
		y_offset = size.y - (570 - tooltip.global_position.y)
	
	position = tooltip.global_position + Vector2(30 - x_offset, -y_offset)
	visible = true
	$Timer.start()

func hide_panel():
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	var mousePos = get_global_mouse_position()
	var panel_x = global_position.x
	var panel_y = global_position.y
	if (mousePos.x >= panel_x and mousePos.x <= panel_x + size.x) and (mousePos.y >= panel_y and mousePos.y <= panel_y + size.y):
		return
	hide_panel()
		
