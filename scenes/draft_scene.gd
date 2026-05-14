extends Control
class_name DraftScene

signal character_hovered(character)
signal character_picked(character)
signal character_banned(character)
signal confirm_pressed(character)

const TEAM_SIZE := 3
const BAN_COUNT := 3
const GRID_COLUMNS := 12
const SLOT_SIZE := Vector2(52, 52)
const LARGE_SLOT_SIZE := Vector2(64, 64)
const AVATAR_SIZE := Vector2(64, 64)
const HEADER_HEIGHT := 88
const TEAM_ROW_HEIGHT := 76
const BAN_ROW_HEIGHT := 64
const FOOTER_HEIGHT := 56
const SIDE_PADDING := 12
const SECTION_GAP := 6

var _player
var _enemy
var _all_characters := []
var _character_buttons := {}
var _player_team := []
var _enemy_team := []
var _player_bans := []
var _enemy_bans := []
var _selected_character = null
var _phase := "pick" # or "ban"
var _is_player_turn := true

var _root_vbox: VBoxContainer
var _header_row: HBoxContainer
var _player_header: PanelContainer
var _enemy_header: PanelContainer
var _player_team_row: HBoxContainer
var _enemy_team_row: HBoxContainer
var _player_ban_row: HBoxContainer
var _enemy_ban_row: HBoxContainer
var _center_panel: PanelContainer
var _grid_container: GridContainer
var _footer_row: HBoxContainer
var _status_label: Label
var _confirm_button: Button
var _player_name_label: Label
var _player_record_label: Label
var _player_avatar: TextureRect
var _enemy_name_label: Label
var _enemy_record_label: Label
var _enemy_avatar: TextureRect


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_populate_grid()
	_update_status("Awaiting opponent...")


func assign_player(player) -> void:
	_player = player
	_refresh_player_header()


func assign_enemy(enemy) -> void:
	_enemy = enemy
	_refresh_enemy_header()


func set_phase(phase: String, is_player_turn: bool) -> void:
	_phase = phase
	_is_player_turn = is_player_turn
	var who := "your" if is_player_turn else "opponent's"
	_update_status(("It's " + who + " turn to ") + ("pick." if phase == "pick" else "ban."))
	_confirm_button.disabled = not is_player_turn or _selected_character == null


func add_pick(character, for_player: bool) -> void:
	var target_row := _player_team_row if for_player else _enemy_team_row
	var target_list: Array = _player_team if for_player else _enemy_team
	if target_list.size() >= TEAM_SIZE:
		return
	target_list.append(character)
	_append_slot(target_row, character, LARGE_SLOT_SIZE, not for_player)
	_mark_button_unavailable(character, Color(0.25, 0.6, 0.25))


func add_ban(character, for_player: bool) -> void:
	var target_row := _player_ban_row if for_player else _enemy_ban_row
	var target_list: Array = _player_bans if for_player else _enemy_bans
	if target_list.size() >= BAN_COUNT:
		return
	target_list.append(character)
	_append_slot(target_row, character, SLOT_SIZE, not for_player)
	_mark_button_unavailable(character, Color(0.6, 0.2, 0.2))


func _build_ui() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.anchor_right = 1.0
	_root_vbox.anchor_bottom = 1.0
	_root_vbox.offset_left = SIDE_PADDING
	_root_vbox.offset_right = -SIDE_PADDING
	_root_vbox.offset_top = SIDE_PADDING
	_root_vbox.offset_bottom = -SIDE_PADDING
	_root_vbox.add_theme_constant_override("separation", SECTION_GAP)
	add_child(_root_vbox)

	_build_header()
	_build_team_strip()
	_build_ban_strip()
	_build_center_panel()
	_build_footer()


func _build_header() -> void:
	_header_row = HBoxContainer.new()
	_header_row.custom_minimum_size.y = HEADER_HEIGHT
	_header_row.add_theme_constant_override("separation", SECTION_GAP)
	_root_vbox.add_child(_header_row)

	_player_header = _make_player_header_panel(true)
	_header_row.add_child(_player_header)

	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 24)
	vs_label.custom_minimum_size = Vector2(48, 0)
	_header_row.add_child(vs_label)

	_enemy_header = _make_player_header_panel(false)
	_header_row.add_child(_enemy_header)


