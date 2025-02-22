class_name RoundDirector

var tank_controllers: Array = []
var active_player_index: int = -1
var physics_sim_time: float = 5.0
var physics_check_time: float = 0.2

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
	 # Wait for physics to settle prior to allowing next player to start
	# TODO: use an AutoLoad SceneManager to get the current tree 
	# or just make this class a Node and add to tree from Game
	# Making this class a node would allow export properties to be set from the editor
	var scene_tree = controller.get_tree()

	# Wait a smidge and then check if any tank is falling and give time for physics to settle
	await scene_tree.create_timer(physics_check_time).timeout
	
	if is_any_tank_falling():
		await controller.get_tree().create_timer(physics_sim_time).timeout
	
	if !next_player():
		GameEvents.emit_round_ended()
		return

func is_any_tank_falling() -> bool:
	for controller in tank_controllers:
		if is_instance_valid(controller) && controller.tank.is_falling():
			return true
	return false
	
func _on_tank_killed(tank: Tank, instigatorController: Node2D, instigator: Node2D):
	# Need to reset the active player index when removing the controller
	var tank_controller_to_remove: TankController = tank.owner
	if !is_instance_valid(tank_controller_to_remove):
		push_warning("tank=" + tank.name + " has no owner controller")
		return
	var index_to_remove: int = tank_controllers.find(tank_controller_to_remove)
	if(index_to_remove < 0):
		push_warning("TankController=" + tank_controller_to_remove.name + " is not in round")
		return
	
	tank_controllers.erase(tank_controller_to_remove)
	
	# See if we need to shift the active player index
	if index_to_remove <= active_player_index:
		active_player_index -= 1
		if active_player_index < 0:
			active_player_index = tank_controllers.size() - 1
