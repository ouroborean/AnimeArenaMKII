extends PanelContainer


signal send_clan_invitation(player_name)

var player_name

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_details(player_details):
	player_name = player_details["username"]
	$MarginContainer/HBoxContainer/Label.text = player_name
	$MarginContainer/HBoxContainer/Label2.text = "(W:" + str(player_details["wins"]) +"/L:" + str(player_details["losses"]) + ")"
	var url = player_details["avatar_url"]
	if url == "":
		$MarginContainer/HBoxContainer/TextureRect.texture = load("res://assets/avatars/toko_toda.png")
		return
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", banner_fetch_completed)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)

func banner_fetch_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		$MarginContainer/HBoxContainer/TextureRect.texture = texture

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func apply_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		send_clan_invitation.emit(player_name)


func apply_hover():
	$MarginContainer/HBoxContainer/PanelContainer.modulate = Color.hex(0xffffff80)


func apply_hover_stopped():
	$MarginContainer/HBoxContainer/PanelContainer.modulate = Color.WHITE
