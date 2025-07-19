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
	NUMBER_OF_SCENES_TO_SPAWN,
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
@export_placeholder("Only needs set if not attached to weapon.") var target_weapon_scene_path:String

@export var is_buff:bool = true ## Set by randomizer, used by item shop.

func modify_weapon(weapon: Weapon) -> void:
	target_weapon_name = weapon.display_name # keep track
	target_weapon_scene_path = weapon.scene_file_path
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
			# TODO: Maybe this should use the new system that appens the mod to the projectile mod list on the weapon?
			# This way applies it inline though projectile mods not yet supported
			weapon.apply_new_mod(mod)

func get_property_key(modifiable: Modifiables = property) -> String:
	var text_representation:String = Modifiables.find_key(modifiable)
	return text_representation.to_lower()

func get_property_value_to_string() -> String:
	if operation != Operations.SET_TRUE and operation != Operations.SET_FALSE:
		return str(snapped(value, 0.01))
	elif operation == Operations.SET_TRUE: return "YES"
	elif operation == Operations.SET_FALSE: return "NO"
	else:
		push_warning("How did you manage to do this?")
		return ""
		
func property_to_display_string() -> String: ## For UI
	match property:
		Modifiables.ACCURACY_ANGLE_SPREAD:
			return "Accuracy Spread"
		Modifiables.ALWAYS_SHOOT_FOR_COUNT:
			return "Shots Fired per Turn"
		Modifiables.ALWAYS_SHOOT_FOR_DURATION:
			return "Shoot for Duration"
		Modifiables.AMMO_USED_PER_SHOT:
			return "Ammo used per Shot"
		Modifiables.CURRENT_AMMO:
			return "Ammo"
		Modifiables.FIRE_RATE:
			return "Rate of Fire"
		#Modifiables.FIRE_VELOCITY:
			## pretty sure this isn't implemented?
			#return "Call a Dev!"
		Modifiables.MAGAZINES:
			return "Magazines"
		Modifiables.MAGAZINE_CAPACITY:
			return "Ammo per Magazine"
		Modifiables.NUMBER_OF_SCENES_TO_SPAWN:
			return "Projectiles Fired per Shot"
		Modifiables.POWER_LAUNCH_SPEED_MULT:
			return "Shot Power"
		Modifiables.RETAIN_WHEN_EMPTY:
			return "Keep when Empty"
		Modifiables.USE_AMMO:
			return "Needs Ammo to Shoot"
		#Modifiables.USE_FIRE_RATE:
			#return ""
		#Modifiables.USE_MAGAZINES:
			#return ""
		_:
			return "Call a Dev!"
			
func operation_to_display_string() -> String:
	match operation:
		Operations.MULTIPLY: return "x"
		Operations.ADD : return "+"
		Operations.SUBTRACT: return "-"
		Operations.SET : return "="
		Operations.SET_TRUE: return "="
		Operations.SET_FALSE: return "="
		_: return "%s" % operation

func operation_to_string() -> String:
	match operation:
		Operations.MULTIPLY: return "x"
		Operations.ADD : return "+"
		Operations.SUBTRACT: return "-"
		Operations.SET : return "="
		Operations.SET_TRUE: return "is true"
		Operations.SET_FALSE: return "is false"
		_: return "OPERATION %s" % operation

func _to_string() -> String:
	var parts:PackedStringArray = []
	if target_weapon_name:
		parts.push_back(target_weapon_name + ":")
	parts.push_back(get_property_key())
	parts.push_back(operation_to_string())

	var property_value_str:String = get_property_value_to_string()
	if property_value_str:
		parts.push_back(property_value_str)

	if projectile_mods:
		parts.push_back("with")
		for proj_mod in projectile_mods:
			parts.push_back(proj_mod.to_string())

	return " ".join(parts)

# Code constructors
func configure_and_apply(weapon_to_attach_to: Weapon, _property: Modifiables, _operation: Operations, _value:float) -> void:
	property = _property
	operation = _operation
	value = _value
	weapon_to_attach_to.apply_mod(self)

#region Savable

func serialize() -> Dictionary:
	var data:Dictionary = {}

	data["property"] = EnumUtils.enum_to_string(Modifiables, property)
	data["operation"] = EnumUtils.enum_to_string(Operations, operation)
	data["value"] = value
	data["name"] = target_weapon_name
	data["scene"] = target_weapon_scene_path
	data["projectiles"] = ModUtils.serialize_mod_array(projectile_mods)

	return data

static func deserialize(state: Dictionary) -> ModWeapon:
	if not state:
		return null
	
	var mod: ModWeapon = ModWeapon.new()

	mod.property = EnumUtils.enum_from_string(Modifiables, state.get("property", ""))
	mod.operation = EnumUtils.enum_from_string(Operations, state.get("operation", ""))
	mod.value = state.get("value", 0.0)
	mod.target_weapon_name = state.get("name", "")
	mod.target_weapon_scene_path = state.get("scene", "")
	mod.projectile_mods = ModUtils.deserialize_mod_array(
		state.get("projectiles", [] as Array[Dictionary]),
		[] as Array[ModProjectile],
		Callable(ModProjectile.deserialize)
	)

	return mod
#endregion
