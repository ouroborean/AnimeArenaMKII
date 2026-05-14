extends MarginContainer
class_name DescriptionAnimator

signal script_finished
signal message_shown(index)
signal page_started(page_index)
signal page_finished(page_index)

@export var fade_duration: float = 0.3
@export var default_hold: float = 1.5
@export var auto_advance_pages: bool = false
@export var page_pause: float = 0.5
@export var click_to_advance: bool = true

var _container: VBoxContainer
var _script: Array = []
var _index: int = 0
var _page_index: int = 0
var _running: bool = false
var _waiting_for_input: bool = false
var _active_tween: Tween
var _epoch: int = 0


func _ready():
	_container = $VBoxContainer
	if click_to_advance:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)


func play(script: Array) -> void:
	_epoch += 1
	_halt()
	_script = script
	_index = 0
	_page_index = 0
	_running = true
	if not _script.is_empty():
		page_started.emit(0)
	_show_next(_epoch)


func stop() -> void:
	_epoch += 1
	_halt()


func next_page() -> void:
	if _script.is_empty():
		return
	var target := _page_index + 1
	if target >= total_pages():
		return
	go_to_page(target)


func previous_page() -> void:
	if _page_index <= 0:
		return
	go_to_page(_page_index - 1)


func go_to_page(target_page: int) -> void:
	if _script.is_empty():
		return
	var max_page := total_pages() - 1
	target_page = clamp(target_page, 0, max_page)
	_epoch += 1
	_waiting_for_input = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	clear()
	_running = true
	_page_index = target_page
	_index = _page_start_index(target_page)
	page_started.emit(target_page)
	_show_next(_epoch)


func total_pages() -> int:
	if _script.is_empty():
		return 0
	var count := 1
	for entry in _script:
		if _entry_is_break(entry):
			count += 1
	return count


func current_page() -> int:
	return _page_index


func skip() -> void:
	if not _running:
		return
	if _waiting_for_input:
		_advance_page()
		return
	_epoch += 1
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	while _index < _script.size():
		var entry = _script[_index]
		if _entry_is_break(entry):
			_index += 1
			_on_page_complete()
			return
		_spawn_entry(entry, true)
		message_shown.emit(_index)
		_index += 1
	_on_script_complete()


func clear() -> void:
	for child in _container.get_children():
		child.queue_free()


func is_running() -> bool:
	return _running


func is_waiting_for_input() -> bool:
	return _waiting_for_input


func _halt() -> void:
	_running = false
	_waiting_for_input = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	clear()


func _show_next(epoch: int) -> void:
	if epoch != _epoch or not _running:
		return
	if _index >= _script.size():
		_on_script_complete()
		return
	var entry = _script[_index]
	if _entry_is_break(entry):
		_index += 1
		_on_page_complete()
		return
	_spawn_entry(entry, false)
	message_shown.emit(_index)
	_index += 1
	var hold: float = entry.get("hold", default_hold)
	await get_tree().create_timer(hold).timeout
	_show_next(epoch)


func _spawn_entry(entry: Dictionary, instant: bool) -> void:
	var node: Control
	if entry.get("type", "") == "image":
		node = _build_image(entry)
	else:
		node = _build_label(entry)
	_container.add_child(node)
	if instant:
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	_active_tween = create_tween()
	_active_tween.tween_property(node, "modulate:a", 1.0, fade_duration)


func _build_image(entry: Dictionary) -> Control:
	var rect := TextureRect.new()
	rect.texture = entry.get("texture", null)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var size = entry.get("size", Vector2(64, 64))
	if size is Vector2:
		rect.custom_minimum_size = size
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect


func _build_label(entry: Dictionary) -> Control:
	var label := Label.new()
	label.text = entry.get("text", "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var color = entry.get("color", null)
	if color != null:
		var sett: LabelSettings = load("res://ui/char_desc_sub_label.tres").duplicate()
		if color is Color:
			sett.font_color = color
		label.label_settings = sett
	else:
		label.label_settings = load("res://ui/char_desc_base_label.tres")
	return label


func _entry_is_break(entry) -> bool:
	return entry is Dictionary and entry.get("type", "") == "break"


func _page_start_index(target_page: int) -> int:
	if target_page == 0:
		return 0
	var pages_passed := 0
	for i in _script.size():
		if _entry_is_break(_script[i]):
			pages_passed += 1
			if pages_passed == target_page:
				return i + 1
	return _script.size()


func _on_page_complete() -> void:
	page_finished.emit(_page_index)
	_page_index += 1
	if auto_advance_pages:
		var epoch := _epoch
		await get_tree().create_timer(page_pause).timeout
		if epoch == _epoch and _running:
			_advance_page()
	else:
		_waiting_for_input = true


func _advance_page() -> void:
	_waiting_for_input = false
	clear()
	page_started.emit(_page_index)
	_show_next(_epoch)


func _on_script_complete() -> void:
	_running = false
	_waiting_for_input = false
	script_finished.emit()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip()
