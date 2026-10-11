class_name DialogueBox
extends PanelContainer
## The NPC conversation window. Opens on a "dialogue" event for the local hero;
## closes on Goodbye, Esc, or walking away. Other systems (vendor, quests) add
## their own buttons through add_option().

signal opened(npc: Npc)
signal closed

const CLOSE_DISTANCE := 3

var hud: Hud
var npc_id := -1
var _title: Label
var _text: RichTextLabel
var _options: VBoxContainer


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(440, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	box.add_child(_title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(420, 0)
	box.add_child(_text)
	_options = VBoxContainer.new()
	box.add_child(_options)
	visible = false


func open(npc: Npc) -> void:
	npc_id = npc.id
	_title.text = npc.display_name
	set_text(npc.def.greeting)
	clear_options()
	visible = true
	opened.emit(npc)
	add_option("Goodbye", close)


func set_text(bbcode: String) -> void:
	_text.text = bbcode


func clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()


func add_option(label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	_options.add_child(b)
	return b


func close() -> void:
	if visible:
		visible = false
		npc_id = -1
		closed.emit()


func current_npc() -> Npc:
	return hud.session.get_actor(npc_id) as Npc if npc_id >= 0 else null


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	var npc := current_npc()
	if hero == null or npc == null or not hero.alive \
			or GridModel.distance(hero.tile(), npc.tile()) > CLOSE_DISTANCE:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"target_clear"):
		close()
		get_viewport().set_input_as_handled()
