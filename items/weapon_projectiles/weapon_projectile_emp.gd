extends WeaponProjectile

@export var charge_to_apply:float = 100.0

func damage_damageable_node(damageable_node: Node, damage:float) -> void:
	if "take_emp" in damageable_node:
		print_debug("Applying EMP")
		damageable_node.take_emp(owner_tank, self, charge_to_apply)
	super(damageable_node, damage)
