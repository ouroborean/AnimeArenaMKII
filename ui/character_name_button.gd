extends PanelContainer
class_name CharacterNameButton

signal character_clicked()
var targeted = false
var enemy = false

var green = Color.hex(0x22b14c)
var yellow = Color.hex(0xedba2f)
var red = Color.hex(0xed2f2f)

var _shake_tween: Tween
var _flash_tween: Tween

#DEFAULT HAT POSITION:
# ( -65, -54 )

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func set_targeted():
	print("Received call to set targeted")
	if not (_flash_tween and _flash_tween.is_running()):
		$PanelContainer/MarginContainer/TextureButton.modulate = Color.INDIAN_RED
	$PanelContainer/MarginContainer/TextureButton/TextureRect.modulate = Color.WHITE
	targeted = true

func set_untargeted():
	if not (_flash_tween and _flash_tween.is_running()):
		$PanelContainer/MarginContainer/TextureButton.modulate = Color.WHITE
	targeted = false

func set_banished():
	pass

func change_color(entity):
	if entity.hp_hidden():
		return
	var hp = entity.health.hp
	var panel = $PanelContainer.get("theme_override_styles/panel")
	if hp > 75:
		panel.bg_color = Color(.133, .694, .298)
	elif hp > 35:
		panel.bg_color = Color(.929, .729, .184)
	else:
		panel.bg_color = Color(.929, .184, .184)

func change_frame(texture):
	var panel = get("theme_override_styles/panel/texture")
	panel.texture = load("res://assets/cosmetics/character_frames/" + texture + ".png")

func update(entity):
	$PanelContainer/MarginContainer/TextureButton.modulate = Color.WHITE
	if entity.targeted:
		set_targeted()
	else:
		set_untargeted()
	change_color(entity)
	$PanelContainer/MarginContainer/TextureButton.texture_normal = entity.active_portrait()
	update_targeter_icons(entity)

func update_targeter_icons(entity):
	
	var target_container = $PanelContainer/MarginContainer/TextureButton/TargetMargins/TargetContainer
	if enemy:
		target_container = $PanelContainer/MarginContainer/TextureButton/EnemyTargetMargins/TargetContainer
		$PanelContainer/MarginContainer/TextureButton/TextureRect.flip_h = true
		$PanelContainer/MarginContainer/TextureButton/TextureRect.position = Vector2(-40, -54)
	
	
	
	for child in target_container.get_children():
		child.queue_free()
		
	if entity.battle.waiting_for_turn:
		return
		
	var characters = entity.battle.player.team.characters
	for character in characters:
		if entity in character.targeter.targets:
			#TODO: Add icon
			var icon = CharacterButton.from_character(character)
			icon.custom_minimum_size = Vector2(25, 25)
			icon.tooltip_mode()
			target_container.add_child(icon)
			

const FLASH_DURATION = 0.6
const SHAKE_STEP_TIME = 0.05

func play_damage_flash():
	var btn = $PanelContainer/MarginContainer/TextureButton
	# Shake — match total flash duration
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var original_pos = btn.position
	var strength = 3.0
	var steps = int(FLASH_DURATION / SHAKE_STEP_TIME) - 1
	for i in range(steps):
		var offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		_shake_tween.tween_property(btn, "position", original_pos + offset, SHAKE_STEP_TIME)
	_shake_tween.tween_property(btn, "position", original_pos, SHAKE_STEP_TIME)
	# Color flash
	play_color_flash(Color(1.0, 0.3, 0.3))

func play_heal_flash():
	play_color_flash(Color(0.3, 1.0, 0.5))

func play_color_flash(color: Color):
	var btn = $PanelContainer/MarginContainer/TextureButton
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	var restore_color = Color.WHITE
	_flash_tween = create_tween()
	var half = FLASH_DURATION / 2.0
	btn.modulate = restore_color
	_flash_tween.tween_property(btn, "modulate", color, half)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_flash_tween.tween_property(btn, "modulate", restore_color, half)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func set_character_name(character):
	
	change_frame(character.portrait_frame)
	$PanelContainer/MarginContainer/TextureButton.texture_normal = character.portrait_texture
	get_hat(character.hat)
	character_clicked.connect(character.character_clicked)
	character.targeting_changed.connect(update)

func set_panel_texture(panel_name):
	var new_texture = StyleBoxTexture.new()
	new_texture.texture = load("res://assets/cosmetics/character_frames/" + panel_name + ".png")
	add_theme_stylebox_override("panel", new_texture)


func _on_texture_button_button_down():
	character_clicked.emit()

func set_hovered():
	pass

func get_hat(hat_name):
	print("Equipping hat with path " + hat_name)
	if hat_name == "none" or hat_name == "None":
		return
	var hat_texture = load("res://assets/cosmetics/character_baubles/" + hat_name+ ".png")
	$PanelContainer/MarginContainer/TextureButton/TextureRect.visible = true
	$PanelContainer/MarginContainer/TextureButton/TextureRect.texture = hat_texture
	

func stop_hovered():
	return
	if not targeted:
		modulate = Color.WHITE
	else:
		modulate = Color.YELLOW
