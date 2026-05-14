extends HBoxContainer
class_name MainActionContainer

var _character: Character

func get_main_actions_from_character(character):
	var abilities = character.moveset.abilities
	print("Populating main action container. Character skin state: " + str(character.mastery_skin_on))
	for ability in character.moveset.get_active_abilities(character):
		add_action(ability, character)

func set_character(character):
	dump_buttons()
	_character = character
	
	
func add_action(action, character):
	var action_button = ActionButton.from_action(action)
	action_button.ability_clicked.connect(character.ability_clicked)
	add_child(action_button)

func dump_buttons():
	for node in get_children():
		node.queue_free()

func update(entity):
	
	var abilities = entity.moveset.get_active_abilities(entity)
	var buttons = get_children()
	
	for i in range(4):
		buttons[i].update(entity, abilities[i])

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
