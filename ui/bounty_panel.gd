extends HBoxContainer

@export var bounty_selection_panel: MarginContainer
@export var bounty_info_panel: MarginContainer
@export var with_info: Label
@export var against_info: Label
@export var with_grid: GridContainer
@export var against_grid: GridContainer

@export var accept_button: PanelContainer
@export var cancel_button: PanelContainer
@export var reroll_button: PanelContainer
@export var complete_button: PanelContainer

@export var unlock_tab: PanelContainer
@export var mastery_tab: PanelContainer
@export var unlock_scroll: ScrollContainer
@export var mastery_scroll: ScrollContainer
@export var unlock_list: VBoxContainer
@export var mastery_list: VBoxContainer
@export var reward_label: Label

const TAB_UNSELECTED_ALPHA = 0.4
const TAB_HOVER_ALPHA = 0.7


signal close_panel()

var rap_sheet
var bounty_grid
var selected_mission
var valid_archetypes = []
var player: Player
var mission_types = [
	"with",
	"against",
	"versus"
]

var selected_bounty
var selected_bounty_path

var button_animating = false

var current_bounty_type = "unlock"



# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	rap_sheet = $BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2
	bounty_grid = $BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/GridContainer
	selected_mission = $BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2
	# Help-system tagging: the whole bounty panel should map to a single help
	# series regardless of internal state (no selection vs unlock selected vs
	# mastery selected). Marking BountyPanel as help_opaque stops the walker
	# from descending into it, so the fingerprint sees only "bounty_panel".
	$BountyPanel.set_meta("help_opaque", true)
	$MarginContainer/TextureButton.mouse_entered.connect(func ():
		$MarginContainer/TextureButton.modulate = Color(1.0, 1.0, 1.0, 0.502)
	)
	$MarginContainer/TextureButton.mouse_exited.connect(func ():
		$MarginContainer/TextureButton.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	$MarginContainer/TextureButton.pressed.connect(func ():
		close_panel.emit()
	)
	accept_button.mouse_entered.connect(func ():
		accept_button.modulate = Color(1.0, 1.0, 1.0, 0.471)
	)
	cancel_button.mouse_entered.connect(func ():
		cancel_button.modulate = Color(1.0, 1.0, 1.0, 0.471)
	)
	reroll_button.mouse_entered.connect(func ():
		reroll_button.modulate = Color(1.0, 1.0, 1.0, 0.471)
	)
	complete_button.mouse_entered.connect(func ():
		complete_button.modulate = Color(1.0, 1.0, 1.0, 0.471)
	)
	accept_button.mouse_exited.connect(func ():
		accept_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	cancel_button.mouse_exited.connect(func ():
		cancel_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	reroll_button.mouse_exited.connect(func ():
		reroll_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	complete_button.mouse_exited.connect(func ():
		complete_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	accept_button.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			accept_clicked()
	)
	cancel_button.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			cancel_clicked()
	)
	reroll_button.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			reroll_clicked()
	)
	complete_button.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			complete_clicked()
	)
	unlock_tab.mouse_entered.connect(func ():
		if current_bounty_type != "unlock":
			unlock_tab.modulate = Color(1.0, 1.0, 1.0, TAB_HOVER_ALPHA)
	)
	unlock_tab.mouse_exited.connect(func ():
		if current_bounty_type != "unlock":
			unlock_tab.modulate = Color(1.0, 1.0, 1.0, TAB_UNSELECTED_ALPHA)
	)
	unlock_tab.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			select_bounty_type("unlock")
	)
	mastery_tab.mouse_entered.connect(func ():
		if current_bounty_type != "mastery":
			mastery_tab.modulate = Color(1.0, 1.0, 1.0, TAB_HOVER_ALPHA)
	)
	mastery_tab.mouse_exited.connect(func ():
		if current_bounty_type != "mastery":
			mastery_tab.modulate = Color(1.0, 1.0, 1.0, TAB_UNSELECTED_ALPHA)
	)
	mastery_tab.gui_input.connect(func (event):
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			select_bounty_type("mastery")
	)


