extends WeaponModes

## Uses Modes array entries as Ints, to be the number of bounces.

func _ready() -> void:
	super()
	parent.projectile_spawned.connect(_on_weapon_bouncing_ball_projectile_spawned)
	
	display.label = "Bounces"
	display.value = _get_bounces_as_string()
	
func _on_weapon_mode_change(mode: int) -> void:
	super(mode)
	display.value = _get_bounces_as_string()
	
func _get_bounces_as_string() -> String:
	return str(modes[current_mode])

## We apply the setting to the projectile when it's spawned.
func _on_weapon_bouncing_ball_projectile_spawned(projectile_root_node: WeaponProjectile) -> void:
	var impact_counter = projectile_root_node.get_node("ImpactCounter")
	impact_counter.count_to_arm = modes[current_mode]
