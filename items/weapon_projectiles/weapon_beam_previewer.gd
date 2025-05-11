class_name WeaponBeamPreviewer extends WeaponProjectile

var speed = 8

func modulate_enabled() -> bool:
	return false

func is_affected_by_wind() -> bool:
	return false