func accept_clicked():
	if not button_animating:
		button_animating = true
		var tween = create_tween()
		tween.tween_property(accept_button, "position", Vector2(accept_button.position.x, accept_button.position.y + 4), 0.05)
		tween.tween_property(accept_button, "position", Vector2(accept_button.position.x, accept_button.position.y), 0.05)
		tween.tween_callback(func (): button_animating = false)
	#TODO: update server state
	player.active_bounties[selected_bounty_path] = [
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0
	]
	get_parent().get_parent().save_cosmetic_changes.emit(player)
	authenticate_buttonstate()
	update_active_bounties()
	

func cancel_clicked():
	if not button_animating:
		button_animating = true
		var tween = create_tween()
		tween.tween_property(cancel_button, "position", Vector2(cancel_button.position.x, cancel_button.position.y + 4), 0.05)
		tween.tween_property(cancel_button, "position", Vector2(cancel_button.position.x, cancel_button.position.y), 0.05)
		tween.tween_callback(func (): button_animating = false)
	get_parent().get_parent().save_cosmetic_changes.emit(player)
	player.active_bounties.erase(selected_bounty_path)
	authenticate_buttonstate()
	update_active_bounties()
	

func reroll_clicked():
	if not button_animating:
		button_animating = true
		var tween = create_tween()
		tween.tween_property(reroll_button, "position", Vector2(reroll_button.position.x, reroll_button.position.y + 4), 0.05)
		tween.tween_property(reroll_button, "position", Vector2(reroll_button.position.x, reroll_button.position.y), 0.05)
		tween.tween_callback(func (): button_animating = false)
	
	if selected_bounty_path in player.bounty_rerolls:
		player.bounty_rerolls[selected_bounty_path] += 1
	else:
		player.bounty_rerolls[selected_bounty_path] = 1
	player.ap -= 1500
	player.active_bounties[selected_bounty_path] = [
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
	]
	get_parent().get_parent().save_cosmetic_changes.emit(player)
	on_list_clicked(selected_bounty_path)
	authenticate_buttonstate()

func complete_clicked():
	if not button_animating:
		button_animating = true
		var tween = create_tween()
		tween.tween_property(complete_button, "position", Vector2(complete_button.position.x, complete_button.position.y + 4), 0.05)
		tween.tween_property(complete_button, "position", Vector2(complete_button.position.x, complete_button.position.y), 0.05)
		tween.tween_callback(func (): button_animating = false)
	if selected_bounty and selected_bounty.requires_bounty_target:
		player.ap += 5000
		player.character_progress.award_xp(selected_bounty.bounty_target_path, 1000)
	else:
		player.unlocks.append(selected_bounty_path + "_unlock")
	player.active_bounties.erase(selected_bounty_path)
	player.bounty_rerolls.erase(selected_bounty_path)
	get_parent().get_parent().save_cosmetic_changes.emit(player)
	authenticate_buttonstate()
	update_character_list()
	update_active_bounties()


func authenticate_buttonstate():
	if len(player.active_bounties.keys()) >= 5 or selected_bounty_path in player.active_bounties or not selected_bounty_path:
		accept_button.hide()
	else:
		accept_button.show()
	if not (selected_bounty_path in player.active_bounties):
		cancel_button.hide()
	else:
		cancel_button.show()
	if player.ap < 1500 or not (selected_bounty_path in player.active_bounties):
		reroll_button.hide()
	else:
		reroll_button.show()
	if not bounty_completed():
		complete_button.hide()
	else:
		complete_button.show()


func bounty_completed():
	if not selected_bounty:
		return false
	if not selected_bounty_path in player.active_bounties:
		return false
	return selected_bounty.bounty_completed(player.active_bounties[selected_bounty_path])

func assign_player(_player):
	player = _player
	update_character_list()
	update_active_bounties()
	authenticate_buttonstate()

