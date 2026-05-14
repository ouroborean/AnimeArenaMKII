extends RefCounted
class_name MenuFingerprint

# Walks the scene tree from `tree_root` and produces a stable identifier
# representing the set of "menu-like" Controls currently visible. Used by the
# help system to look up which help pages apply to the current UI state.
#
# A node contributes to the fingerprint if:
#   - It is a visible Control (visible_in_tree)
#   - AND either:
#       * It has meta "help_id" set (preferred — explicit author opt-in), or
#       * Its node name ends with "Panel", "Menu", or "Scene"
#
# A node with meta "help_opaque" is identified normally but its descendants
# are not walked — useful for areas with dynamic/variable child panels (e.g.
# bounty cards) that would otherwise destabilize the fingerprint.
#
# The Help overlay itself is skipped so its own internal nodes do not pollute
# the fingerprint.

static func compute(tree_root: Node, skip_node: Node = null) -> String:
	var ids: Array = []
	_walk(tree_root, ids, skip_node)
	ids.sort()
	# Dedupe in case two visible nodes resolve to the same id.
	var deduped: Array = []
	var last := ""
	for id in ids:
		if id != last:
			deduped.append(id)
			last = id
	return "|".join(deduped)

static func _walk(node: Node, ids: Array, skip_node: Node) -> void:
	if node == skip_node:
		return
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree():
			var id := _identify(control)
			if id != "":
				ids.append(id)
	if node.has_meta("help_opaque"):
		return
	for child in node.get_children():
		_walk(child, ids, skip_node)

static func _identify(control: Control) -> String:
	if control.has_meta("help_id"):
		return str(control.get_meta("help_id"))
	var raw := str(control.name)
	# Strip Godot's auto-generated numeric suffix (e.g. "ClanPanel2" → "ClanPanel")
	var trimmed := raw
	while trimmed.length() > 0 and trimmed[trimmed.length() - 1] >= "0" and trimmed[trimmed.length() - 1] <= "9":
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	if trimmed.ends_with("Panel") or trimmed.ends_with("Menu") or trimmed.ends_with("Scene"):
		return _to_snake_case(trimmed)
	return ""

static func _to_snake_case(s: String) -> String:
	var result := ""
	for i in s.length():
		var c := s[i]
		if c >= "A" and c <= "Z":
			if i > 0:
				result += "_"
			result += c.to_lower()
		else:
			result += c
	return result
