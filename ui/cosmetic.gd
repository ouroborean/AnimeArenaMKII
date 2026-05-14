class_name Cosmetic

var cosmetic_payload
var cosmetic_name
var cosmetic_type
var character_restrictions

enum Type {
	TRINKET,
	PANEL_THEME,
	BORDER,
	SKIN,
	TITLE,
	MEDAL
}

func _init(payload, nam, c_type, restrict):
	cosmetic_payload = payload
	cosmetic_name = nam
	cosmetic_type = c_type
	character_restrictions = restrict

#Bauble
#Portrait Frame (Character)
#Panel (Character)
#Alt Portrait
#Medal
#Portrait Frame (Player)
#Panel (Player)

static func get_cosmetics_from_mastery(char_name):
	pass


