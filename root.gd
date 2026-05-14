extends Control

var game

# Called when the node enters the scene tree for the first time.
func _ready():
	if DisplayServer.get_name() == "headless":
		print("Starting in headless")
		var game = load("res://game.tscn").instantiate()
		add_child(game)
		game.server.actually_start_server()
	else:
		#if not "PASS" in OS.get_cmdline_args() and OS.get_name() != "macOS":
		#	get_tree().quit()
		instantiate_game()

func reload_game():
	print("Attempting reload")
	remove_child(game)
	game.queue_free()
	instantiate_game()

func instantiate_game():
	for i in range(5):
		for j in range(10):
			for k in range(20):
				if FileAccess.file_exists("res://patch" + str(i) + "." + str(j) + "." + str(k) + ".pck"):
					print("Loading existing update pack, ver. " + str(i) + "." + str(j) + "." + str(k))
					#ProjectSettings.load_resource_pack("res://patch" + str(i) + "." + str(j) + "." + str(k) + ".pck")
	game = load("res://game.tscn").instantiate()
	game.request_reload.connect(reload_game)
	add_child(game)
	game.focus_username()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
