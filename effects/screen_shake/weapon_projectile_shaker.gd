extends Node2D

@export var trauma_v_max_damage:Curve
@export var screen_shake_camera:ScreenShakeCamera2D

func _ready() -> void:
	if not screen_shake_camera:
		push_error("%s: Missing screen_shake_camera assignment" % name)
		return
	if not trauma_v_max_damage:
		push_error("%s: Missing trauma_v_max_damage" % name)
		return
		
	GameEvents.projectile_fired.connect(_on_projectile_fired)
	
func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	if projectile.is_in_group(&"TrajectoryPreviewer"): return ## Don't monitor these
	
	if OS.is_debug_build():
		print_debug("%s: projectile %s fired" % [name, projectile.name])
	projectile.completed_lifespan.connect(_on_projectile_exploded)

func _on_projectile_exploded(projectile: WeaponProjectile) -> void:
	var new_trauma:float = trauma_v_max_damage.sample(projectile.max_damage)
	screen_shake_camera.add_trauma(new_trauma)
	
	if OS.is_debug_build():
		print_debug("%s: projectile %s exploded - max_damage=%f; trauma_added=%f; total_trauma=%f" % 
			[name, projectile.name, projectile.max_damage, new_trauma, screen_shake_camera.trauma])
	
