extends Node2D

@onready var playableArea = $PlayableArea
@onready var shape = $PlayableArea/CollisionShape2D
@export var warp_offset: float = 10
enum WallType {
	WARP, 
	ELASTIC
}
var wall_mode = WallType.WARP
var bounds: Rect2;

var tracked_projectile: WeaponProjectile

func _ready() -> void:
	playableArea.connect("body_exited", on_body_exited)
	playableArea.connect("area_exited",on_area_exited)
	
	bounds = shape.shape.get_rect()
	bounds = Rect2(shape.to_global(bounds.position), bounds.size)
		
func on_body_exited(body : Node2D):
	if body is WeaponProjectile:
		check_projectile_wall_interaction(body)

func _physics_process(_delta: float) -> void:
	if !tracked_projectile:
		return
	check_projectile_wall_interaction(tracked_projectile)
	
func on_area_exited(area: Node2D):
	pass
		
#TODO: Implement Warp, elastic, accelerate, sticky, and none behaviors
func check_projectile_wall_interaction(projectile: WeaponProjectile):
	match wall_mode:
		WallType.WARP:
			projectile_warp(projectile)
		WallType.ELASTIC:
			projectile_elastic(projectile)
	
func projectile_elastic(projectile: WeaponProjectile):
	var pos = projectile.global_position
	var movement_dir : Vector2 = projectile.linear_velocity
	
	if(pos.x <= bounds.position.x):
		pos.x = bounds.position.x
		if(movement_dir.x < 0):
			movement_dir.x = -movement_dir.x
			projectile.linear_velocity = movement_dir
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + bounds.size.x
		if(movement_dir.x > 0):
			movement_dir.x = -movement_dir.x
			projectile.linear_velocity = movement_dir

func projectile_warp(projectile: WeaponProjectile):
	var pos = projectile.global_position
	if(pos.x <= bounds.position.x):
		pos.x = bounds.position.x + bounds.size.x - warp_offset
		print_debug("Warp to right side %s -> %s" % [str(projectile.global_position), str(pos)])
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + warp_offset
		print_debug("Warp to left side %s -> %s" % [str(projectile.global_position), str(pos)])

	if(pos.y <= bounds.position.y):
		# Need to monitor position of projectile
		tracked_projectile = projectile
		#pos.y = bounds.position.y + bounds.size.y - warp_offset
	else:
		tracked_projectile = null
		if pos.y >= bounds.position.y + bounds.size.y:
			print_debug("Hit bottom %s - destroying" % [str(pos)])
			#Delete projectile
			projectile.destroy()
	
	projectile.global_position = pos
