class_name Game extends Node2D

var round_director : RoundDirector

#TODO: These will be instantiated from the "players data" 
@onready var player = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameEvents.connect("round_ended", _on_round_ended)
	
	round_director = RoundDirector.new()
	begin_round()

# This is called at the start of the round to enable input for players
# TODO: We could pass in the global players data containing info about who is playing
# or more simply could do an auto-load Singleton and store the state for the active game there
# That class could also manage saving state
# Passing around a game-scoped object to results screens and new game scenes
# could be more error prone than using an auto-load and just initializing it at the start of every game
func begin_round():
	# TODO: This is where we will use the global "players data" auto-load singleton
	# to then create the necessary controllers and tanks from it
	# For now just loading in the instance from the scene
	round_director.add_controller(player)
	# TODO: Temporarily adding in fixed enemies from scene
	round_director.add_controller($Enemy1)
	round_director.add_controller($Enemy2)
	
	round_director.begin_round()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_player_player_killed(player: Player) -> void:
	print("Game Over!")
	player.queue_free()
	
	restart_game()

func _on_round_ended() -> void:
	restart_game()
	
func restart_game():
	await get_tree().create_timer(1).timeout
	# Restart the game 
	get_tree().reload_current_scene()
