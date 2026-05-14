extends VBoxContainer
class_name BattleLogRow

const PORTRAIT_SIZE = Vector2(28, 28)
const ICON_SIZE = Vector2(20, 20)
const SUB_PORTRAIT_SIZE = Vector2(20, 20)
const SUB_ICON_SIZE = Vector2(16, 16)
const HEADER_FONT_SIZE = 13
const SUB_FONT_SIZE = 12
const SUB_INDENT = 18

const COLOR_NEUTRAL = Color(0.92, 0.92, 0.92)
const COLOR_DAMAGE = Color(0.88, 0.33, 0.33)
const COLOR_HEALING = Color(0.37, 0.86, 0.49)
const COLOR_BUFF = Color(0.37, 0.71, 0.86)
const COLOR_DEBUFF = Color(0.76, 0.40, 0.86)
const COLOR_EFFECT_OFF = Color(0.55, 0.55, 0.55)
const COLOR_COUNTER = Color(1.0, 0.71, 0.33)
const COLOR_BLOCK = Color(0.62, 0.62, 0.62)
const COLOR_DEATH = Color(0.95, 0.20, 0.20)
const COLOR_TURN_HEADER = Color(0.85, 0.85, 0.55)
const COLOR_SYSTEM = Color(0.80, 0.80, 0.95)
const COLOR_SUB_TEXT = Color(0.80, 0.80, 0.80)

const COLOR_TEAM_PLAYER = Color(0.55, 0.85, 1.0)
const COLOR_TEAM_ENEMY = Color(1.0, 0.55, 0.55)

const DAMAGE_TYPE_COLORS = {
	0: Color(0.88, 0.33, 0.33),
	1: Color(0.55, 0.65, 1.0),
	2: Color(0.95, 0.65, 0.30),
	3: Color(0.95, 0.86, 0.30),
	4: Color(0.65, 0.36, 0.85),
	5: Color(0.85, 0.20, 0.20),
	6: Color(1.0, 1.0, 1.0),
}

var _battle
var _event: BattleLogEvent
var _is_sub: bool = false
var _header_row: HBoxContainer
var _sub_container: MarginContainer
var _sub_vbox: VBoxContainer

static func from_event(event: BattleLogEvent, battle, is_sub: bool = false) -> BattleLogRow:
	var row = BattleLogRow.new()
	row._event = event
	row._battle = battle
	row._is_sub = is_sub
	row.add_theme_constant_override("separation", 1)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row._build()
	return row

func attach_sub_event(event: BattleLogEvent):
	if _sub_container == null:
		_sub_container = MarginContainer.new()
		_sub_container.add_theme_constant_override("margin_left", SUB_INDENT)
		_sub_container.add_theme_constant_override("margin_top", 1)
		_sub_vbox = VBoxContainer.new()
		_sub_vbox.add_theme_constant_override("separation", 1)
		_sub_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sub_container.add_child(_sub_vbox)
		add_child(_sub_container)
	var sub_row = BattleLogRow.from_event(event, _battle, true)
	_sub_vbox.add_child(sub_row)

func _font_size() -> int:
	return SUB_FONT_SIZE if _is_sub else HEADER_FONT_SIZE

func _portrait_size() -> Vector2:
	return SUB_PORTRAIT_SIZE if _is_sub else PORTRAIT_SIZE

func _icon_size() -> Vector2:
	return SUB_ICON_SIZE if _is_sub else ICON_SIZE

func _team_color(team_idx: int) -> Color:
	if team_idx == 0:
		return COLOR_TEAM_PLAYER
	if team_idx == 1:
		return COLOR_TEAM_ENEMY
	return COLOR_NEUTRAL

