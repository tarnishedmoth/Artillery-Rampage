extends Node

var current_level:GameLevel

@warning_ignore_start("unused_signal")

signal user_options_changed()
signal difficulty_changed(new_difficulty: Difficulty.DifficultyLevel, old_difficulty: Difficulty.DifficultyLevel)

signal save_state_restored()
signal save_state_persisted()

## Called just before round started when all players have been added to the game
signal all_players_added(level: GameLevel)

signal round_started()
signal round_ended()

## Called when the game level is ready but before players and procedural spawning occurs
signal level_loaded(level: GameLevel)

## Called right before a scene is freed when the scenes are being switched
signal scene_leaving(scene: Node)
## Called when a new root scene is instantiated but before it is added to the tree
signal scene_switched(scene: Node)

signal turn_started(player: TankController)
signal turn_ended(player: TankController)

## Called when a full cycle of players has completed their actions within a round
signal turn_orbit_cycled()

signal player_added(player: TankController)
signal player_died(player: TankController)

signal tank_changed(player: TankController, old_tank:Tank, new_tank: Tank)

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

## Emitted when a destructible or damageable object takes damage.
## Only Damageable objects will have a damage > 0 as it is only relevant for health-aware nodes.
## Note that fall damage is currently only available through the tank.tank_took_damage signal and is not emitted here.
## [param object] The root node in a scene that has a Damageable group membership node
## [param instigatorController] The controller Node2D that caused the damage. Currently this is always a TankController or null
## [param instigator] The Node2D that caused the damage. Example would be a WeaponProjectile or the object if it was fall damage
## [param contact_point] The point of contact where the damage occurred.
## [param damage] The amount of raw damage that was done to the object. This is always > 0 for Damageable objects and 0 for destructible objects. This is not clamped to damageable object health.
signal took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, contact_point: Vector2, damage: float)

@warning_ignore_restore("unused_signal")
