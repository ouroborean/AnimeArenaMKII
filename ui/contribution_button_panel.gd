extends HBoxContainer
class_name ContributionButtonPanel

signal contribute_amount(amount)
signal close_contribution_panel()

var current_contribution: int

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func assign_character(character_name, character_ap):
	current_contribution = 0
	$ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer2/TextEdit.text = ""
	$ContributionButtonPanel/MarginContainer/VBoxContainer/Label.text = character_name
	$ContributionButtonPanel/MarginContainer/VBoxContainer/Label2.text = "Current AP: " + str(int(character_ap))

func cancel_clicked():
	close_contribution_panel.emit()

func accept_clicked():
	if current_contribution != 0:
		contribute_amount.emit(current_contribution)
	cancel_clicked()

func text_changed():
	if int($ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer2/TextEdit.text) is int:
		current_contribution = int($ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer2/TextEdit.text)


func _on_accept_button_mouse_entered():
	$ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer/AcceptButton.modulate = Color.hex(0xdc0008ff)

func _on_decline_button_mouse_entered():
	$ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer/DeclineButton.modulate = Color.hex(0xdc0008ff)
	
func _on_accept_button_mouse_exited():
	$ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer/AcceptButton.modulate = Color.WHITE
	
func _on_decline_button_mouse_exited():
	$ContributionButtonPanel/MarginContainer/VBoxContainer/MarginContainer3/HBoxContainer/AcceptButton.modulate = Color.WHITE
