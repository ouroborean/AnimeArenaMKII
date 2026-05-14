extends RefCounted
class_name DescriptionScript

var entries: Array = []


func line(text: String, hold: float = -1.0) -> DescriptionScript:
	var entry := {"text": text, "color": null}
	if hold >= 0.0:
		entry["hold"] = hold
	entries.append(entry)
	return self


func colored(text: String, color: Color, hold: float = -1.0) -> DescriptionScript:
	var entry := {"text": text, "color": color}
	if hold >= 0.0:
		entry["hold"] = hold
	entries.append(entry)
	return self


func image(texture, size: Vector2 = Vector2(64, 64), hold: float = -1.0) -> DescriptionScript:
	var entry := {"type": "image", "texture": texture, "size": size}
	if hold >= 0.0:
		entry["hold"] = hold
	entries.append(entry)
	return self


func ability_segment(ability, show_icon: bool = true) -> DescriptionScript:
	if show_icon and ability.image != null:
		image(ability.image, Vector2(80, 80))
	line(ability.ability_name)
	line(DescriptionScript._format_cost(ability._cost))
	line("Cooldown: " + str(ability.cooldown))
	var split = ability.split_desc()
	if split != null and split.size() > 0:
		for entry in DescriptionScript.from_split_desc(split):
			entries.append(entry)
	elif ability.ability_description != "":
		line(ability.ability_description)
	return self


func pause(seconds: float) -> DescriptionScript:
	if entries.size() > 0:
		entries[entries.size() - 1]["hold"] = seconds
	return self


func page_break() -> DescriptionScript:
	entries.append({"type": "break"})
	return self


func build() -> Array:
	return entries.duplicate()


static func from_split_desc(split: Array) -> Array:
	var out: Array = []
	for item in split:
		if item is String:
			out.append({"text": item, "color": null})
		elif item is Array and item.size() >= 2:
			out.append({"text": item[0], "color": item[1]})
	return out


static func from_ability(ability, _user = null) -> Array:
	var script := DescriptionScript.new()
	script.ability_segment(ability)
	return script.build()


static func from_character(character) -> Array:
	var script := DescriptionScript.new()
	script.line(character.character_name)
	script.page_break()
	if "description" in character and character.description != "":
		script.line(character.description)
	return script.build()


static func _format_cost(cost_dict: Dictionary) -> String:
	var parts: Array = []
	for key in cost_dict:
		var amount: int = cost_dict[key]
		if amount > 0:
			parts.append(str(amount) + " " + str(key))
	if parts.is_empty():
		return "Cost: Free"
	var s := "Cost: "
	for i in parts.size():
		s += parts[i]
		if i < parts.size() - 1:
			s += ", "
	return s
