extends Control
class_name HelpDimLayer

# Fullscreen dim with highlight cutouts and opaque obscure regions, all drawn
# via _draw (no shader). The visual model:
#   - Whole canvas dimmed at DIM_ALPHA by default
#   - Highlight rects cut clear through the dim AND through obscure rects
#   - Obscure rects (minus any highlight overlap) painted fully opaque
#
# Highlights and obscures are stored as plain Rect2 arrays; the dim region is
# computed as (canvas_rect minus union of highlight rects), each piece drawn
# as a separate dim rectangle. Cheap for the small widget counts we deal with.

const DIM_COLOR := Color(0, 0, 0, 0.85)
const OBSCURE_COLOR := Color(0, 0, 0, 1)

var highlight_rects: Array = []
var obscure_rects: Array = []

func set_rects(highlights: Array, obscures: Array) -> void:
	highlight_rects = highlights
	obscure_rects = obscures
	queue_redraw()

func _draw() -> void:
	var screen_rect := Rect2(Vector2.ZERO, size)
	# Default dim: screen minus highlights.
	var dim_pieces: Array = [screen_rect]
	for h in highlight_rects:
		dim_pieces = _subtract_from_list(dim_pieces, h)
	for r in dim_pieces:
		if r.size.x > 0 and r.size.y > 0:
			draw_rect(r, DIM_COLOR)
	# Obscure: each obscure rect minus highlights.
	for o in obscure_rects:
		var obs_pieces: Array = [o]
		for h in highlight_rects:
			obs_pieces = _subtract_from_list(obs_pieces, h)
		for r in obs_pieces:
			if r.size.x > 0 and r.size.y > 0:
				draw_rect(r, OBSCURE_COLOR)

static func _subtract_from_list(rects: Array, cutter: Rect2) -> Array:
	var out: Array = []
	for r in rects:
		for piece in _subtract(r, cutter):
			out.append(piece)
	return out

# Returns the axis-aligned pieces of `a` left after removing `b`. Up to 4
# strips (above, below, left, right of the intersection). If `b` does not
# overlap `a`, returns `[a]` unchanged.
static func _subtract(a: Rect2, b: Rect2) -> Array:
	var clip := a.intersection(b)
	if clip.size.x <= 0 or clip.size.y <= 0:
		return [a]
	var pieces: Array = []
	# Top strip — full width of a, above clip.
	if clip.position.y > a.position.y:
		pieces.append(Rect2(a.position.x, a.position.y, a.size.x, clip.position.y - a.position.y))
	# Bottom strip — full width of a, below clip.
	var clip_bottom := clip.position.y + clip.size.y
	var a_bottom := a.position.y + a.size.y
	if clip_bottom < a_bottom:
		pieces.append(Rect2(a.position.x, clip_bottom, a.size.x, a_bottom - clip_bottom))
	# Left strip — within clip's vertical range, left of clip.
	if clip.position.x > a.position.x:
		pieces.append(Rect2(a.position.x, clip.position.y, clip.position.x - a.position.x, clip.size.y))
	# Right strip — within clip's vertical range, right of clip.
	var clip_right := clip.position.x + clip.size.x
	var a_right := a.position.x + a.size.x
	if clip_right < a_right:
		pieces.append(Rect2(clip_right, clip.position.y, a_right - clip_right, clip.size.y))
	return pieces
