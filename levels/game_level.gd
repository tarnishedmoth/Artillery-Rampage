class_name GameLevel extends Node2D

@onready var round_director : RoundDirector = %RoundDirector
@onready var spawner: ArtillerySpawner = %ArtillerySpawner
@onready var terrain: Terrain = %Terrain

func _ready() -> void:
	GameEvents.connect("round_ended", _on_round_ended)
	
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
	_add_manually_placed_units()
	_add_spawned_units()
				
	round_director.begin_round()

func _on_player_killed(in_player: Player) -> void:
	print("Game Over!")
	in_player.queue_free()
	
	SceneManager.restart_level()

func _on_round_ended() -> void:
	SceneManager.next_level()

func _add_manually_placed_units():
	for child in get_children():
		if child is TankController:
			round_director.add_controller(child)
			connect_events(child)

func _add_spawned_units():
	for controller in spawner.spawn_all(terrain):
		round_director.add_controller(controller)
		connect_events(controller)
		
func connect_events(controller: TankController) -> void:
	if controller is Player:
		controller.connect("player_killed", _on_player_killed)
