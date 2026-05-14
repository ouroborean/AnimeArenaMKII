extends MarginContainer
class_name MasteryProgressBar


static func from_character_progress(fraction: float, current_xp: int, next_level_xp: int, level: int):
	var bar = load("res://ui/mastery_progress_bar.tscn").instantiate()
	bar.set_progress(fraction, current_xp, next_level_xp, level)
	return bar


func _ready():
	pass


func set_progress(fraction: float, current_xp: int, next_level_xp: int, level: int):
	$PanelContainer/TextureProgressBar.value = clampf(fraction * 100.0, 0.0, 100.0)
	if level >= MasteryConfig.MAX_LEVEL:
		$XPLabel.text = str(current_xp) + " XP (MAX)"
	else:
		var floor_xp = MasteryConfig.xp_at_current_level(current_xp)
		$XPLabel.text = str(current_xp - floor_xp) + " / " + str(next_level_xp - floor_xp) + " XP"


func _process(delta):
	pass
