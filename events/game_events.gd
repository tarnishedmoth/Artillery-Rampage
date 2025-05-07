extends Node

var current_level:GameLevel

@warning_ignore_start("unused_signal")

signal user_options_changed()

## Called just before round started when all players have been added to the game
signal all_players_added(level: GameLevel)

signal round_started()
signal round_ended()

# Called when the game level is ready but before players and procedural spawning occurs
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

signal wall_interaction(walls: Walls, projectile: WeaponProjectile, interaction_location: Walls.WallInteractionLocation)

signal took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, contact_point: Vector2)

@warning_ignore_restore("unused_signal")
