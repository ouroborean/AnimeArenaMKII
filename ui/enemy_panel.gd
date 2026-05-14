extends PanelContainer
class_name EnemyPanel

var _player
var tex: PanelContainer
@export var name_label: Label
@export var clan_label: Label
@export var rank_label: Label
@export var title_label: Label
@export var label_container: MarginContainer
@export var avatar_container: MarginContainer
@export var win_label: Label
@export var avatar_rect: TextureRect
var panel_image_name = "playercard_color_default"
static func from_enemy(player, enemy=false):
	var panel = load("res://ui/enemy_panel.tscn").instantiate()
	panel.assign_player(player)
	if enemy:
		panel.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.clan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.shuffle_profile()
	return panel

var light_background_names = [
	"aang",
	"alphonse",
	"diane",
	"gilgamesh",
	"goku",
	"gon",
	"invincible",
	"killua",
	"king",
	"korra",
	"kuroko",
	"madoka",
	"mikasa",
	"misaka",
	"naruto",
	"nezuko",
	"nonon",
	"omniman",
	"saitama",
	"satsuki",
	"sayaka",
	"sheele",
	"shiro",
	"tatsumi",
	"uraraka",
	"usopp",
	"gatomon",
	"gallantmon"
]

var dark_clan_bar_names = [
	"darkblue",
	"darkpurple",
	"akame",
	"eren",
	"ganta",
	"goku",
	"gon",
	"killua",
	"maka",
	"meliodas",
	"mikasa",
	"misaka",
	"naruto",
	"ryuko",
	"sasuke",
	"satsuki",
	"tanjiro",
	"tatsumi",
	"gatomon",
]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func shuffle_profile():
	$HBoxContainer.remove_child(label_container)
	$HBoxContainer.add_child(label_container)

func set_playercard_image():
	panel_image_name = _player.equipped_player_card
	var panel = get("theme_override_styles/panel/texture")
	var color_check_name = panel_image_name.split("_")[2]
	if color_check_name in dark_clan_bar_names:
		$HBoxContainer/LabelContainer/VBoxContainer/PlayerClan.label_settings.font_color = Color.WHITE_SMOKE
	if color_check_name in light_background_names:
		$HBoxContainer/LabelContainer/VBoxContainer/PlayerName.label_settings.font_color = Color.hex(0x0e0e0eff)
		$HBoxContainer/LabelContainer/VBoxContainer/PlayerRank.label_settings.font_color = Color.hex(0x0e0e0eff)
		$HBoxContainer/LabelContainer/VBoxContainer/PlayerTitle.label_settings.font_color = Color.hex(0x0e0e0eff)
		$HBoxContainer/VBoxContainer/MarginContainer2/Label.label_settings.font_color = Color.hex(0x0e0e0eff)
	panel.texture = load("res://assets/cosmetics/playercards/" + panel_image_name + ".png")


func assign_player(player):
	_player = player
	set_playercard_image()
	name_label.text = player._name.show()
	clan_label.text = player.clan
	title_label.text = player.title
	rank_label.text = "Rating: " + str(player.rank.get_rating())
	win_label.text = str(int(player.rank.wins)) + " - " + str(int(player.rank.losses))
	avatar_rect.texture = _player.avatar_texture
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
