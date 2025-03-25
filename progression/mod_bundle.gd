class_name ModBundle extends Resource

## This class is a nice way to package upgrading things the player has. The weapon,
## the weapon's projectile, the tank, they all have different classes, and
## different tweakable properties. This class should be able to have a component of
## each available aspect of the player's control that we want to upgrade through
## game progression.

@export_group("Components", "component_")
@export var components_weapon_mods:Array[ModWeapon]
@export var components_projectile_mods:Array[ModProjectile]
var target_weapon
# ideas
#@export var component_tank_mod:ModTank
#@export var component_player_mod:ModPlayer
#@export var component_world_mod:ModWorld

func apply_all_mods(player:Player, weapons:Array[Weapon]) -> void:
	# apply mods where they need to go
	# weapons hold projectile mods to apply at spawn time
	var target_weapon
	for mod in components_weapon_mods:
		for weapon in weapons:
			if mod.target_weapon_name.to_lower() == weapon.display_name.to_lower(): # this is lousy
				weapon.apply_mod(mod)
