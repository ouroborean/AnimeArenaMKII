extends RefCounted
class_name HelpData

const SAVE_PATH := "user://help_pages.json"

var pages_by_fingerprint: Dictionary = {}

func _init() -> void:
	load_from_disk()

func load_from_disk() -> void:
	pages_by_fingerprint = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("HelpData: could not open %s for reading" % SAVE_PATH)
		return
	var content := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		pages_by_fingerprint = parsed

func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("HelpData: could not open %s for writing" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(pages_by_fingerprint, "\t"))
	f.close()

func get_pages(fingerprint: String) -> Array:
	if pages_by_fingerprint.has(fingerprint):
		var pages = pages_by_fingerprint[fingerprint]
		if pages is Array:
			return pages
	return []

func set_pages(fingerprint: String, pages: Array) -> void:
	if pages.is_empty():
		pages_by_fingerprint.erase(fingerprint)
	else:
		pages_by_fingerprint[fingerprint] = pages
