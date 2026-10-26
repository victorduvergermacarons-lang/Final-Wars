class_name DialogueLines
extends RefCounted
## Every line of dialogue, loaded from one editable JSON file
## (content/dialogue/act1.json). Code and data refer to lines by id only, so lines
## can be rewritten without touching either.
##
## File format:
##   {"lines": {
##       "<id>": "Plain text",
##       "<id>": {"text": "...", "speaker": "<npc id> | hero",
##                "next": "<id of the line after this one>",
##                "choices": [{"text": "What you answer", "next": "<id>"}, ...]}
##   }}
## "speaker" defaults to whoever you are talking to. Ids follow conventions:
##   npc.<npc>.greeting[.<world flag>]       what an NPC (or board, object) says
##   quest.<quest>.offer / .progress / .complete / .accepted / .declined /
##       .failed / .world_flag               what the quest's NPC says
##   quest.<quest>.accept / .decline         your answers on the offer page
##   quest.<quest>.interact.<i> / .deliver.<i> / .escort.<i>
##                                           said when objective <i> is done there
##   quest.<quest>.spot.<i>.<n>              what you find at investigate spot <n>
## A missing line falls back to a short default, so nothing breaks while writing.

const PATH := "res://content/dialogue/act1.json"
const HERO := "hero"

var _lines := {} # id -> {"text", "speaker", "next", "choices"}


static func load_file(path: String = PATH) -> DialogueLines:
	var out := DialogueLines.new()
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) == TYPE_DICTIONARY:
		out.load_dict(parsed)
	else:
		push_error("Dialogue: can't read %s" % path)
	return out


func load_dict(data: Dictionary) -> void:
	_lines.clear()
	var raw = data.get("lines", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for id in raw:
		var v = raw[id]
		var entry := {"text": "", "speaker": "", "next": "", "choices": []}
		if typeof(v) == TYPE_STRING:
			entry.text = v
		elif typeof(v) == TYPE_DICTIONARY:
			entry.text = str(v.get("text", ""))
			entry.speaker = str(v.get("speaker", ""))
			entry.next = str(v.get("next", ""))
			var choices = v.get("choices", [])
			if typeof(choices) == TYPE_ARRAY:
				for c in choices:
					if typeof(c) == TYPE_DICTIONARY:
						entry.choices.append({"text": str(c.get("text", "")), "next": str(c.get("next", ""))})
		_lines[String(id)] = entry


func has(id: String) -> bool:
	return _lines.has(id)


func ids() -> Array:
	var out := _lines.keys()
	out.sort()
	return out


## The line `id` ({"id", "text", "speaker", "next", "choices"}); a missing line
## comes back with `fallback` as its text.
func line(id: String, fallback: String = "") -> Dictionary:
	var entry: Dictionary = _lines.get(id, {"text": fallback, "speaker": "", "next": "", "choices": []})
	var out := entry.duplicate(true)
	out.id = id
	return out


func text(id: String, fallback: String = "") -> String:
	return _lines[id].text if _lines.has(id) else fallback


## Problems in the file: "next" or choices pointing at lines that don't exist.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for id in ids():
		var entry: Dictionary = _lines[id]
		if entry.text == "":
			errors.append("Dialogue line %s has no text" % id)
		if entry.next != "" and not _lines.has(entry.next):
			errors.append("Dialogue line %s: next line %s doesn't exist" % [id, entry.next])
		for c in entry.choices:
			if c.next != "" and not _lines.has(c.next):
				errors.append("Dialogue line %s: choice \"%s\" leads to missing line %s" % [id, c.text, c.next])
	return errors


## Initials for a placeholder portrait: "Captain Rowan" -> "CR", "Hilda" -> "HI".
static func initials(name: String) -> String:
	var words := name.strip_edges().split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].substr(0, 2).to_upper()
	return (words[0].substr(0, 1) + words[words.size() - 1].substr(0, 1)).to_upper()
