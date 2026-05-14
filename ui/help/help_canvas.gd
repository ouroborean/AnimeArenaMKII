extends Control
class_name HelpCanvas

# Full-screen container that holds the widgets making up a single help page.
# In author mode, clicks deselect; Delete removes the currently selected
# widget. In player mode, widgets pass mouse input through and the canvas
# itself just blocks clicks to the game UI behind it.
#
# Rendering model (handled by HelpDimLayer, the canvas's bottom-most child):
#   - Whole canvas dimmed at 65% by default
#   - Highlight widget rects cut clear through the dim
#   - Obscure widget rects painted fully opaque black (also cut by highlights)
# Highlight and obscure widgets contribute only their rect to the dim layer;
# they draw no fill of their own. They may still draw selection chrome and
# outline markers on top.

signal widget_added(widget)
signal widget_removed(widget)

var author_mode := false
var widgets: Array = []
var selected_widget: HelpWidget = null

var dim_layer: HelpDimLayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_dim_layer()

func _build_dim_layer() -> void:
	dim_layer = HelpDimLayer.new()
	dim_layer.name = "DimLayer"
	dim_layer.anchor_right = 1.0
	dim_layer.anchor_bottom = 1.0
	dim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_layer)
	_refresh_dim()

func _process(_dt: float) -> void:
	# Cheap pass that keeps the dim layer in sync with drag positions.
	if visible:
		_refresh_dim()

func _refresh_dim() -> void:
	if dim_layer == null:
		return
	var hl_rects: Array = []
	var obs_rects: Array = []
	for w in widgets:
		if w is HelpHighlightWidget:
			hl_rects.append(Rect2(w.position, w.size))
		elif w is HelpObscureWidget:
			obs_rects.append(Rect2(w.position, w.size))
	dim_layer.set_rects(hl_rects, obs_rects)

func set_author_mode(mode: bool) -> void:
	author_mode = mode
	for w in widgets:
		w.set_author_mode(mode)

func clear_widgets() -> void:
	for w in widgets:
		w.queue_free()
	widgets.clear()
	selected_widget = null
	_refresh_dim()

func add_widget(widget: HelpWidget) -> void:
	widget.widget_selected.connect(_on_widget_selected)
	add_child(widget)
	widget.set_author_mode(author_mode)
	widgets.append(widget)
	_refresh_dim()
	widget_added.emit(widget)

func remove_widget(widget: HelpWidget) -> void:
	if widget == selected_widget:
		selected_widget = null
	widgets.erase(widget)
	widget.queue_free()
	_refresh_dim()
	widget_removed.emit(widget)

func _on_widget_selected(widget: HelpWidget) -> void:
	if selected_widget != null and selected_widget != widget:
		selected_widget.set_selected_state(false)
	selected_widget = widget
	move_child(widget, -1)

func _gui_input(event: InputEvent) -> void:
	if not author_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_widget != null:
			selected_widget.set_selected_state(false)
			selected_widget = null
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not author_mode or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE and selected_widget != null:
			remove_widget(selected_widget)
			get_viewport().set_input_as_handled()

func serialize_widgets() -> Array:
	var out: Array = []
	for w in widgets:
		out.append(w.to_dict())
	return out

func deserialize_widgets(widget_dicts: Array) -> void:
	clear_widgets()
	for d in widget_dicts:
		if not d is Dictionary:
			continue
		var w := _make_widget_from_dict(d)
		if w != null:
			add_widget(w)
			w.apply_dict(d)
	# apply_dict moved widgets after add_widget already pushed defaults to the
	# dim layer — re-push with the loaded positions.
	_refresh_dim()

func _make_widget_from_dict(d: Dictionary) -> HelpWidget:
	var t := str(d.get("type", ""))
	match t:
		"obscure":
			return HelpObscureWidget.new()
		"highlight":
			return HelpHighlightWidget.new()
		"text":
			return HelpTextWidget.new()
		"arrow":
			return HelpArrowWidget.new()
	return null
