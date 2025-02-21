class_name GameLevel extends Node2D

var round_director : RoundDirector

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
	# Discover any placed child controller nodes
	for child in get_children():
		if child is TankController:
			round_director.add_controller(child)
			
			if child is Player:
				child.connect("player_killed", _on_player_player_killed)
				
	round_director.begin_round()

func _on_player_player_killed(in_player: Player) -> void:
	print("Game Over!")
	in_player.queue_free()
	
	SceneManager.restart_level()

func _on_round_ended() -> void:
	SceneManager.restart_level()
