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


func _on_user_options_changed() -> void:
	toggle_visibility()

func _on_turn_started(controller: TankController) -> void:
	if controller is not Player:
		is_player_turn = false
		switch_display_to_new_context(Context.EnemyTurn)
	else:
		is_player_turn = true
		switch_display_to_new_context(Context.PlayerTurn)