func update_character_list():
	var character_list = CharacterDatabase.char_name_list()
	var starters = CharacterDatabase.starter_squads()
	_populate_bounty_list(unlock_list, character_list, _is_unlock_bounty_target.bind(starters))
	_populate_bounty_list(mastery_list, character_list, _is_mastery_bounty_target.bind(starters))


func _populate_bounty_list(list_container: VBoxContainer, character_list, include_predicate: Callable):
	for child in list_container.get_children():
		if child is Label:
			continue
		child.queue_free()
	var is_mastery_list = list_container == mastery_list
	for character_name in character_list:
		if include_predicate.call(character_name):
			var character_instance = Character.from_character_name(character_name)
			var item = BountyListItem.from_character(character_instance)
			if is_mastery_list:
				item.character_clicked.connect(func (path): on_list_clicked(path + Bounty.MASTERY_SUFFIX))
			else:
				item.character_clicked.connect(on_list_clicked)
			list_container.add_child(item)


func _is_unlock_bounty_target(character_name, starters) -> bool:
	return not (character_name in starters) and not (character_name + "_unlock" in player.unlocks) and not ("all_unlock" in player.unlocks)


func _is_mastery_bounty_target(character_name, starters) -> bool:
	return character_name in starters or (character_name + "_unlock" in player.unlocks or "all_unlock" in player.unlocks)


func select_bounty_type(bounty_type):
	current_bounty_type = bounty_type
	var unlock_selected = bounty_type == "unlock"
	unlock_scroll.visible = unlock_selected
	mastery_scroll.visible = not unlock_selected
	unlock_tab.modulate = Color(1.0, 1.0, 1.0, 1.0 if unlock_selected else TAB_UNSELECTED_ALPHA)
	mastery_tab.modulate = Color(1.0, 1.0, 1.0, TAB_UNSELECTED_ALPHA if unlock_selected else 1.0)
	

func update_active_bounties():
	for child in $BountyPanel/MarginContainer/VBoxContainer/MarginContainer/ActiveBountyContainer/MarginContainer/VBoxContainer/HBoxContainer.get_children():
		child.queue_free()
	for path_name in player.active_bounties:
		var active_bounty_button = ActiveBountyButton.from_details(path_name)
		active_bounty_button.active_bounty_clicked.connect(on_list_clicked)
		$BountyPanel/MarginContainer/VBoxContainer/MarginContainer/ActiveBountyContainer/MarginContainer/VBoxContainer/HBoxContainer.add_child(active_bounty_button)
	

