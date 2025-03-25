class_name ModProjectile extends Resource

## Class for upgrading/modifying Weapon properties at runtime.

enum Operations {
	MULTIPLY,
	ADD,
	SUBTRACT,
	SET,
	SET_TRUE,
	SET_FALSE
}

enum Modifiables {
	FALLOFF_DISTANCE_MULTIPLIER, # float
	DAMAGE_MULTIPLIER, # float
	DESTRUCTIBLE_SCALE_MULTIPLIER_SCALAR, # float
	SHOULD_EXPLODE_ON_IMPACT, # bool
	MASS, # float
	MAX_LIFETIME, # float
}

@export var property: Modifiables ## Which property of the Weapon to modify.
@export var operation: Operations ## What operation to perform on the property value.
@export var value:float ## Int or Float. Not used if Operation is SET_TRUE or SET_FALSE.

func modify_projectile(projectile: WeaponProjectile) -> void:
	var property_string:String = get_property_key(property)
	var current_value = projectile.get(property_string) # This could be float, int, or bool
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
	projectile.set(property_string, new_value)

func get_property_key(modifiable: Modifiables) -> String:
	var text_representation:String = Modifiables.find_key(modifiable)
	return text_representation.to_lower()

# Code constructors
func configure_and_apply(projectile_to_attach_to: WeaponProjectile, property: Modifiables, operation: Operations, value:float) -> void:
	property = property
	operation = operation
	value = value
	projectile_to_attach_to.apply_mod(self)
