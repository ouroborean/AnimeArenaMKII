extends CanvasLayer
class_name HelpOverlay

# Top-most overlay containing the always-visible '?' button and the help
# canvas. Lives as a child of root.tscn so it survives game reloads.
#
# Modes:
#   - author_mode (true in editor + debug builds): clicking '?' opens an
#     authoring session with a widget palette + page nav. Saves persist to
#     user://help_pages.json keyed by the current open-menu fingerprint.
#   - player mode: clicking '?' shows the pages saved for the current
#     fingerprint, read-only, with prev/next nav.

const BUTTON_SIZE := Vector2(34, 34)
const BUTTON_MARGIN := 6.0

var help_data: HelpData
var help_active := false
var author_mode := false

var current_fingerprint := ""
var current_pages: Array = []
var current_page_index := 0
var dirty := false

var root_control: Control
var help_button: Button
var help_canvas: HelpCanvas
var page_nav: Control
var palette: Control
var page_label: Label
var empty_label: Label
var fingerprint_label: Label
var save_status_label: Label
var esc_hint_label: Label

# Palette drag state (in author mode the palette + page nav can be relocated).
var palette_dragging := false
var palette_drag_start_mouse := Vector2.ZERO
var palette_drag_start_pal_left := 0.0
var palette_drag_start_pal_top := 0.0
var palette_drag_start_nav_left := 0.0
var palette_drag_start_nav_top := 0.0

# Inline page-nav arrows. Created per page beside the page's first text panel
# (if any). Cleared and rebuilt whenever the current page changes.
var inline_nav_buttons: Array = []
const INLINE_NAV_BUTTON_SIZE := Vector2(30, 30)
const INLINE_NAV_GAP := 6.0

func _ready() -> void:
	author_mode = OS.has_feature("editor") or OS.is_debug_build()
	help_data = HelpData.new()
	layer = 128
	_build_ui()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "HelpRoot"
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	help_canvas = HelpCanvas.new()
	help_canvas.name = "HelpCanvas"
	help_canvas.anchor_right = 1.0
	help_canvas.anchor_bottom = 1.0
	help_canvas.visible = false
	root_control.add_child(help_canvas)

	# Empty-state label, parented to canvas so it hides when canvas hides.
	empty_label = Label.new()
	empty_label.text = "No help has been written for this screen yet."
	empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	empty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	empty_label.add_theme_constant_override("outline_size", 4)
	empty_label.add_theme_font_size_override("font_size", 20)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.anchor_left = 0.5
	empty_label.anchor_top = 0.5
	empty_label.anchor_right = 0.5
	empty_label.anchor_bottom = 0.5
	empty_label.offset_left = -260
	empty_label.offset_right = 260
	empty_label.offset_top = -24
	empty_label.offset_bottom = 24
	empty_label.visible = false
	help_canvas.add_child(empty_label)

	# Page nav strip.
	page_nav = _build_page_nav()
	page_nav.visible = false
	root_control.add_child(page_nav)

	# Author palette (only in author mode).
	if author_mode:
		palette = _build_palette()
		palette.visible = false
		root_control.add_child(palette)

	# Help '?' button. Added last so it draws above everything.
	help_button = Button.new()
	help_button.name = "HelpButton"
	help_button.text = "?"
	help_button.tooltip_text = "Help"
	help_button.custom_minimum_size = BUTTON_SIZE
	help_button.anchor_left = 1.0
	help_button.anchor_right = 1.0
	help_button.offset_left = -BUTTON_SIZE.x - BUTTON_MARGIN
	help_button.offset_top = BUTTON_MARGIN
	help_button.offset_right = -BUTTON_MARGIN
	help_button.offset_bottom = BUTTON_SIZE.y + BUTTON_MARGIN
	help_button.add_theme_font_size_override("font_size", 22)
	help_button.pressed.connect(_toggle_help)
	root_control.add_child(help_button)

	# "Esc to exit" hint, shown to the left of the '?' button while help is open.
	esc_hint_label = Label.new()
	esc_hint_label.name = "EscHint"
	esc_hint_label.text = "Esc to exit"
	esc_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	esc_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	esc_hint_label.add_theme_constant_override("outline_size", 4)
	esc_hint_label.add_theme_font_size_override("font_size", 13)
	esc_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	esc_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	esc_hint_label.anchor_left = 1.0
	esc_hint_label.anchor_right = 1.0
	esc_hint_label.offset_left = -BUTTON_SIZE.x - BUTTON_MARGIN - 110
	esc_hint_label.offset_right = -BUTTON_SIZE.x - BUTTON_MARGIN - 4
	esc_hint_label.offset_top = BUTTON_MARGIN
	esc_hint_label.offset_bottom = BUTTON_SIZE.y + BUTTON_MARGIN
	esc_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esc_hint_label.visible = false
	root_control.add_child(esc_hint_label)

