class_name InitialAim extends Node

var _my_tank:Tank

## Change start angle pointed when spawn into the game
@export_range(-90, 90, 1.0) var start_angle:float = 0.0

func _ready() -> void:
	if is_zero_approx(start_angle):
		print_debug("%s - Skipping as no start angle magnitude was specified" % name)
		return
		
	var game_level:GameLevel = await GameEvents.all_players_added
	assert(game_level)
	
	_set_aim_direction(game_level)
	
func _set_aim_direction(game_level:GameLevel) -> void:
	_my_tank = Groups.get_parent_in_group(self, Groups.Unit) as Tank
	
	if not _my_tank:
		push_error("%s - Unable to find parent tank" % name)
		return
		
	var nearest_dist_sq:float = 1e12
	var nearest_player:Tank = null
	var my_pos:Vector2 = _my_tank.global_position
	
	for player in game_level.round_director.tank_controllers:
		if player.tank == _my_tank:
			continue
		
		var opponent:Tank = player.tank
		var dist_sq := opponent.global_position.distance_squared_to(my_pos)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_player = opponent
			
	if not nearest_player:
		push_warning("%s(%s) - Could not find nearest opponent" % [name, _my_tank])
		return
	
	# Aim at the nearest player
	var opp_pos:Vector2 = nearest_player.global_position
	var aim_sign:float = _get_aim_angle_sign(opp_pos)
	
	start_angle *= aim_sign * signf(start_angle)
	# We already ran ready so explicitly aim at this direction
	_my_tank.aim_at(deg_to_rad(start_angle))
	
	print_debug("%s(%s) - Start Angle=%f" % [name, _my_tank, start_angle])


# TODO: Copied from ai_behavior
func _get_aim_angle_sign(to_pos: Vector2) -> float:
	# Needs to be relative to turret neutral position which is up
	var up_vector: Vector2 = Vector2.UP.rotated(_my_tank.tankBody.global_rotation)
	
	var from_pos: Vector2 = _my_tank.turret.global_position
	var dir := from_pos.direction_to(to_pos)
	var angle := up_vector.angle_to(dir)

	return signf(angle)
