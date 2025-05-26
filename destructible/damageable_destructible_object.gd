class_name DamageableDestructibleObject extends DestructibleObject

@export var starting_health:float = 100.0
var health: float = starting_health

@export var can_be_emp_charged:bool = false
@export var emp_conductivity_multiplier:float = 1.0 ## Incoming charge is multiplied by this figure
@export var emp_discharge_per_turn:float = 60.0 ## This much charge is subtracted each turn end.
var emp_charge:float = 0.0:
	set(value):
		emp_charge = maxf(value, 0.0)

## [b][i]Non-tank damageable object should define these signals as well as the take_damage function.[/i][/b]
## Something to note is that the WeaponProjectile class actually emits
## GameEvents.took_damage so this looks like a doubling, but I am following
## convention of the project in case existing systems (spawners) depend on this.
signal took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, amount: float)
## Simpler signal for use by other local nodes (i.e. a personal healthbar).
signal health_changed(current_health:float, damage_taken:float)
signal emp_charge_changed(current_total_charge:float)

func _ready() -> void:
	GameEvents.turn_ended.connect(_on_turn_ended)

func take_damage(instigatorController: Node2D, instigator: Node2D, damage_amount: float) -> void:
	var orig_health = health
	
	if is_zero_approx(damage_amount):
		print_debug("%s didn't take any actual damage" % [display_name])
		return
		
	health = maxf(health - damage_amount, 0.0)
	var actual_damage = orig_health - health
	
	print_debug("%s took %f damage; health=%f"
		% [display_name, damage_amount, health])
	
	took_damage.emit(self, instigatorController, instigator, actual_damage)
	health_changed.emit(health, actual_damage)

	if health == 0.0:
		delete()

func take_emp(instigatorController: Node2D, instigator: Node2D, charge:float) -> void:
	if not can_be_emp_charged: return
	var actual_charge = charge * emp_conductivity_multiplier
	emp_charge += actual_charge
	
	print_debug("%s took %f EMP charge; total=%f" % [ self.name, actual_charge, emp_charge])
	emp_charge_changed.emit(emp_charge)

func _on_turn_ended() -> void:
	if emp_charge > 0.0:
		emp_charge = maxf(emp_charge - emp_discharge_per_turn, 0.0)
		
