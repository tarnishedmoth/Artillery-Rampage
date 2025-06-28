class_name DestructibleRigidMeshBody extends RigidMeshBody

func damage(_projectile: WeaponPhysicsContainer, _contact_point: Vector2, _poly_scale: Vector2 = Vector2(1,1)):
	delete(false)