func _build():
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 4)
	_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_header_row)
	if _is_sub:
		_add_text("• ", COLOR_SUB_TEXT)
	match _event.kind:
		BattleLogEvent.Kind.ABILITY_USE:
			_add_actor()
			_add_text(" used ", COLOR_NEUTRAL)
			_add_ability()
		BattleLogEvent.Kind.DAMAGE:
			_add_actor()
			_add_text(" dealt ", COLOR_NEUTRAL)
			_add_damage_amount()
			_add_text(" to ", COLOR_NEUTRAL)
			_add_targets()
			_add_damage_source_suffix()
		BattleLogEvent.Kind.HEALING:
			_add_actor()
			_add_text(" healed ", COLOR_NEUTRAL)
			_add_targets()
			_add_text(" for ", COLOR_NEUTRAL)
			_add_amount_segment(_event.amount, COLOR_HEALING, "")
		BattleLogEvent.Kind.EFFECT_APPLIED:
			_add_actor()
			_add_text(" applied ", COLOR_NEUTRAL)
			_add_effect_segment()
			_add_text(" to ", COLOR_NEUTRAL)
			_add_targets()
		BattleLogEvent.Kind.EFFECT_EXPIRED:
			_add_effect_segment(COLOR_EFFECT_OFF)
			var reason = _event.extra.get("reason", "expired")
			_add_text(" " + reason + " on ", COLOR_EFFECT_OFF)
			_add_targets()
		BattleLogEvent.Kind.COUNTER:
			_add_actor()
			_add_text(" was countered!", COLOR_COUNTER)
		BattleLogEvent.Kind.REFLECT:
			_add_actor()
			_add_text(" was reflected!", COLOR_COUNTER)
		BattleLogEvent.Kind.INVULN_BLOCK:
			_add_targets()
			_add_text(" was invulnerable to ", COLOR_BLOCK)
			_add_actor()
			_add_text("'s attack", COLOR_BLOCK)
		BattleLogEvent.Kind.MISS:
			_add_actor()
			_add_text(" missed ", COLOR_BLOCK)
			_add_targets()
		BattleLogEvent.Kind.DEATH:
			_add_actor()
			_add_text(" has fallen", COLOR_DEATH)
		BattleLogEvent.Kind.REVIVE:
			_add_actor()
			_add_text(" was revived", COLOR_HEALING)
		BattleLogEvent.Kind.ENERGY_GAIN:
			var element = str(_event.extra.get("element", ""))
			_add_text("Team gained ", COLOR_NEUTRAL)
			_add_text(element, COLOR_BUFF)
			_add_text(" energy", COLOR_NEUTRAL)
		BattleLogEvent.Kind.TURN_HEADER:
			_add_text("— Turn " + str(_event.turn) + " —", COLOR_TURN_HEADER, true)
		BattleLogEvent.Kind.SYSTEM:
			if _event.actor_path != "":
				_add_actor()
				_add_text(": ", COLOR_SYSTEM)
			_add_text(str(_event.extra.get("text", "")), COLOR_SYSTEM, true)

func _add_damage_amount():
	var color = DAMAGE_TYPE_COLORS.get(_event.damage_type, COLOR_DAMAGE)
	if _has_specific_damage_type():
		var dt_word = DamageType.get_damage_type_name(_event.damage_type, true)
		_add_amount_segment(_event.amount, color, " " + dt_word)
		_add_text(" damage", COLOR_NEUTRAL)
	else:
		_add_amount_segment(_event.amount, color, "")
		_add_text(" damage", COLOR_NEUTRAL)

func _has_specific_damage_type() -> bool:
	if _event.damage_type < 0:
		return false
	if _event.damage_type == DamageType.Type.NORMAL:
		return false
	return true

func _add_damage_source_suffix():
	if _event.effect_source_path != "":
		_add_text(" (from ", COLOR_EFFECT_OFF)
		_add_text(_event.effect_source_path, COLOR_EFFECT_OFF)
		_add_text(")", COLOR_EFFECT_OFF)
	elif _event.ability_name != "" and not _is_sub:
		_add_text(" via ", COLOR_NEUTRAL)
		_add_ability()

func _add_text(text: String, color: Color, bold: bool = false):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _font_size())
	if bold:
		var settings = LabelSettings.new()
		settings.font_size = _font_size() + 1
		settings.font_color = color
		settings.outline_size = 4
		settings.outline_color = Color.BLACK
		label.label_settings = settings
	_header_row.add_child(label)

func _add_amount_segment(amount: int, color: Color, suffix: String):
	_add_text(str(amount) + suffix, color, true)

func _add_actor():
	if _event.actor_path == "":
		return
	var character = _resolve_character(_event.actor_path)
	if character != null:
		_add_portrait(character)
	_add_name_label(_event.actor_name, _team_color(_event.actor_team), character)

func _add_targets():
	if _event.target_paths.is_empty():
		return
	for i in range(_event.target_paths.size()):
		if i > 0:
			if i == _event.target_paths.size() - 1:
				_add_text(" and ", COLOR_NEUTRAL)
			else:
				_add_text(", ", COLOR_NEUTRAL)
		var path = _event.target_paths[i]
		var name = _event.target_names[i] if i < _event.target_names.size() else path
		var character = _resolve_character(path)
		if character != null:
			_add_portrait(character)
		var team_idx = -1
		if character != null:
			team_idx = BattleLogEvent._resolve_team_index(character)
		_add_name_label(name, _team_color(team_idx), character)

