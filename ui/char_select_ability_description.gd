extends PanelContainer
class_name CharSelectAbilityDescription

static func from_description(user, ability, force=false):
	var panel = load("res://ui/char_select_ability_description.tscn").instantiate()
	panel.add_cost_symbols(ability.cost())
	panel.add_ability_name(ability.return_name_with_mastery(user, force))
	panel.add_ability_desc(ability, force)
	panel.add_ability_cooldown(ability.cooldown)
	panel.add_ability_classes(ability.classes)
	panel.add_ability_image(ability, force)
	return panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func add_ability_image(ability, force):
	$MarginContainer/HBoxContainer/MarginContainer/ActionButton.set_action(ability, force)

func add_ability_cooldown(ability_cooldown):
	$MarginContainer/HBoxContainer/MarginContainer2/Rows/HBoxContainer/AbilityCooldownLabel.text = "Cooldown: " + str(ability_cooldown)

func add_ability_name(ability_name):
	$MarginContainer/HBoxContainer/MarginContainer2/Rows/HeaderRow/AbilityNameLabel.text = "  " + ability_name

func add_ability_desc(ability, force):
	if ability.split_desc() != []:
		$MarginContainer/HBoxContainer/MarginContainer2/Rows/ScrollContainer/MarginContainer/AbilityDescLabel.hide()
		$MarginContainer/HBoxContainer/MarginContainer2/Rows/ScrollContainer/MarginContainer/VBoxContainer.show()
		var first = true
		for string in ability.split_desc():
			var label = load("res://ui/ability_desc_label.tscn").instantiate()
			if first:
				first = false
				label.set_base_label(string)
			else:
				if string is String:
				
					label.set_sub_label(string)
				else:
					label.set_color_label(string[0], string[1])
			$MarginContainer/HBoxContainer/MarginContainer2/Rows/ScrollContainer/MarginContainer/VBoxContainer.add_child(label)
	else:
		$MarginContainer/HBoxContainer/MarginContainer2/Rows/ScrollContainer/MarginContainer/AbilityDescLabel.text = ability.return_description_with_mastery(ability.user, force)

func add_ability_classes(ability_classes):
	var abcs = []
	for key in ability_classes:
		if ability_classes[key]:
			abcs.append(key)
	
	
	var text = "Classes: "
	for abc in abcs:
		text += abc + ", "
	text = text.substr(0, len(text) - 2)
	$MarginContainer/HBoxContainer/MarginContainer2/Rows/HBoxContainer/AbilityClassLabel.text = text

func add_cost_symbols(cost):
	for element in cost:
		for i in range(cost[element]):
			var symbol = Energy.get_symbol(element)
			var symbol_rect = TextureRect.new()
			symbol_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			symbol_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			symbol_rect.custom_minimum_size = Vector2(12, 12)
			symbol_rect.texture = symbol
			
			$MarginContainer/HBoxContainer/MarginContainer2/Rows/HeaderRow/CostContainer.add_child(symbol_rect)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
