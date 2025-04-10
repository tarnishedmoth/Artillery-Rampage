extends Node

var current_level:GameLevel

@warning_ignore_start("unused_signal")

signal user_options_changed()

signal round_started()
signal round_ended()
signal level_loaded(level: GameLevel)

signal turn_started(player: TankController)
signal turn_ended(player: TankController)

signal player_added(player: TankController)
signal player_died(player: TankController)

signal wind_updated(wind: Wind)
signal aim_updated(player: TankController)
signal power_updated(player: TankController)
signal weapon_updated(weapon: Weapon)
signal projectile_fired(projectile : WeaponProjectile)
signal weapon_fired(weapon : Weapon)

signal collectible_collected(collected: CollectibleItem)
signal personnel_requested_pickup(unit: PersonnelUnit)
signal personnel_requested_delivery(unit: PersonnelUnit)
signal copter_arrived_for_pickups(copter)
signal copter_left_airspace(copter)

@warning_ignore_restore("unused_signal")

func emit_turn_started(player: TankController):
	emit_signal("turn_started", player)

func emit_turn_ended(player: TankController):
	emit_signal("turn_ended", player)

func emit_aim_updated(player: TankController):
	emit_signal("aim_updated", player)

func emit_power_updated(player: TankController):
	emit_signal("power_updated", player)

func emit_round_started():
	emit_signal("round_started")

func emit_round_ended():
	emit_signal("round_ended")
	
func emit_weapon_fired(weapon : Weapon):
	emit_signal("weapon_fired", weapon)

func emit_projectile_fired(projectile : WeaponProjectile):
	emit_signal("projectile_fired", projectile)

func emit_wind_updated(wind: Wind):
	emit_signal("wind_updated", wind)
