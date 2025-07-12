extends Control

enum Context {
	PlayerTurn,
	EnemyTurn,
}

@export var transition_time:float = 1.2
var current_context
var is_player_turn:bool = false

@onready var tooltips_player_turn: MarginContainer = %TooltipsPlayerTurn
@onready var tooltips_enemy_turn: MarginContainer = %TooltipsEnemyTurn

@onready var contexts: Array = [
	tooltips_player_turn,
	tooltips_enemy_turn,
]

func _ready() -> void:
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.user_options_changed.connect(_on_user_options_changed)
	GameEvents.level_loaded.connect(_on_level_loaded)

func _on_level_loaded(game_level:GameLevel) -> void:
	toggle_visibility(true)

func toggle_visibility(toggle:bool = true) -> void:
	if UserOptions.show_tooltips and toggle == true:
		check_glyphs(tooltips_player_turn)
		check_glyphs(tooltips_enemy_turn)
		show()
		return

	if visible: hide()

func switch_display_to_new_context(context: Context) -> void:
	if context == current_context: return
	current_context = context

	for ui in contexts:
		ui.hide()

	await transition() # Wait

	match context:
		Context.PlayerTurn:
			tooltips_player_turn.show()
		Context.EnemyTurn:
			tooltips_enemy_turn.show()

func transition(time:float = transition_time) -> bool:
	await get_tree().create_timer(time).timeout
	return true

func recursive_get_children(node:Node) -> Array:
	var children: Array
	for child in node.get_children():
		children.append(child)
		var subchildren = recursive_get_children(child)
		children.append_array(subchildren)
	return children

func check_glyphs(top_node: Control) -> void:
	check_and_remove_conditional_tooltips(top_node as TextSequence)

	var tooltips = recursive_get_children(top_node)
	
	for control in tooltips:
		if "text" in control:
			control.text = replace_keybind_glyphs(control.text)

func check_and_remove_conditional_tooltips(text_sequence: TextSequence) -> void:		
	if not text_sequence or not text_sequence.sequence:
		return
	
	for i in range(text_sequence.sequence.size() - 1, -1, -1):
		var tooltip:Control = text_sequence.sequence[i]
		if tooltip.is_in_group(Groups.SimultaneousFire) and not _is_simultaneous_fire_mode():
			print_debug("%s: Removing simultaneous fire only tooltip: %s" % [name, tooltip.name])
			text_sequence.remove_from_sequence(tooltip)

func _is_simultaneous_fire_mode() -> bool:
	var game_level:GameLevel = SceneManager.get_current_level_root()
	return game_level.round_director.is_simultaneous_fire if is_instance_valid(game_level) else false
			
func replace_keybind_glyphs(text: String) -> String:
	var new_text = text

	for action in UserOptions.get_all_keybinds():
		var glyphs = UserOptions.get_glyphs(action)
		var replacement_text:String

		for glyph:String in glyphs:
			# Remove crap
			glyph = glyph.replace(" (Physical)", "")
			glyph = glyph.replace(" - All Devices", "")

			if not replacement_text.is_empty():
				replacement_text += ", "
			replacement_text += glyph
		#print_debug(new_text, action, replacement_text)
		action = "[" + action + "]" # Making syntax to restrain it
		new_text = new_text.replace(action, replacement_text)

	return new_text


func _on_user_options_changed() -> void:
	toggle_visibility()

func _on_turn_started(controller: TankController) -> void:
	if controller is Player:
		is_player_turn = true
		switch_display_to_new_context(Context.PlayerTurn)
	# Don't show enemy tooltips for simultaneous fire mode
	elif not _is_simultaneous_fire_mode():
		is_player_turn = false
		switch_display_to_new_context(Context.EnemyTurn)
