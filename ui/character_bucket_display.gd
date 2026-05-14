extends MarginContainer
class_name CharacterBucketDisplay


var _bucket
var displaying_contribution = false

signal bucket_clicked(bucket)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

static func from_character_bucket(bucket):
	var display = load("res://ui/character_bucket_display.tscn").instantiate()
	
	display.get_details_from_bucket(bucket)

	return display

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_details_from_bucket(bucket):
	_bucket = bucket
	$PanelContainer/VBoxContainer/APBarMargin/ProgressBar.max_value = bucket.maximum
	$PanelContainer/VBoxContainer/APBarMargin/ProgressBar.value = bucket.ap
	$PanelContainer/VBoxContainer/MarginContainer/Label.text = bucket.bucket_name()
	$PanelContainer/VBoxContainer/APBarMargin/ProgressBar/Label.text = str(int(bucket.ap))
	if bucket is CharacterBucket:
		get_details_from_concept(bucket.character_concept)
	elif bucket is UniverseBucket:
		get_details_from_universe(bucket.universe)

func get_details_from_universe(universe):
	#TODO get universe image
	$PanelContainer/VBoxContainer/CharacterProfileMargin/TextureRect.visible = true
	$PanelContainer/VBoxContainer/CharacterProfileMargin/CharacterButton.visible = false
	
func get_details_from_concept(concept):
	$PanelContainer/VBoxContainer/CharacterProfileMargin/CharacterButton.assign_character(concept, false)

func panel_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		bucket_clicked.emit(self)

func add_ap_to_bucket(amount, adder):
	_bucket.add_ap(amount, adder)
	get_details_from_bucket(_bucket)



func _on_panel_container_mouse_entered():
	var panel = $PanelContainer.get("theme_override_styles/panel/border_color")
	panel.border_color = Color.hex(0x008c95ff)
	

	


func _on_panel_container_mouse_exited():
	var panel = $PanelContainer.get("theme_override_styles/panel/border_color")
	panel.border_color = Color.hex(0x8e000cff)
	
