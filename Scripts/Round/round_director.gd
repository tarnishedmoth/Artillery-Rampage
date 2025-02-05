class_name RoundDirector

var tank_controllers: Array = []
var active_player_index: int = -1

func add_controller(tank_controller) -> void:
	tank_controllers.append(tank_controller)
	
func begin_round() -> bool:
	
	GameEvents.connect("turn_ended", _on_turn_ended)
	
	for controller in tank_controllers:
		controller.tank.connect("tank_killed", _on_tank_killed)
		
	# Order of tanks is always random per original "Tank Wars"
	tank_controllers.shuffle()
	
	GameEvents.emit_round_started()
	
	return next_player()

func next_player() -> bool:
	# If there are 1 or 0 players left then the round is over
	if tank_controllers.size() <= 1:
		active_player_index = -1
		return false
		
	active_player_index = (active_player_index + 1) % tank_controllers.size()
	var active_player = tank_controllers[active_player_index]
	
	active_player.begin_turn()
	GameEvents.emit_turn_started(active_player)
	
	return true
	
func _on_turn_ended(controller: TankController):
	print("Turn ended for " + controller.name)
	
	if !next_player():
		GameEvents.emit_round_ended()
		return

func _on_tank_killed(tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile):
	tank_controllers.erase(tank.owner)
