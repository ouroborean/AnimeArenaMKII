extends PanelContainer
class_name MessageBox

const MAX_HISTORY = 1000
const AUTO_SCROLL_THRESHOLD = 16.0

var battle = null
var _events: Array = []
var _last_turn_logged: int = -1
var _user_scrolled_away: bool = false
var _current_ability_row: BattleLogRow = null
var _seen_first_action: bool = false

@onready var _scroll: ScrollContainer = $MarginContainer/VBoxRoot/ScrollPanel/ScrollMargin/ScrollContainer
@onready var _vbox: VBoxContainer = $MarginContainer/VBoxRoot/ScrollPanel/ScrollMargin/ScrollContainer/VBoxContainer

func _ready():
	if _scroll != null:
		_scroll.get_v_scroll_bar().scrolling.connect(_on_user_scrolled)

func bind_battle(battle_node):
	battle = battle_node
	if battle == null:
		return
	if battle.has_signal("log_event") and not battle.log_event.is_connected(receive_log_event):
		battle.log_event.connect(receive_log_event)

func clear_log():
	_events.clear()
	_last_turn_logged = -1
	_current_ability_row = null
	_seen_first_action = false
	_user_scrolled_away = false
	if _vbox != null:
		for child in _vbox.get_children():
			_vbox.remove_child(child)
			child.queue_free()

func receive_log_event(event):
	if event == null:
		return
	# Hard gate: nothing renders until the first real ABILITY_USE arrives.
	# Everything before the first action — startup passives, system effects,
	# snapshot-reconcile chatter, start-of-turn triggers from passives, even
	# the leading TURN_HEADER — is silenced. The auto-insert below stamps in
	# the missing turn header right above the first action so the log still
	# starts with "Turn 1" once it opens.
	if not _seen_first_action:
		if event.kind != BattleLogEvent.Kind.ABILITY_USE:
			return
		_seen_first_action = true
	if event.kind == BattleLogEvent.Kind.TURN_HEADER and event.turn == _last_turn_logged:
		return
	if event.kind != BattleLogEvent.Kind.TURN_HEADER and event.turn != _last_turn_logged and event.turn > 0:
		_insert_turn_header(event.turn)
	if event.kind == BattleLogEvent.Kind.TURN_HEADER:
		_last_turn_logged = event.turn
		_current_ability_row = null
	_events.append(event)
	if _events.size() > MAX_HISTORY:
		_events.pop_front()
		if _vbox.get_child_count() > MAX_HISTORY:
			var first = _vbox.get_child(0)
			_vbox.remove_child(first)
			first.queue_free()
	if _should_nest(event) and _current_ability_row != null:
		_current_ability_row.attach_sub_event(event)
	else:
		var row = BattleLogRow.from_event(event, battle)
		_vbox.add_child(row)
		if event.kind == BattleLogEvent.Kind.ABILITY_USE:
			_current_ability_row = row
		elif event.kind == BattleLogEvent.Kind.TURN_HEADER:
			pass
		else:
			_current_ability_row = null
	_maybe_autoscroll()

func _should_nest(event) -> bool:
	match event.kind:
		BattleLogEvent.Kind.ABILITY_USE, BattleLogEvent.Kind.TURN_HEADER, BattleLogEvent.Kind.SYSTEM, BattleLogEvent.Kind.ENERGY_GAIN, BattleLogEvent.Kind.DEATH, BattleLogEvent.Kind.REVIVE:
			return false
	# Damage / healing produced by an ongoing effect tick (not by an in-progress
	# ability execution) become their own top-level rows instead of nesting
	# under whatever ability happened earlier in the turn. Detect via
	# effect_name being set (with_effect populated on the event) or effect_id.
	if event.kind == BattleLogEvent.Kind.DAMAGE or event.kind == BattleLogEvent.Kind.HEALING:
		if event.effect_name != "" or event.effect_id != null or event.effect_source_path != "":
			return false
	# Effect expirations always belong to end-of-turn / cleanse cleanup and
	# should not retroactively nest under an earlier ability use.
	if event.kind == BattleLogEvent.Kind.EFFECT_EXPIRED:
		return false
	return true

func _insert_turn_header(turn_number: int):
	var header_event = BattleLogEvent.make(BattleLogEvent.Kind.TURN_HEADER)
	header_event.turn = turn_number
	_last_turn_logged = turn_number
	_current_ability_row = null
	_events.append(header_event)
	var row = BattleLogRow.from_event(header_event, battle)
	_vbox.add_child(row)

func _maybe_autoscroll():
	if _scroll == null or _user_scrolled_away:
		return
	await get_tree().process_frame
	var bar = _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)

func _on_user_scrolled():
	if _scroll == null:
		_user_scrolled_away = false
		return
	var bar = _scroll.get_v_scroll_bar()
	if bar == null:
		return
	var distance_from_bottom = bar.max_value - (_scroll.scroll_vertical + bar.page)
	_user_scrolled_away = distance_from_bottom > AUTO_SCROLL_THRESHOLD

func receive_message_request(_msg):
	pass

func receive_message_demand(_msg):
	pass

func toggle_visibility():
	visible = not visible

func _on_gui_input(event):
	pass
