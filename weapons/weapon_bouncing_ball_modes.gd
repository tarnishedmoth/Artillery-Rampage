extends Node

@export var number_of_bounces: Array[int]

@onready var parent: Weapon = get_parent()

var mode:int = 0

func _ready() -> void:
	parent.modes_total = number_of_bounces.size()


func _on_weapon_bouncing_ball_projectile_spawned(projectile_root_node: WeaponProjectile) -> void:
	var impact_counter = projectile_root_node.get_node("ImpactCounter")
	impact_counter.count_to_arm = number_of_bounces[mode]

func _on_weapon_bouncing_ball_mode_change(current_mode: int) -> void:
	#TODO Update the UI
	mode = current_mode
	print_debug("Bounces set to ", number_of_bounces[current_mode])
	pass
