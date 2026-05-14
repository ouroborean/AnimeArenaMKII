extends Control

var with_target = ""
var against_target = ""
var background_path = ""
var progress = 0
var goal = 0
var track = false
var complete = false
@export var with_only : Control
@export var against_only : Control
@export var versus_with : Control
@export var versus_against : Control
@export var with_panel : Control
@export var against_panel : Control
@export var versus_panel : Control
@export var count_label: Label
@export var mission_label: Label
@export var complete_panel: Control

signal bounty_mission_clicked(details)

var mission_details

var archetypes = ["sword", "air", "water", "earth", "ice", "fire", "lightning", "undead", "ninja", "hero", "fairy tail", "vongola", "leader", "brawler", "servant", "team 7", "shinigami", "straw hat", "esper", "magical girl", "night raid", "sins", "villain", "black bulls", "digimon", "assassin", "non human", "mage"]
var categories = {
	"sword": ["zoro", "meliodas", "erza", "sayaka", "asta", "blackstar", "tatsumi", "akame", "tanjiro", "zenitsu", "inosuke", "rengoku", "muichiro", "yamamoto", "squalo", "eren", "mikasa", "kurapika", "emiya", "saber", "emiyaarcher", "ryuko", "satsuki", "ichigo", "byakuya", "nimaiya", "omnimon"],
	"air": ["naruto", "yuno", "aang", "korra", "hawkmon", "nonon"],
	"water": ["lucy", "hashirama", "noelle", "aang", "korra", "tanjiro", "muichiro", "yamamoto", "squalo"],
	"earth": ["diane", "hashirama", "aang", "toph", "korra", "alphonse"],
	"ice": ["gray"],
	"fire": ["sasuke", "bakugou", "natsu", "meliodas", "frieren", "ace", "sukuna", "aang", "korra", "rengoku", "tsuna", "genos", "shinra", "tamaki", "mars", "megumin"],
	"lightning": ["sasuke", "zenitsu", "genos", "killua", "misaka", "frankenstein", "jupiter"],
	"undead": ["jack", "ken", "touka", "myotismon", "hashirama", "ban", "arima"],
	"ninja": ["naruto", "sasuke", "sakura", "hinata", "hashirama", "tsubaki"],
	"hero": ["midoriya", "uraraka", "bakugo", "saitama", "genos", "tatsumaki", "gilgamesh", "gallantmon", "omnimon"],
	"fairy tail": ["natsu", "lucy", "gray", "erza"],
	"vongola": ["tsuna", "yamamoto", "ryohei", "xanxus", "squalo"],
	"leader": ["luffy", "meliodas", "hashirama", "rob", "tsuna", "xanxus", "rimuru"],
	"brawler": ["luffy", "yuji", "midoriya", "bakugo", "goku", "vegeta", "natsu", "rob", "ryohei", "saitama", "genos", "shinra", "sogiita", "gogeta"],
	"servant": ["saber", "gilgamesh", "emiyaarcher", "jack", "semiramis", "frankenstein", "mash"],
	"team 7": ["naruto", "sasuke", "sakura"],
	"shinigami": ["ichigo", "byakuya", "nimaiya"],
	"straw hat": ["luffy", "zoro", "usopp"],
	"esper": ["tatsumaki", "misaka", "kuroko", "sogiita", "shokuho"],
	"magical girl": ["madoka", "sayaka", "mami", "mars", "jupiter"],
	"night raid": ["tatsumi", "akame", "sheele"],
	"sins": ["meliodas", "king", "diane", "ban"],
	"villain": ["sasuke", "gilgamesh", "ken", "vegeta", "machinedramon", "xanxus", "toga", "sukuna", "rob", "myotismon"],
	"black bulls": ["asta", "noelle"],
	"digimon": ["gatomon", "ominmon", "myotismon", "machinedramon", "gallantmon", "renamon", "hawkmon"],
	"assassin": ["rob", "blackstar", "tatsumi", "sheele", "akame", "killua", "jack", "semiramis", "nagisa", "tsubaki"],
	"non human" : ["koro", "diane", "king", "meliodas", "eren", "gatomon", "omnimon", "myotismon", "machinedramon", "omnimon", "gallantmon", "renamon", "hawkmon", "sukuna"],
	"mage" : ["asta", "noelle", "yuno", "natsu", "gray", "lucy", "semiramis", "megumin", "frieren"],
}

func handle_click_logic():
	bounty_mission_clicked.emit(mission_details)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	with_panel.mouse_entered.connect(_on_mouse_entered)
	against_panel.mouse_entered.connect(_on_mouse_entered)
	versus_panel.mouse_entered.connect(_on_mouse_entered)

	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mouse_entered() -> void:
	$PanelContainer.visible = true

func _on_mouse_exited() -> void:
	$PanelContainer.visible = false

func _on_with_panel_gui_input(event: InputEvent) -> void:
	# Check if the event is a mouse button click
	if event is InputEventMouseButton:
		# Check if it was the left mouse button and specifically the "down" press
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_click_logic()
	elif event is InputEventMouseMotion:
		$PanelContainer.visible = true


func _on_panel_2_gui_input(event: InputEvent) -> void:
	# Check if the event is a mouse button click
	if event is InputEventMouseButton:
		# Check if it was the left mouse button and specifically the "down" press
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_click_logic()


func _on_panel_3_gui_input(event: InputEvent) -> void:
	# Check if the event is a mouse button click
	if event is InputEventMouseButton:
		# Check if it was the left mouse button and specifically the "down" press
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_click_logic()
