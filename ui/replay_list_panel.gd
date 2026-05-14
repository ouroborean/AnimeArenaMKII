extends PanelContainer
class_name ReplayListPanel

signal close_panel()
signal change_panel(panel)
signal replay_loaded(json_string: String)

var _status_label: Label
var _js_callback: JavaScriptObject

static func create() -> ReplayListPanel:
	var panel = ReplayListPanel.new()
	panel.custom_minimum_size = Vector2(340, 180)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.anchors_preset = Control.PRESET_CENTER

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(0.8, 0, 0, 1)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", bg)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "REPLAYS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.5, 0, 0, 1)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(0.7, 0, 0, 1)
	close_hover.corner_radius_top_left = 4
	close_hover.corner_radius_top_right = 4
	close_hover.corner_radius_bottom_left = 4
	close_hover.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(panel._on_close)
	header.add_child(close_btn)

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxFlat.new())
	vbox.add_child(sep)

	var load_btn = Button.new()
	load_btn.text = "Load Replay File..."
	load_btn.custom_minimum_size = Vector2(0, 40)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.12, 1)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.5, 0, 0, 1)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	load_btn.add_theme_stylebox_override("normal", normal)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.05, 0.05, 1)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.8, 0, 0, 1)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	load_btn.add_theme_stylebox_override("hover", hover)
	load_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	load_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	load_btn.add_theme_font_size_override("font_size", 14)
	load_btn.pressed.connect(panel._on_load_pressed)
	vbox.add_child(load_btn)

	panel._status_label = Label.new()
	panel._status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel._status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(panel._status_label)

	return panel


func _on_load_pressed():
	if OS.has_feature("web"):
		_open_web_file_picker()
	else:
		_open_native_file_dialog()


func _open_web_file_picker():
	_status_label.text = "Waiting for file..."
	# Create a hidden file input, click it, and read the result via JS callback.
	_js_callback = JavaScriptBridge.create_callback(_on_web_file_read)
	JavaScriptBridge.eval("""
	(function() {
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = '.replay';
		input.style.display = 'none';
		document.body.appendChild(input);
		input.addEventListener('change', function(e) {
			var file = e.target.files[0];
			if (!file) return;
			var reader = new FileReader();
			reader.onload = function(ev) {
				window._replayFileContent = ev.target.result;
				window._replayFileReady = true;
			};
			reader.readAsText(file);
			document.body.removeChild(input);
		});
		input.click();
	})();
	""", true)
	# Poll for the result since JS callbacks from file readers are async
	_poll_web_file()


func _poll_web_file():
	var ready = JavaScriptBridge.eval("window._replayFileReady === true;", true)
	if ready:
		var content = JavaScriptBridge.eval("window._replayFileContent;", true)
		JavaScriptBridge.eval("delete window._replayFileReady; delete window._replayFileContent;", true)
		if content is String and content != "":
			_status_label.text = ""
			replay_loaded.emit(content)
			close_panel.emit()
		else:
			_status_label.text = "Failed to read file."
	else:
		# Check again next frame
		get_tree().create_timer(0.1).timeout.connect(_poll_web_file)


func _on_web_file_read(args):
	pass


func _open_native_file_dialog():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.replay ; Replay Files"])
	dialog.size = Vector2i(600, 400)
	dialog.file_selected.connect(_on_native_file_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_native_file_selected(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_status_label.text = "Failed to open file."
		return
	var content = file.get_as_text()
	replay_loaded.emit(content)
	close_panel.emit()


func _on_close():
	close_panel.emit()