func _build_page_nav() -> Control:
	var bar := PanelContainer.new()
	bar.name = "PageNav"
	# Pinned to the bottom-left, sharing horizontal extent with the palette
	# above it. Page nav sits at the very bottom; palette stacks on top.
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 8
	bar.offset_right = 488
	bar.offset_top = -52
	bar.offset_bottom = -8
	bar.add_theme_stylebox_override("panel", _make_stylebox(Color(1, 1, 1, 0.7)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	bar.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	margin.add_child(hb)

	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(_on_prev_page)
	hb.add_child(prev)

	page_label = Label.new()
	page_label.text = "1/1"
	page_label.custom_minimum_size = Vector2(54, 0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(page_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_on_next_page)
	hb.add_child(next_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_help)
	hb.add_child(close_btn)

	return bar

func _build_palette() -> Control:
	var bar := PanelContainer.new()
	bar.name = "AuthorPalette"
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 8
	bar.offset_right = 488
	# Stacked directly above the page nav so the two bars touch.
	bar.offset_top = -142
	bar.offset_bottom = -52
	bar.add_theme_stylebox_override("panel", _make_stylebox(Color(0.7, 0, 0.12, 1)))

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 0)
	bar.add_child(root_vb)

	# Drag handle at the top of the panel. Grab and drag to relocate the
	# whole author UI (palette + page nav move together).
	var drag_bar := ColorRect.new()
	drag_bar.name = "DragHandle"
	drag_bar.custom_minimum_size = Vector2(0, 14)
	drag_bar.color = Color(0.6, 0, 0.1, 0.85)
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_bar.gui_input.connect(_on_palette_drag_input)
	root_vb.add_child(drag_bar)

	var drag_label := Label.new()
	drag_label.text = "≡  drag to move"
	drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	drag_label.add_theme_font_size_override("font_size", 10)
	drag_label.anchor_right = 1.0
	drag_label.anchor_bottom = 1.0
	drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_bar.add_child(drag_label)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	root_vb.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	# Top row: widget add buttons.
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	vb.add_child(add_row)

	var adders: Array = [
		["+ Obscure", _add_obscure],
		["+ Highlight", _add_highlight],
		["+ Text", _add_text],
		["+ Arrow", _add_arrow],
	]
	for entry in adders:
		var btn := Button.new()
		btn.text = entry[0]
		btn.pressed.connect(entry[1])
		add_row.add_child(btn)

	# Bottom row: page + save.
	var page_row := HBoxContainer.new()
	page_row.add_theme_constant_override("separation", 4)
	vb.add_child(page_row)

	var new_page := Button.new()
	new_page.text = "+ Page"
	new_page.pressed.connect(_on_new_page)
	page_row.add_child(new_page)

	var del_page := Button.new()
	del_page.text = "- Page"
	del_page.pressed.connect(_on_delete_page)
	page_row.add_child(del_page)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	page_row.add_child(save_btn)

	save_status_label = Label.new()
	save_status_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7, 1))
	save_status_label.add_theme_font_size_override("font_size", 12)
	save_status_label.custom_minimum_size = Vector2(110, 0)
	save_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_row.add_child(save_status_label)

	# Fingerprint label below, small.
	fingerprint_label = Label.new()
	fingerprint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	fingerprint_label.add_theme_font_size_override("font_size", 10)
	vb.add_child(fingerprint_label)

	return bar

