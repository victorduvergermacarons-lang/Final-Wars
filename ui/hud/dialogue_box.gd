class_name DialogueBox
extends PanelContainer
## The conversation window at the bottom of the screen: the speaker's portrait and
## name, what they say, and your answers. Every line comes from the dialogue file
## by id (ContentDB.dialogue; see DialogueLines). Opens on a "dialogue" event for
## the local hero, or on a line of your own (examining a spot). Closes on Goodbye,
## Esc (handled by Hud._escape), or walking away. Other systems (shop, quests) add
## their own buttons through add_option().

signal opened(npc: Npc)
signal closed

const CLOSE_DISTANCE := 3
const WIDTH := 760.0

var hud: Hud
var npc_id := -1
## Where a conversation without an NPC (examining a spot) happens; it closes when
## you walk away from it.
var anchor_tile: Variant = null
var _portrait: PortraitView
var _name: Label
var _faction: Label
var _text: RichTextLabel
var _options: VBoxContainer
## The id of the line shown (tests and screenshots read it).
var line_id := ""


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(WIDTH, 0)
	# A paper sheet with ink text, like the menu book.
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_portrait = PortraitView.new()
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	head.add_child(_name)
	_faction = Label.new()
	_faction.add_theme_font_size_override("font_size", 14)
	_faction.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_faction)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(WIDTH - 140, 0)
	box.add_child(_text)
	_options = VBoxContainer.new()
	box.add_child(_options)
	visible = false


## Talking to `npc`: its greeting, its quests and shop, Goodbye.
func open(npc: Npc) -> void:
	npc_id = npc.id
	anchor_tile = null
	visible = true
	show_line(npc.def.greeting_line(hud.session.world_flags(), ContentDB.dialogue), "…", main_page_options)


## A line with no one to talk to (what you find at a spot you examine): `tile` is
## where it happens.
func open_line(id: String, fallback: String, tile: Vector2i) -> void:
	npc_id = -1
	anchor_tile = tile
	visible = true
	show_line(id, fallback, func(): add_option("Close", close), DialogueLines.HERO)


## Back to the NPC's main page (greeting and options), or closes if there is none.
func back_to_main() -> void:
	var npc := current_npc()
	if npc != null:
		open(npc)
	else:
		close()


## The main page's buttons: added by `opened` listeners (quests, shop) and Goodbye.
func main_page_options() -> void:
	var npc := current_npc()
	if npc != null:
		opened.emit(npc)
	add_option("Goodbye", close)


## Shows line `id` (with `fallback` text if the file lacks it): its speaker, its
## text, then its choices or a Continue button. At the end of the chain `after`
## adds the closing buttons (default: Back to the main page); when given, it also
## follows a line's choices (the greeting's choices sit beside the main page's
## buttons). `default_speaker` is who speaks when the line doesn't say ("" = the
## NPC you talk to, "hero" = you).
func show_line(id: String, fallback: String = "", after: Callable = Callable(), default_speaker: String = "") -> void:
	var l := ContentDB.dialogue.line(id, fallback)
	line_id = id
	set_speaker(l.speaker if l.speaker != "" else default_speaker)
	set_text(l.text)
	clear_options()
	for c in l.choices:
		var next: String = c.next
		add_option(c.text, func():
			if next != "":
				show_line(next, "…", Callable(), default_speaker)
			else:
				back_to_main())
	if l.next != "":
		var next_id: String = l.next
		add_option("Continue", func(): show_line(next_id, "…", after, default_speaker))
	elif after.is_valid():
		after.call()
	elif l.choices.is_empty():
		add_option("Back", back_to_main)


## Who speaks: "" = the NPC you talk to, "hero" = you, else an NPC id.
func set_speaker(speaker: String) -> void:
	var hero: Hero = hud.session.local_hero()
	if speaker == DialogueLines.HERO and hero != null:
		_name.text = hero.display_name
		_faction.text = ""
		_portrait.show_hero(hero.display_name, WorldView.HERO_COLORS[(hero.id - 1) % WorldView.HERO_COLORS.size()])
		return
	var def: NpcDef = ContentDB.npcs.get(StringName(speaker)) if speaker != "" else null
	if def == null:
		var npc := current_npc()
		def = npc.def if npc != null else null
	if def == null:
		_name.text = ""
		_faction.text = ""
		return
	_name.text = def.display_name
	_faction.text = Factions.display_name(def.faction)
	_faction.add_theme_color_override("font_color", def.color().darkened(0.35))
	_portrait.show_npc(def)


func set_text(bbcode: String) -> void:
	_text.text = bbcode


## Adds a block under the line (a quest's objectives and rewards).
func append_text(bbcode: String) -> void:
	_text.text += "\n\n" + bbcode


func text() -> String:
	return _text.text


func speaker_name() -> String:
	return _name.text


func clear_options() -> void:
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()


func add_option(label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	_options.add_child(b)
	return b


## Adds an already-built button (e.g. one with an item tooltip).
func add_custom_option(b: Button) -> void:
	_options.add_child(b)


## The buttons shown, by label (tests).
func option_labels() -> Array[String]:
	var out: Array[String] = []
	for c in _options.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c.text)
	return out


## Presses the button labelled `label` (tests); false if there is none.
func press(label: String) -> bool:
	for c in _options.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.text == label:
			c.pressed.emit()
			return true
	return false


func close() -> void:
	if visible:
		visible = false
		npc_id = -1
		anchor_tile = null
		closed.emit()


func current_npc() -> Npc:
	return hud.session.get_actor(npc_id) as Npc if npc_id >= 0 else null


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null or not hero.alive:
		close()
		return
	if anchor_tile != null:
		if GridModel.distance(hero.tile(), anchor_tile) > CLOSE_DISTANCE:
			close()
		return
	var npc := current_npc()
	if npc == null or GridModel.distance(hero.tile(), npc.tile()) > CLOSE_DISTANCE:
		close()