func on_list_clicked(character_path):
	var bounty_type = "unlock"
	var raw_path = character_path
	if character_path.ends_with(Bounty.MASTERY_SUFFIX):
		bounty_type = "mastery"
		raw_path = character_path.trim_suffix(Bounty.MASTERY_SUFFIX)
	selected_bounty_path = character_path
	var character_instance = Character.from_character_name(raw_path)
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/TextureRect.texture = character_instance.portrait_texture
	bounty_info_panel.visible = true
	bounty_selection_panel.visible = false
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/Label.text = character_instance.character_name
	print("Fetching bounty with hash " + player.username + raw_path + str(player.get_bounty_rerolls(selected_bounty_path)) + " (" + bounty_type + ")")
	var bounty = Bounty.get_bounty(player.username, raw_path, player.get_bounty_rerolls(selected_bounty_path), bounty_type)
	selected_bounty = bounty
	load_bounty_grid(bounty)
	for child in $BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/GridContainer.get_children():
		child.queue_free()
	for archetype in Bounty.flat_bounty_categories(raw_path):
		var rect = TextureRect.new()
		rect.texture = load("res://assets/bounty/" + archetype + ".png")
		rect.tooltip_text = archetype.capitalize()
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(50, 50)
		$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/GridContainer.add_child(rect)
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/MarginContainer/ScrollContainer/VBoxContainer.hide()
	if bounty_type == "mastery":
		reward_label.text = "\nComplete any row, column, or diagonal to earn 5000 AP and 1000 Character Mastery XP for " + character_instance.character_name + "!"
	else:
		reward_label.text = "\nComplete any row, column, or diagonal to unlock the bounty target!"
	authenticate_buttonstate()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func load_bounty_grid(bounty):
	for child in bounty_grid.get_children():
		child.queue_free()
	var bounty_target_name = ""
	if bounty.requires_bounty_target:
		bounty_target_name = Character.from_character_name(bounty.bounty_target_path).character_name
	var i = 0
	for mission in bounty.missions:
		var count = 0
		if bounty.bounty_path in player.active_bounties:
			count = int(player.active_bounties[bounty.bounty_path][i])
		var bounty_card = load("res://ui/bounty_card.tscn").instantiate()
		var mission_type = mission[0]
		var mission_count = mission[2]
		if mission_type == "with":
			var mission_target = mission[1][0]
			var mission_details = bounty.get_mission_details(mission_target)
			bounty_card.with_panel.visible = true
			bounty_card.with_only.visible = true
			bounty_card.with_only.texture = mission_details.portrait
			if bounty.requires_bounty_target:
				bounty_card.mission_label.text = "With " + bounty_target_name + " and " + mission_details.name
			else:
				bounty_card.mission_label.text = "With " + mission_details.name
		elif mission_type == "against":
			var mission_target = mission[1][0]
			var mission_details = bounty.get_mission_details(mission_target)
			bounty_card.against_panel.visible = true
			bounty_card.against_only.visible = true
			bounty_card.against_only.texture = mission_details.portrait
			if bounty.requires_bounty_target:
				bounty_card.mission_label.text = "With " + bounty_target_name + " against " + mission_details.name
			else:
				bounty_card.mission_label.text = "Against " + mission_details.name
		elif mission_type == "versus":
			var with_target = mission[1][0]
			var with_mission_details = bounty.get_mission_details(with_target)
			var against_target = mission[1][1]
			var against_mission_details = bounty.get_mission_details(against_target)
			bounty_card.versus_panel.visible = true
			bounty_card.versus_against.visible = true
			bounty_card.versus_with.visible = true
			bounty_card.versus_against.texture = against_mission_details.portrait
			bounty_card.versus_with.texture = with_mission_details.portrait
			if bounty.requires_bounty_target:
				bounty_card.mission_label.text = "With " + bounty_target_name + " and " + with_mission_details.name + " Against " + against_mission_details.name
			else:
				bounty_card.mission_label.text = "With " + with_mission_details.name + " Against " + against_mission_details.name
		bounty_card.count_label.text = str(count) + "/" + str(mission_count)
		if int(count) >= int(mission_count):
			bounty_card.complete_panel.visible = true
		bounty_card.mission_details = mission
		bounty_card.bounty_mission_clicked.connect(mission_clicked)
		bounty_grid.add_child(bounty_card)
		i += 1

