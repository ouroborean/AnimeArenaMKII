extends PanelContainer

var player_name = ""

signal send_demotion(player_name)
signal send_promotion(player_name)
signal send_kick(player_name)
signal send_leave(player_name)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func ingest_details(player_details, member_level, viewer_name, viewer_level):
	player_name = player_details["username"]
	$MarginContainer/HBoxContainer/Label.text = player_name
	$MarginContainer/HBoxContainer/Label2.text = "(W:" + str(player_details["wins"]) +"/L:" + str(player_details["losses"]) + ")"
	if player_name == viewer_name and member_level != 0:
		$MarginContainer/HBoxContainer/PanelContainer4.show()
	if player_name != viewer_name and member_level > viewer_level:
		$MarginContainer/HBoxContainer/PanelContainer3.show()
	if member_level > viewer_level and member_level == 2:
		$MarginContainer/HBoxContainer/PanelContainer2.show()
	if viewer_level == 0 and member_level != 0 and member_level != 2:
		$MarginContainer/HBoxContainer/PanelContainer.show()
	
	var url = player_details["avatar_url"]
	if url == "":
		$MarginContainer/HBoxContainer/TextureRect.texture = load("res://assets/avatars/toko_toda.png")
		return
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", banner_fetch_completed)
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


func demote_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		send_demotion.emit(player_name)


func promote_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		send_promotion.emit(player_name)


func kick_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		send_kick.emit(player_name)


func leave_click(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		send_leave.emit(player_name)


func demote_hover():
	$MarginContainer/HBoxContainer/PanelContainer.modulate = Color.hex(0xffffff80)


func promote_hover():
	$MarginContainer/HBoxContainer/PanelContainer2.modulate = Color.hex(0xffffff80)


func kick_hover():
	$MarginContainer/HBoxContainer/PanelContainer3.modulate = Color.hex(0xffffff80)


func leave_hover():
	$MarginContainer/HBoxContainer/PanelContainer4.modulate = Color.hex(0xffffff80)


func demote_hover_stop():
	$MarginContainer/HBoxContainer/PanelContainer.modulate = Color.WHITE


func promote_hover_stop():
	$MarginContainer/HBoxContainer/PanelContainer2.modulate = Color.WHITE


func kick_hover_stop():
	$MarginContainer/HBoxContainer/PanelContainer3.modulate = Color.WHITE


func leave_hover_stop():
	$MarginContainer/HBoxContainer/PanelContainer4.modulate = Color.WHITE
