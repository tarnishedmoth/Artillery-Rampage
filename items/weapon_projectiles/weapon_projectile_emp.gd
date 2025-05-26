extends WeaponProjectile

@export var charge_to_apply:float = 100.0

func damage_damageable_node(damageable: Node, instigator, projectile:WeaponProjectile, damage:float) -> void:
	if "take_emp" in damageable:
		print_debug("Applying EMP")
		damageable.take_emp(instigator, projectile, charge_to_apply)
	super(damageable, instigator, projectile, damage)
