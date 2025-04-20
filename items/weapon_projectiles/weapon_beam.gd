class_name WeaponBeam extends WeaponProjectile

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	$PhysicsShape.position.x += 2
	$PhysicsShape.scale.x += 4
	$Destructible.position.x += 2
	$Destructible.scale.x += 4
	$BeamSprite.position.x += 2
	$BeamSprite.scale.y = $PhysicsShape.scale.x
