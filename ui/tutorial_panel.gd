extends CanvasLayer
class_name TutorialPanel

signal closed

const DOT_SIZE := Vector2(8, 8)
const DOT_ACTIVE := Color(1, 1, 1, 1)
const DOT_INACTIVE := Color(0.4, 0.4, 0.4, 1)

@export var animator: DescriptionAnimator
@export var name_label: Label
@export var close_button: BaseButton
@export var prev_button: Button
@export var next_button: Button
@export var page_dots: HBoxContainer

var _character


static func show_for(character, parent: Node) -> TutorialPanel:
	var panel: TutorialPanel = load("res://ui/tutorial_panel.tscn").instantiate()
	parent.add_child(panel)
	panel.set_character(character)
	return panel


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	animator.page_started.connect(_on_page_started)
	animator.script_finished.connect(_on_script_finished)


func set_character(character) -> void:
	_character = character
	name_label.text = character.character_name
	var script: Array = TutorialLoader.script_for(character)
	_build_page_dots(_count_pages(script))
	animator.play(script)


func _count_pages(script: Array) -> int:
	if script.is_empty():
		return 0
	var count := 1
	for entry in script:
		if entry is Dictionary and entry.get("type", "") == "break":
			count += 1
	return count


func _build_page_dots(total: int) -> void:
	for child in page_dots.get_children():
		page_dots.remove_child(child)
		child.queue_free()
	for i in total:
		var dot := ColorRect.new()
		dot.custom_minimum_size = DOT_SIZE
		dot.color = DOT_INACTIVE
		page_dots.add_child(dot)


func _on_page_started(page_index: int) -> void:
	var total := animator.total_pages()
	if page_dots.get_child_count() != total:
		_build_page_dots(total)
	for i in page_dots.get_child_count():
		var dot: ColorRect = page_dots.get_child(i)
		dot.color = DOT_ACTIVE if i == page_index else DOT_INACTIVE
	prev_button.disabled = (page_index <= 0)
	next_button.disabled = (page_index >= total - 1)


func _on_script_finished() -> void:
	next_button.disabled = true


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _on_prev_pressed() -> void:
	animator.previous_page()


func _on_next_pressed() -> void:
	animator.next_page()
