class_name GameLevel extends Node2D

@onready var round_director : RoundDirector = %RoundDirector
@onready var spawner: ArtillerySpawner = %ArtillerySpawner
@onready var terrain: Terrain = %Terrain
@onready var wind: Wind = %Wind
@onready var walls: Walls = %Walls
@onready var game_timer:GameTimer = %GameTimer
@onready var post_processing: PostProcessingEffects = %PostProcessing

## Name of level displayed to player
@export var level_name:StringName

var _scene_transitioned:bool = false

## Used to hold various spawnables such as [WeaponProjectile] and particle effects.
var container_for_spawnables

func _ready() -> void:
	GameEvents.connect("round_ended", _on_round_ended)
	container_for_spawnables = make_container_node() # For spawnables
	GameEvents.level_loaded.emit(self)
	
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
	await _add_spawned_units()

	GameEvents.all_players_added.emit(self)
				
	round_director.begin_round()
		
func _on_player_killed(in_player: Player) -> void:
	# Must free player as the player class does not do this when the tank is killed
	# AI tank gets freed when the tank is killed
	in_player.queue_free()

	if _scene_transitioned:
		print_debug("Player killed but scene already transitioned - ignoring")
		return
	_scene_transitioned = true
	
	print("Game Over!")
	SceneManager.level_failed()

func _on_round_ended() -> void:
	# Let other listeners process before switching the scene
	await get_tree().process_frame

	# if player was killed then level_failed already called so don't call again here
	# as this is used for the win state
	if _scene_transitioned:
		print_debug("Round ended but scene already transitioned - ignoring")
		return

	_scene_transitioned = true
	SceneManager.level_complete()

func _add_manually_placed_units():
	for child in get_children():
		if child is TankController:
			round_director.add_controller(child)
			connect_events(child)

func _add_spawned_units():
	for controller in await spawner.spawn_all(terrain):
		round_director.add_controller(controller)
		connect_events(controller)
		
func connect_events(controller: TankController) -> void:
	if controller is Player:
		controller.connect("player_killed", _on_player_killed)
		
func make_container_node() -> Node2D:
	var container = Node2D.new()
	if has_node("%Walls"):
		%Walls.add_child(container)
	else:
		add_child(container)
	return container

func get_container() -> Node2D:
	if not container_for_spawnables.is_inside_tree():
		container_for_spawnables = make_container_node()
	return container_for_spawnables
