class_name ModWeapon extends Resource

## Class for upgrading/modifying Weapon properties at runtime.

## Passed to the Weapon to be applied on [method Weapon.shoot]
@export var projectile_mods:Array[ModProjectile]

enum Operations {
	MULTIPLY,
	ADD,
	SUBTRACT,
	SET,
	SET_TRUE,
	SET_FALSE
}

enum Modifiables {
	ACCURACY_ANGLE_SPREAD,
	ALWAYS_SHOOT_FOR_COUNT,
	ALWAYS_SHOOT_FOR_DURATION,
	AMMO_USED_PER_SHOT,
	CURRENT_AMMO,
	FIRE_RATE,
	FIRE_VELOCITY,
	MAGAZINES,
	MAGAZINE_CAPACITY,
	POWER_LAUNCH_SPEED_MULT,
	RETAIN_WHEN_EMPTY,
	USE_AMMO,
	USE_FIRE_RATE,
	USE_MAGAZINES,
}

@export var property: Modifiables ## Which property of the Weapon to modify.
@export var operation: Operations ## What operation to perform on the property value.
@export var value:float = 1.0 ## Int or Float. Not used if Operation is SET_TRUE or SET_FALSE.

## Can be used to retain mods across matches and reapply them.
@export_placeholder("Only needs set if not attached to weapon.") var target_weapon_name:String

func modify_weapon(weapon: Weapon) -> void:
	target_weapon_name = weapon.display_name # keep track
	var property_string:String = get_property_key(property)
	var current_value = weapon.get(property_string) # This could be float, int, or bool
	var new_value = current_value # Should set the type??
	print_debug(new_value)
	
	match operation:
		Operations.MULTIPLY:
			new_value = current_value * value
			
		Operations.ADD:
			new_value = current_value + value
			
		Operations.SUBTRACT:
			new_value = current_value - value
			
		Operations.SET:
			new_value = value
			
		Operations.SET_TRUE:
			if current_value is bool: # Catch designer error
				new_value = true
			else:
				new_value = current_value
				print_debug("Invalid operation on value", property_string)
				
		Operations.SET_FALSE:
			if current_value is bool: # Catch designer error
				new_value = false
			else:
				new_value = current_value
				print_debug("Invalid operation on value", property_string)
	
	# Set the property
	weapon.set(property_string, new_value)
	
	if not projectile_mods.is_empty():
		for mod in projectile_mods:
			weapon.apply_new_mod(mod)

func get_property_key(modifiable: Modifiables) -> String:
	var text_representation:String = Modifiables.find_key(modifiable)
	return text_representation.to_lower()

# Code constructors
func configure_and_apply(weapon_to_attach_to: Weapon, property: Modifiables, operation: Operations, value:float) -> void:
	property = property
	operation = operation
	value = value
	weapon_to_attach_to.apply_mod(self)