func mission_clicked(details):
	for child in against_grid.get_children():
		child.queue_free()
	for child in with_grid.get_children():
		child.queue_free()
	print("Clicked mission: ", details)
	against_info.text = ""
	with_info.text = ""
	
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/MarginContainer/Label.visible = false
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/MarginContainer/ScrollContainer/VBoxContainer.show()
	var mission_type = details[0]
	var mission_count = details[2]
	var mission_targets = details[1]
	var is_mastery = selected_bounty and selected_bounty.requires_bounty_target
	var bounty_target_name = ""
	if is_mastery:
		bounty_target_name = Character.from_character_name(selected_bounty.bounty_target_path).character_name
	if mission_type == "with":
		against_info.text = "against any characters"
		if is_mastery:
			with_info.text = "Win " + str(mission_count) + " battles with " + bounty_target_name + " AND: "
		else:
			with_info.text = "Win " + str(mission_count) + " battles with: "
		if mission_targets[0] in selected_bounty.archetypes:
			for path_name in selected_bounty.categories[mission_targets[0]]:
				if is_mastery and path_name == selected_bounty.bounty_target_path:
					continue
				var character_instance = Character.from_character_name(path_name)
				var rect = TextureRect.new()
				rect.texture = character_instance.portrait_texture
				rect.tooltip_text = character_instance.character_name
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.custom_minimum_size = Vector2(28, 28)
				with_grid.add_child(rect)
		else:
			var character_instance = Character.from_character_name(mission_targets[0])
			var rect = TextureRect.new()
			rect.texture = character_instance.portrait_texture
			rect.tooltip_text = character_instance.character_name
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.custom_minimum_size = Vector2(50, 50)
			with_grid.add_child(rect)
	elif mission_type == "against":
		if is_mastery:
			with_info.text = "Win " + str(mission_count) + " battles with " + bounty_target_name
		else:
			with_info.text = "Win " + str(mission_count) + " battles"
		against_info.text = "against: "
		if mission_targets[0] in selected_bounty.archetypes:
			for path_name in selected_bounty.categories[mission_targets[0]]:
				var character_instance = Character.from_character_name(path_name)
				var rect = TextureRect.new()
				rect.texture = character_instance.portrait_texture
				rect.tooltip_text = character_instance.character_name
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.custom_minimum_size = Vector2(28, 28)
				against_grid.add_child(rect)
		else:
			var character_instance = Character.from_character_name(mission_targets[0])
			var rect = TextureRect.new()
			rect.texture = character_instance.portrait_texture
			rect.tooltip_text = character_instance.character_name
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.custom_minimum_size = Vector2(50, 50)
			against_grid.add_child(rect)
	else:
		if is_mastery:
			with_info.text = "Win " + str(mission_count) + " battles with " + bounty_target_name + " AND: "
		else:
			with_info.text = "Win " + str(mission_count) + " battles with: "
		against_info.text = "against: "
		print("Printing mission details for versus mission with targets: ", mission_targets)
		var with_target = mission_targets[0]
		var against_target = mission_targets[1]
		if with_target in selected_bounty.archetypes:
			for path_name in selected_bounty.categories[with_target]:
				if is_mastery and path_name == selected_bounty.bounty_target_path:
					continue
				var character_instance = Character.from_character_name(path_name)
				var rect = TextureRect.new()
				rect.texture = character_instance.portrait_texture
				rect.tooltip_text = character_instance.character_name
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.custom_minimum_size = Vector2(28, 28)
				with_grid.add_child(rect)
		else:
			var character_instance = Character.from_character_name(with_target)
			var rect = TextureRect.new()
			rect.texture = character_instance.portrait_texture
			rect.tooltip_text = character_instance.character_name
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.custom_minimum_size = Vector2(50, 50)
			with_grid.add_child(rect)
		if against_target in selected_bounty.archetypes:
			for path_name in selected_bounty.categories[against_target]:
				var character_instance = Character.from_character_name(path_name)
				var rect = TextureRect.new()
				rect.texture = character_instance.portrait_texture
				rect.tooltip_text = character_instance.character_name
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.custom_minimum_size = Vector2(28, 28)
				against_grid.add_child(rect)
		else:
			var character_instance = Character.from_character_name(against_target)
			var rect = TextureRect.new()
			rect.texture = character_instance.portrait_texture
			rect.tooltip_text = character_instance.character_name
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.custom_minimum_size = Vector2(50, 50)
			against_grid.add_child(rect)
	


func _back_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		bounty_info_panel.visible = false
		bounty_selection_panel.visible = true
		$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/MarginContainer/ScrollContainer/VBoxContainer.visible = false
		$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/MarginContainer/Label.visible = true

func _back_hovered():
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/PanelContainer.modulate = Color(1.0, 1.0, 1.0, 0.482)


func _back_hover_stopped():
	$BountyPanel/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SelectedInfoMargin/VBoxContainer/PanelContainer.modulate = Color(1.0, 1.0, 1.0, 1.0)
