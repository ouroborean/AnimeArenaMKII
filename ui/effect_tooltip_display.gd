extends GridContainer
class_name EffectTooltipDisplay
var _character
var info_panel: EffectTooltipHoverPanel
var _previous_cluster_keys: Array = []
var _update_pending: bool = false

func effects_changed():
	pass

func set_enemy():
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	anchors_preset = PRESET_CENTER_LEFT
	columns = 5

func sync_effects(character):
	if character.enemy:
		set_enemy()

	_character = character
	character.effects.effects_changed.connect(update)

func update():
	# Coalesce multiple update() calls in the same frame into one rebuild.
	# effects_changed and Character.update often fire back-to-back; without
	# this, the second call would dump the animating tooltips and recreate
	# them without entrance animations.
	if not _update_pending:
		_update_pending = true
		call_deferred("_do_update")

func _do_update():
	_update_pending = false
	var clusters = _character.effects.get_effect_clusters(_character.effects.get_renderable_effects())
	var new_keys = clusters.keys()
	var added_keys = []
	for key in new_keys:
		if not key in _previous_cluster_keys:
			added_keys.append(key)
	_previous_cluster_keys = new_keys.duplicate()
	get_effect_tooltips(clusters, added_keys)

func get_effect_tooltips(clusters, added_keys = []):
	dump_tooltips()
	for cluster in clusters:
		var tooltip = EffectTooltip.from_effect_cluster(clusters[cluster])
		tooltip.show_panel_request.connect(show_panel)
		tooltip.hide_panel.connect(hide_panel)
		tooltip.tooltip_expired.connect(effects_changed)
		add_child(tooltip)
		if cluster in added_keys:
			tooltip.play_entrance_animation()
	effects_changed()

func tooltip_count():
	get_child_count()

func dump_tooltips():
	for tooltip in get_children():
		tooltip.free()

func show_panel(panel):
	pass
	
	

func hide_panel():
	pass

func change_width(new_width):
	size.x = new_width

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