func _add_name_label(name: String, color: Color, character):
	if name == "":
		return
	var label = Label.new()
	label.text = name.capitalize()
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _font_size())
	if character != null:
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_entered.connect(_on_character_hover.bind(label, character))
	_header_row.add_child(label)

func _add_portrait(character):
	if character == null:
		return
	var rect = _make_icon_rect(_portrait_size())
	var tex = null
	if character.has_method("active_portrait"):
		tex = character.active_portrait()
	if tex == null:
		tex = character.portrait_texture
	rect.texture = tex
	rect.mouse_entered.connect(_on_character_hover.bind(rect, character))
	_header_row.add_child(rect)

func _make_icon_rect(target_size: Vector2) -> TextureRect:
	var rect = TextureRect.new()
	rect.custom_minimum_size = target_size
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect

func _add_ability():
	if _event.ability_name == "":
		return
	var character = _resolve_character(_event.actor_path)
	var ability = _resolve_ability(character, _event.ability_name)
	if ability != null and ability.image != null:
		var rect = _make_icon_rect(_icon_size())
		rect.texture = ability.image
		rect.mouse_entered.connect(_on_ability_hover.bind(rect, character, ability))
		_header_row.add_child(rect)
	var label = Label.new()
	label.text = _event.ability_name
	label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _font_size())
	if ability != null and character != null:
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_entered.connect(_on_ability_hover.bind(label, character, ability))
	_header_row.add_child(label)

func _add_effect_segment(override_color: Color = Color(0, 0, 0, 0)):
	if _event.effect_name == "":
		return
	var color = override_color if override_color.a > 0.0 else COLOR_BUFF
	var character = null
	if not _event.target_paths.is_empty():
		character = _resolve_character(_event.target_paths[0])
	var effect = _resolve_effect(character, _event.effect_id, _event.effect_name, _event.effect_type)
	if effect != null and effect.tooltip != null:
		var rect = _make_icon_rect(_icon_size())
		rect.texture = effect.tooltip
		rect.mouse_entered.connect(_on_effect_hover.bind(rect, effect))
		_header_row.add_child(rect)
	var label = Label.new()
	label.text = _event.effect_name
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _font_size())
	if effect != null:
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_entered.connect(_on_effect_hover.bind(label, effect))
	_header_row.add_child(label)

func _resolve_character(path: String):
	if _battle == null or path == "":
		return null
	if not _battle.has_method("all_characters"):
		return null
	for character in _battle.all_characters():
		if character.path_name == path:
			return character
	return null

func _resolve_ability(character, ability_name: String):
	if character == null or character.moveset == null:
		return null
	for ability in character.moveset.get_active_abilities(character):
		if ability.ability_name == ability_name:
			return ability
	for ability in character.moveset.base_abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

func _resolve_effect(character, target_id, target_name: String, target_type: int):
	if character == null or character.effects == null:
		return null
	if target_id != null:
		for eff in character.effects._effects:
			if eff.id == target_id:
				return eff
		for eff in character.effects._display_effects:
			if eff.id == target_id:
				return eff
	if target_type >= 0:
		for eff in character.effects._effects:
			if eff.effect_name() == target_name and eff.effect_type == target_type:
				return eff
		for eff in character.effects._display_effects:
			if eff.effect_name() == target_name and eff.effect_type == target_type:
				return eff
	for eff in character.effects._effects:
		if eff.effect_name() == target_name:
			return eff
	for eff in character.effects._display_effects:
		if eff.effect_name() == target_name:
			return eff
	return null

func _on_character_hover(_source, character):
	if _battle == null or character == null:
		return
	if _battle.has_method("describe_character"):
		_battle.describe_character(character)

func _on_ability_hover(_source, character, ability):
	if _battle == null or character == null or ability == null:
		return
	if _battle.has_method("describe_ability"):
		_battle.describe_ability(character, ability)

func _on_effect_hover(source, effect):
	if _battle == null or not _battle.has_method("show_panel"):
		return
	if effect == null:
		return
	var panel = EffectTooltipHoverPanel.from_effects([effect])
	_battle.show_panel(source, panel)
