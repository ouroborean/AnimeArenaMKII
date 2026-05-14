extends GridContainer

signal letter_action(value: String)

var is_shift: bool = false
var keys = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM", "0123456789", ".,?!$&@-"]

func _ready():
	columns = 10
	create_keyboard()

func create_keyboard():
	for child in get_children():
		child.queue_free()

	# Generate Letter Keys
	for row in keys:
		for letter in row:
			var char_to_add = letter if is_shift else letter.to_lower()
			_add_button(char_to_add, char_to_add)
	
	# Action Keys
	_add_button("SHIFT", "toggle_shift")
	_add_button("⌫", "backspace")

func _add_button(label: String, action: String):
	var btn = Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	if action == "toggle_shift":
		btn.pressed.connect(_toggle_shift)
	elif action == "backspace":
		btn.pressed.connect(func(): letter_action.emit("backspace"))
	else:
		btn.pressed.connect(func(): letter_action.emit(action))
		
	add_child(btn)

func _toggle_shift():
	is_shift = !is_shift
	create_keyboard()

# Example of how to handle the signal in your main script:
# func _on_keyboard_letter_action(value):
#     if value == "backspace":
#         line_edit.text = line_edit.text.left(-1)
#     else:
#         line_edit.text += value
