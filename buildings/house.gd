extends Node

@export var max_health:float = 100

@onready var health_label = $HealthLabel

var health: float

func _ready() -> void:
	health = max_health

#region Damage and Death
func take_damage(instigatorController: Node2D, instigator: Node2D, amount: float) -> void:
	var orig_health = health
	health = clampf(health - amount, 0, max_health)
	var actual_damage = orig_health - health
	
	if is_zero_approx(actual_damage):
		print("House " + get_parent().name + " didn't take any actual damage")
		return
	
	print("House " + get_parent().name + " took " + str(actual_damage) + " damage; health=" + str(health))
	
	health_label.text = str(health)
	
	if health <= 0:
		queue_free()
		
#endregion
