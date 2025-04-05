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
	var tooltips = recursive_get_children(top_node)
	
	for control in tooltips:
		if "text" in control:
			control.text = replace_keybind_glyphs(control.text)

func replace_keybind_glyphs(text: String) -> String: # I don't understand why this isn't working
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
		new_text = new_text.replace(action, replacement_text)
	
	return new_text


func _on_user_options_changed() -> void:
	toggle_visibility()

func _on_turn_started(controller: TankController) -> void:
	if controller is not Player:
		is_player_turn = false
		switch_display_to_new_context(Context.EnemyTurn)
	else:
		is_player_turn = true
		switch_display_to_new_context(Context.PlayerTurn)