func _make_stylebox(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.85)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	return sb

func _toggle_help() -> void:
	if help_active:
		_close_help()
	else:
		_open_help()

func _open_help() -> void:
	help_active = true
	current_fingerprint = MenuFingerprint.compute(get_tree().root, self)
	if fingerprint_label != null:
		fingerprint_label.text = "fingerprint: " + current_fingerprint
	current_pages = help_data.get_pages(current_fingerprint).duplicate(true)
	current_page_index = 0
	dirty = false
	help_canvas.visible = true
	# Author palette and standalone page-nav bar are no longer shown. Page
	# navigation is now inline arrows beside the first text panel on each page
	# (created in _attach_inline_page_nav after widgets load).
	if page_nav != null:
		page_nav.visible = false
	if palette != null:
		palette.visible = false
	if esc_hint_label != null:
		esc_hint_label.visible = true
	# Widgets render read-only — author drag/resize chrome disabled.
	help_canvas.set_author_mode(false)
	_load_current_page()
	_update_save_status("")

func _close_help() -> void:
	if not help_active:
		return
	if author_mode and dirty:
		_on_save()
	help_active = false
	_clear_inline_page_nav()
	help_canvas.clear_widgets()
	help_canvas.visible = false
	if page_nav != null:
		page_nav.visible = false
	if palette != null:
		palette.visible = false
	if esc_hint_label != null:
		esc_hint_label.visible = false
	empty_label.visible = false

func _load_current_page() -> void:
	_clear_inline_page_nav()
	help_canvas.clear_widgets()
	if current_pages.is_empty():
		empty_label.visible = true
		return
	empty_label.visible = false
	current_page_index = clamp(current_page_index, 0, current_pages.size() - 1)
	var page = current_pages[current_page_index]
	if not page is Dictionary:
		page = {"widgets": []}
		current_pages[current_page_index] = page
	var widget_dicts = page.get("widgets", [])
	if not widget_dicts is Array:
		widget_dicts = []
	help_canvas.deserialize_widgets(widget_dicts)
	_attach_inline_page_nav()

func _persist_current_page() -> void:
	if current_pages.is_empty():
		return
	current_pages[current_page_index] = {
		"widgets": help_canvas.serialize_widgets()
	}

# --- Inline page nav (arrows flanking the first text panel on each page) ---

func _attach_inline_page_nav() -> void:
	_clear_inline_page_nav()
	if current_pages.size() <= 1:
		return
	var first_text: HelpTextWidget = null
	for w in help_canvas.widgets:
		if w is HelpTextWidget:
			first_text = w
			break
	if first_text == null:
		return
	var center_y := first_text.position.y + first_text.size.y * 0.5 - INLINE_NAV_BUTTON_SIZE.y * 0.5
	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = INLINE_NAV_BUTTON_SIZE
	prev_btn.add_theme_font_size_override("font_size", 16)
	prev_btn.disabled = current_page_index <= 0
	prev_btn.pressed.connect(_on_prev_page)
	help_canvas.add_child(prev_btn)
	prev_btn.position = Vector2(
		first_text.position.x - INLINE_NAV_BUTTON_SIZE.x - INLINE_NAV_GAP,
		center_y
	)
	inline_nav_buttons.append(prev_btn)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = INLINE_NAV_BUTTON_SIZE
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.disabled = current_page_index >= current_pages.size() - 1
	next_btn.pressed.connect(_on_next_page)
	help_canvas.add_child(next_btn)
	next_btn.position = Vector2(
		first_text.position.x + first_text.size.x + INLINE_NAV_GAP,
		center_y
	)
	inline_nav_buttons.append(next_btn)

func _clear_inline_page_nav() -> void:
	for btn in inline_nav_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	inline_nav_buttons.clear()

func _on_prev_page() -> void:
	if current_page_index <= 0:
		return
	current_page_index -= 1
	_load_current_page()
	_update_page_label()

