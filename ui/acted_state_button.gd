extends PanelContainer
class_name ActedStateButton

signal acted_clicked()

var norm_texture = load("res://assets/images/placeholder_icon.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_acted(entity):
	if entity.used_ability != null:
		$TextureButton.texture_normal = entity.used_ability.return_image_with_mastery(entity)
		var action_name = entity.used_ability.return_name_with_mastery(entity)

func set_unacted():
	$TextureButton.texture_normal = norm_texture

func update(entity):
	if entity.waiting:
		set_acted(entity)
	else:
		set_unacted()
	if entity.battle.waiting_for_turn:
		modulate = Color.hex(0xffffff35)
	else:
		modulate = Color.WHITE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_character_link(character):
	acted_clicked.connect(character.acted_clicked)

func _on_texture_button_button_down():
	acted_clicked.emit()

func set_hovered():
	pass

func stop_hovered():
	pass
