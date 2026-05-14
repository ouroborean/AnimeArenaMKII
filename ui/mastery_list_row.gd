extends PanelContainer
class_name MasteryListRow

const COSMETIC_ASSET_PATHS = {
	"playercard": "res://assets/cosmetics/playercards/playercard_mastery_%s.png",
	"action_frame": "res://assets/cosmetics/game_panels/gamepanel_mastery_%s.png",
	"hat": "res://assets/cosmetics/character_baubles/hat_mastery_%s.png",
	"elite_action_frame": "res://assets/cosmetics/game_panels/mastery_panel_elite_%s.png",
}

var _unlock_type: String
var _character_path: String
var _portrait_texture: Texture2D
var _preview_popup: PanelContainer = null

static func from_unlock(unlock_name: String, required_level: int, current_level: int, character_path: String = "", portrait: Texture2D = null):
	var row = load("res://ui/mastery_list_row.tscn").instantiate()
	row._unlock_type = unlock_name
	row._character_path = character_path
	row._portrait_texture = portrait
	row.ingest_unlock(unlock_name, required_level, current_level)
	return row


func _ready():
	if _unlock_type in COSMETIC_ASSET_PATHS and _character_path != "":
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


func ingest_unlock(unlock_name: String, required_level: int, current_level: int):
	var unlocked = current_level >= required_level
	var display_name = unlock_name.replace("_", " ").capitalize()
	$MarginContainer/RowItem/ObjectiveLabel.text = display_name
	if unlocked:
		$MarginContainer/RowItem/ObjectiveLabel.label_settings.font_color = Color.GREEN
		$MarginContainer/RowItem/ObjectiveCount.text = "Unlocked"
	else:
		$MarginContainer/RowItem/ObjectiveLabel.label_settings.font_color = Color.hex(0x38363dff)
		$MarginContainer/RowItem/ObjectiveCount.text = "Level " + str(required_level)


func _get_cosmetic_texture() -> Texture2D:
	var path = COSMETIC_ASSET_PATHS[_unlock_type] % _character_path
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _build_popup_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.77, 0.71, 0.21)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style


func _on_mouse_entered():
	var texture = _get_cosmetic_texture()
	if texture == null:
		return
	_preview_popup = PanelContainer.new()
	_preview_popup.add_theme_stylebox_override("panel", _build_popup_style())

	var preview_size = Vector2(128, 128)

	if _unlock_type == "hat" and _portrait_texture != null:
		var hat_size = texture.get_size()
		var container = Control.new()
		container.custom_minimum_size = hat_size

		var face_size = Vector2(75, 75)
		var face_rect = TextureRect.new()
		face_rect.texture = _portrait_texture
		face_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_rect.custom_minimum_size = face_size
		face_rect.position = Vector2(((hat_size.x - face_size.x) * 0.5) + 12, ((hat_size.y - face_size.y) * 0.5) -2)
		face_rect.z_index = 0
		container.add_child(face_rect)

		var hat_rect = TextureRect.new()
		hat_rect.texture = texture
		hat_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		hat_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hat_rect.custom_minimum_size = hat_size
		hat_rect.position = Vector2.ZERO
		hat_rect.z_index = 1
		container.add_child(hat_rect)

		_preview_popup.add_child(container)
		preview_size = hat_size
	else:
		var tex_rect = TextureRect.new()
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = preview_size
		_preview_popup.add_child(tex_rect)

	var canvas = get_tree().root
	canvas.add_child(_preview_popup)
	_preview_popup.z_index = 100

	var mouse_pos = get_global_mouse_position()
	var popup_size = preview_size + Vector2(12, 12)
	var viewport_size = get_viewport_rect().size
	var x = mouse_pos.x + 16
	if x + popup_size.x > viewport_size.x:
		x = mouse_pos.x - popup_size.x - 16
	var y = mouse_pos.y - popup_size.y * 0.5
	y = clampf(y, 0, viewport_size.y - popup_size.y)
	_preview_popup.position = Vector2(x, y)


func _on_mouse_exited():
	if _preview_popup != null:
		_preview_popup.queue_free()
		_preview_popup = null


func _exit_tree():
	_on_mouse_exited()