func _on_next_page() -> void:
	if current_page_index >= current_pages.size() - 1:
		return
	current_page_index += 1
	_load_current_page()
	_update_page_label()

func _on_new_page() -> void:
	_persist_current_page()
	current_pages.append({"widgets": []})
	current_page_index = current_pages.size() - 1
	dirty = true
	_load_current_page()
	_update_page_label()
	_update_save_status("Unsaved page added")

func _on_delete_page() -> void:
	if current_pages.is_empty():
		return
	current_pages.remove_at(current_page_index)
	if current_pages.is_empty():
		current_pages.append({"widgets": []})
	current_page_index = clamp(current_page_index, 0, current_pages.size() - 1)
	dirty = true
	_load_current_page()
	_update_page_label()
	_update_save_status("Unsaved deletion")

func _on_save() -> void:
	_persist_current_page()
	# Strip empty pages so we don't persist meaningless ones.
	var pruned: Array = []
	for page in current_pages:
		if page is Dictionary:
			var widget_dicts = page.get("widgets", [])
			if widget_dicts is Array and widget_dicts.size() > 0:
				pruned.append(page)
	help_data.set_pages(current_fingerprint, pruned)
	help_data.save_to_disk()
	dirty = false
	_update_save_status("Saved")

func _update_page_label() -> void:
	var total = max(current_pages.size(), 1)
	var idx = current_page_index + 1
	page_label.text = "%d/%d" % [idx, total]

func _update_save_status(msg: String) -> void:
	if save_status_label:
		save_status_label.text = msg

func _add_obscure() -> void:
	_spawn_widget(HelpObscureWidget.new())

func _add_highlight() -> void:
	_spawn_widget(HelpHighlightWidget.new())

func _add_text() -> void:
	_spawn_widget(HelpTextWidget.new())

func _add_arrow() -> void:
	var w := HelpArrowWidget.new()
	var p := _spawn_position()
	w.from_point = p
	w.to_point = p + Vector2(140, 60)
	help_canvas.add_widget(w)
	dirty = true
	_update_save_status("Unsaved changes")

func _spawn_widget(w: HelpWidget) -> void:
	w.position = _spawn_position()
	help_canvas.add_widget(w)
	dirty = true
	_update_save_status("Unsaved changes")

func _spawn_position() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x * 0.5 - 100, vp.y * 0.5 - 60)

func _unhandled_key_input(event: InputEvent) -> void:
	if not help_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_help()
		get_viewport().set_input_as_handled()

# --- Palette drag (author mode only) ---

func _on_palette_drag_input(event: InputEvent) -> void:
	if palette == null or page_nav == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		palette_dragging = true
		palette_drag_start_mouse = get_viewport().get_mouse_position()
		palette_drag_start_pal_left = palette.offset_left
		palette_drag_start_pal_top = palette.offset_top
		palette_drag_start_nav_left = page_nav.offset_left
		palette_drag_start_nav_top = page_nav.offset_top

func _process(_dt: float) -> void:
	if not palette_dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		palette_dragging = false
		return
	var delta := get_viewport().get_mouse_position() - palette_drag_start_mouse
	# Move palette by adjusting all four offsets together (preserves size).
	var pal_w := palette.offset_right - palette.offset_left
	var pal_h := palette.offset_bottom - palette.offset_top
	palette.offset_left = palette_drag_start_pal_left + delta.x
	palette.offset_right = palette.offset_left + pal_w
	palette.offset_top = palette_drag_start_pal_top + delta.y
	palette.offset_bottom = palette.offset_top + pal_h
	# Move page nav in lock-step so the unit stays attached.
	var nav_w := page_nav.offset_right - page_nav.offset_left
	var nav_h := page_nav.offset_bottom - page_nav.offset_top
	page_nav.offset_left = palette_drag_start_nav_left + delta.x
	page_nav.offset_right = page_nav.offset_left + nav_w
	page_nav.offset_top = palette_drag_start_nav_top + delta.y
	page_nav.offset_bottom = page_nav.offset_top + nav_h
