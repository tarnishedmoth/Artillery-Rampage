class_name RoundDirector

var tank_controllers: Array = []
var active_player_index: int = 0

#TODO: Will listen for signals for when tank shot is finished, 
# when tank is killed, etc to remove them from round decisions

func add_controller(tank_controller) -> void:
	tank_controllers.append(tank_controller)
	
func begin_round() -> void:
	if tank_controllers.is_empty():
		return

	# Order of tanks is always random per original "Tank Wars"
	tank_controllers.shuffle()

	# Start with first player
	active_player_index = 0
	
	var active_player = tank_controllers[active_player_index]
	active_player.begin_turn()
	GameEvents.emit_turn_started(active_player)
