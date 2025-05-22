class_name DamageableDestructibleObject extends DestructibleObject

@export var starting_health:float = 100.0
var health: float = starting_health

## [b][i]Non-tank damageable object should define these signals as well as the take_damage function.[/i][/b]
## Something to note is that the WeaponProjectile class actually emits
## GameEvents.took_damage so this looks like a doubling, but I am following
## convention of the project in case existing systems (spawners) depend on this.
signal took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, amount: float)
## Simpler signal for use by other local nodes (i.e. a personal healthbar).
signal health_changed(current_health:float, damage_taken:float)

func take_damage(instigatorController: Node2D, instigator: Node2D, damage_amount: float) -> void:
	health = maxf(health - damage_amount, 0.0)
	
	if is_zero_approx(damage_amount):
		print_debug("%s didn't take any actual damage" % [display_name])
		return
	
	print_debug("%s took %f damage; health=%f"
		% [display_name, damage_amount, health])
	
	took_damage.emit(self, instigatorController, instigator, damage_amount)
	health_changed.emit(health, damage_amount)

	if health == 0.0:
		delete()
