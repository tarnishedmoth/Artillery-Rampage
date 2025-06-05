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
	DEPLOY_NUMBER, # int, Deployable only
	DEPLOY_VELOCITY_IMPULSE, # float, Deployable only
	DEPLOY_DELAY, # float, Deployable only
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

func get_property_key(modifiable: Modifiables = property) -> String:
	var text_representation:String = Modifiables.find_key(modifiable)
	return text_representation.to_lower()
	
func get_property_value_to_string() -> String:
	return str(value) if operation != Operations.SET_TRUE and operation != Operations.SET_FALSE else ""
		

func operation_to_string() -> String:
	match operation:
		Operations.MULTIPLY: return "*"
		Operations.ADD : return "+"
		Operations.SUBTRACT: return "-"
		Operations.SET : return "="
		Operations.SET_TRUE: return "is true"
		Operations.SET_FALSE: return "is false"
		_: return "OPERATION %s" % operation

func _to_string() -> String:
	return "%s %s %s" % [get_property_key(), operation_to_string(), get_property_value_to_string()]

# Code constructors
func configure_and_apply(projectile_to_attach_to: WeaponProjectile, _property: Modifiables, _operation: Operations, _value:float) -> void:
	property = _property
	operation = _operation
	value = _value
	projectile_to_attach_to.apply_mod(self)

#region Savable

func serialize() -> Dictionary:
	var data:Dictionary = {}

	data["property"] = EnumUtils.enum_to_string(Modifiables, property)
	data["operation"] = EnumUtils.enum_to_string(Operations, operation)
	data["value"] = value

	return data

static func deserialize(state: Dictionary) -> ModProjectile:
	if not state:
		return null
	
	var mod: ModProjectile = ModProjectile.new()

	mod.property = EnumUtils.enum_from_string(Modifiables, state.get("property", ""))
	mod.operation = EnumUtils.enum_from_string(Operations, state.get("operation", ""))
	mod.value = state.get("value", 0.0)

	return mod

#endregion
