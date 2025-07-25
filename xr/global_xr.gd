class_name XRGameEvents extends Node

## Events
signal round_ready

var simulation: SubViewport

var player_controller: Player
var level_root: GameLevel

func _ready() -> void:
	## Connect signals
	GameEvents.all_players_added.connect(_on_game_all_players_added)
	
	
func _on_game_all_players_added(level: GameLevel) -> void:
	#level_root = SceneManager.get_current_level_root()
	level_root = level
	player_controller = level_root.round_director.player
	assert(player_controller is Player)
	
	round_ready.emit()