func _make_player_header_panel(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	style.border_color = Color(0.9, 0.75, 0.2) if is_player else Color(0.85, 0.25, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = AVATAR_SIZE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(avatar)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "---"
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var record_label := Label.new()
	record_label.text = "Record: 0 - 0"
	record_label.add_theme_font_size_override("font_size", 12)
	info.add_child(record_label)

	if is_player:
		_player_avatar = avatar
		_player_name_label = name_label
		_player_record_label = record_label
	else:
		_enemy_avatar = avatar
		_enemy_name_label = name_label
		_enemy_record_label = record_label

	return panel


func _build_team_strip() -> void:
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size.y = TEAM_ROW_HEIGHT
	wrapper.add_theme_stylebox_override("panel", _make_section_style(Color(0.08, 0.08, 0.12, 0.85)))
	_root_vbox.add_child(wrapper)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SECTION_GAP)
	wrapper.add_child(row)

	_player_team_row = _make_slot_row(TEAM_SIZE, LARGE_SLOT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	_player_team_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_player_team_row)

	var divider := VSeparator.new()
	row.add_child(divider)

	_enemy_team_row = _make_slot_row(TEAM_SIZE, LARGE_SLOT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	_enemy_team_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_enemy_team_row)


func _build_ban_strip() -> void:
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size.y = BAN_ROW_HEIGHT
	wrapper.add_theme_stylebox_override("panel", _make_section_style(Color(0.15, 0.05, 0.05, 0.85)))
	_root_vbox.add_child(wrapper)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SECTION_GAP)
	wrapper.add_child(row)

	var pl_label := Label.new()
	pl_label.text = "BANS"
	pl_label.add_theme_font_size_override("font_size", 14)
	pl_label.modulate = Color(0.85, 0.3, 0.3)
	row.add_child(pl_label)

	_player_ban_row = _make_slot_row(BAN_COUNT, SLOT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	_player_ban_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_player_ban_row)

	var divider := VSeparator.new()
	row.add_child(divider)

	_enemy_ban_row = _make_slot_row(BAN_COUNT, SLOT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	_enemy_ban_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_enemy_ban_row)

	var en_label := Label.new()
	en_label.text = "BANS"
	en_label.add_theme_font_size_override("font_size", 14)
	en_label.modulate = Color(0.85, 0.3, 0.3)
	row.add_child(en_label)


func _build_center_panel() -> void:
	_center_panel = PanelContainer.new()
	_center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_panel.add_theme_stylebox_override("panel", _make_section_style(Color(0.06, 0.06, 0.09, 0.9)))
	_root_vbox.add_child(_center_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_center_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_grid_container = GridContainer.new()
	_grid_container.columns = GRID_COLUMNS
	_grid_container.add_theme_constant_override("h_separation", SECTION_GAP)
	_grid_container.add_theme_constant_override("v_separation", SECTION_GAP)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_container)


func _build_footer() -> void:
	_footer_row = HBoxContainer.new()
	_footer_row.custom_minimum_size.y = FOOTER_HEIGHT
	_footer_row.add_theme_constant_override("separation", 16)
	_root_vbox.add_child(_footer_row)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_footer_row.add_child(_status_label)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(128, 44)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_footer_row.add_child(_confirm_button)


func _populate_grid() -> void:
	_all_characters = CharacterDatabase.get_characters()
	for character in _all_characters:
		var button = CharacterButton.from_character(character)
		button.custom_minimum_size = SLOT_SIZE
		button.button_clicked.connect(_on_character_clicked)
		button.mouse_entered.connect(func(): emit_signal("character_hovered", character))
		_character_buttons[character.path_name] = button
		_grid_container.add_child(button)


func _make_section_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_slot_row(count: int, slot_size: Vector2, align: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SECTION_GAP)
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		row.alignment = BoxContainer.ALIGNMENT_END
	else:
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in count:
		row.add_child(_make_empty_slot(slot_size))
	return row


func _make_empty_slot(slot_size: Vector2) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = slot_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _append_slot(row: HBoxContainer, character, slot_size: Vector2, enemy_side: bool) -> void:
	var children := row.get_children()
	for child in children:
		if child is PanelContainer and child.get_child_count() == 0:
			row.remove_child(child)
			child.queue_free()
			var button = CharacterButton.from_character(character, enemy_side)
			button.custom_minimum_size = slot_size
			row.add_child(button)
			if enemy_side and row.alignment == BoxContainer.ALIGNMENT_END:
				row.move_child(button, 0)
			return


func _mark_button_unavailable(character, tint: Color) -> void:
	if not _character_buttons.has(character.path_name):
		return
	var button = _character_buttons[character.path_name]
	button.set_locked()
	button.modulate = tint


func _refresh_player_header() -> void:
	if _player == null:
		return
	_player_name_label.text = _player._name.show() if _player._name else str(_player.username)
	if _player.avatar_texture:
		_player_avatar.texture = _player.avatar_texture
	if _player.rank:
		_player_record_label.text = "Record: %d - %d" % [int(_player.rank.wins), int(_player.rank.losses)]


func _refresh_enemy_header() -> void:
	if _enemy == null:
		return
	_enemy_name_label.text = _enemy._name.show() if _enemy._name else str(_enemy.username)
	if _enemy.avatar_texture:
		_enemy_avatar.texture = _enemy.avatar_texture
	if _enemy.rank:
		_enemy_record_label.text = "Record: %d - %d" % [int(_enemy.rank.wins), int(_enemy.rank.losses)]


func _update_status(text: String) -> void:
	_status_label.text = text


func _on_character_clicked(character, locked: bool) -> void:
	if locked or not _is_player_turn:
		return
	_selected_character = character
	_confirm_button.disabled = false
	var verb := "Pick" if _phase == "pick" else "Ban"
	_confirm_button.text = verb + ": " + character.character_name


func _on_confirm_pressed() -> void:
	if _selected_character == null:
		return
	if _phase == "pick":
		character_picked.emit(_selected_character)
	else:
		character_banned.emit(_selected_character)
	confirm_pressed.emit(_selected_character)
	_selected_character = null
	_confirm_button.text = "Confirm"
	_confirm_button.disabled = true
