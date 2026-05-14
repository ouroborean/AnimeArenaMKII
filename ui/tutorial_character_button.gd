extends PanelContainer


var tween: Tween
var rng: RandomNumberGenerator

func get_panel_reference():
	return get("theme_override_styles/panel")

# Called when the node enters the scene tree for the first time.
func _ready():
	tween = create_tween()
	rng = RandomNumberGenerator.new()
	tween_color(Color.WHITE, true)
	shake()

func tween_color(color, parallel = false, duration=1.0):
	if parallel:
		tween.parallel().tween_property(get_panel_reference(), "bg_color", color, duration)
	else:
		tween.tween_property(get_panel_reference(), "bg_color", color, duration)

func shake():
	
	tween.tween_property(self, "position", Vector2(position.x + 5, position.y - 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x - 5, position.y + 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x + 5, position.y + 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x - 5, position.y - 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x + 5, position.y - 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x - 5, position.y + 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x + 5, position.y + 5), 0.05)
	tween.tween_property(self, "position", Vector2(position.x - 5, position.y - 5), 0.05)

	tween.tween_property(self, "position", position, 0.05)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
