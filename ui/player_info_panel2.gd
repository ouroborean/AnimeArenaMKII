extends PanelContainer
class_name PlayerInfoPanel2

var _player
@export var avatar_texture: TextureRect
@export var name_label: RichTextLabel
@export var rank_label: Label
@export var clan_label: Label
@export var level_label: Label
@export var ladder_label: Label
@export var ratio_label: Label
@export var avatar_upload_pane: PanelContainer
@export var ap_label: Label
var team = {}

signal team_button_clicked(character)
signal avatar_request()


var sounds = {
	"click": load("res://assets/sounds/ability_click.mp3"),
	"hover": load("res://assets/sounds/soft_click.mp3"),
}

func play_sound(sound_name):
	$Sound.stop()
	$Sound.stream = sounds[sound_name]
	$Sound.play()

static func from_player(player):
	var panel = load("res://ui/player_info_panel2.tscn").instantiate()
	panel.assign_player(player)
	
	return panel

func update_player(player):
	assign_player(player)

func assign_player(player):
	
	_player = player
	ap_label.text = str(int(player.ap))
	name_label.text = player._name.show()
	rank_label.text = "Rating: " + str(int(player.rank.get_rating()))
	if player.clan is String:
		clan_label.text = "Clan: " + player.clan
	else:
		clan_label.text = "Clan: " + player.clan.clan_name
	if not player.title == "":
		ladder_label.text = player.title
	var ranked_streak_string = "Ranked Streak: "
	if player.rank._ranked_streak >= 0:
		ranked_streak_string += "+" + str(int(player.rank._ranked_streak))
	else:
		ranked_streak_string += str(int(player.rank._ranked_streak))
	level_label.text = ranked_streak_string
	var personal_streak_string = "Personal Streak: "
	if player.rank.streak >= 0:
		personal_streak_string = personal_streak_string + "+" + str(int(player.rank.streak))
	else:
		personal_streak_string = personal_streak_string + str(int(player.rank.streak))
	var ratio_string = "Ratio: " + str(player.rank.wins) + " - " + str(int(player.rank.losses))
	if player.rank.streak >= 0:
		ratio_string += " (+" + str(int(player.rank.streak)) + ")"
	else:
		ratio_string += " (" + str(int(player.rank.streak)) + ")"

	ratio_label.text = ratio_string
	avatar_texture.texture = player.avatar_texture

func update_team():
	
	for character_button in $PanelMargin/Rows/PlayerTeamMargin/HBoxContainer.get_children():
		character_button.queue_free()
	
	
	for character in _player.team.characters:
		var button = CharacterButton.from_character(character)
		button.button_clicked.connect(team_character_clicked)
		button.custom_minimum_size = Vector2(50, 50)
		$PanelMargin/Rows/PlayerTeamMargin/HBoxContainer.add_child(button)
	
func team_character_clicked(character, _locked):
	team_button_clicked.emit(character)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func avatar_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		avatar_upload_pane.visible = true
		
func avatar_accept_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		avatar_upload_pane.visible = false
		_player.avatar_url = $AvatarUploadPane/MarginContainer/VBoxContainer/LineEdit.text
		avatar_request.emit()

func avatar_cancel_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		play_sound("click")
		avatar_upload_pane.visible = false


func _on_player_avatar_mouse_entered():
	$PanelMargin/Rows/PlayerDisplayRow/VBoxContainer/PlayerAvatarMargin/PlayerAvatar.modulate = Color.DARK_RED
	play_sound("hover")

func _on_player_avatar_mouse_exited():
	$PanelMargin/Rows/PlayerDisplayRow/VBoxContainer/PlayerAvatarMargin/PlayerAvatar.modulate = Color.WHITE


func _on_panel_container_mouse_entered():
	$AvatarUploadPane/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer.modulate = Color.hex(0xffffff88)
	play_sound("hover")


func _on_panel_container_mouse_exited():
	$AvatarUploadPane/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer.modulate = Color.WHITE

func _on_panel_container_2_mouse_entered():
	$AvatarUploadPane/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2.modulate = Color.hex(0xffffff88)
	play_sound("hover")
	
func _on_panel_container_2_mouse_exited():
	$AvatarUploadPane/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2.modulate = Color.WHITE
