class_name ModBundle extends Resource

## This class is a nice way to package upgrading things the player has. The weapon,
## the weapon's projectile, the tank, they all have different classes, and
## different tweakable properties. This class should be able to have a component of
## each available aspect of the player's control that we want to upgrade through
## game progression.

@export_group("Components", "component_")
@export var components_weapon_mods:Array[ModWeapon]
@export var components_projectile_mods:Array[ModProjectile]
# ideas
#@export var component_tank_mod:ModTank
#@export var component_player_mod:ModPlayer
#@export var component_world_mod:ModWorld

func apply_all_mods(weapon: Weapon) -> void:
	# apply mods where they need to go
	
	# weapons hold projectile mods to apply at spawn time
	weapon.apply_all_mods(components_weapon_mods)
