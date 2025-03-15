class_name Walls extends Node2D

@onready var playableArea = $PlayableArea
@onready var shape = $PlayableArea/CollisionShape2D
@export var warp_offset: float = 10

enum WallType {
	WARP, 
	ELASTIC
}

@export
var wall_mode = WallType.WARP

var bounds: Rect2;
var min_extent: Vector2
var max_extent: Vector2

var tracked_projectiles: Array[WeaponProjectile]

func _ready() -> void:
	# Opting for continuous checking once fired due to edge cases crossing boundary like the turret going through boundary
	GameEvents.projectile_fired.connect(_on_projectile_fired)

	bounds = shape.shape.get_rect()
	bounds = Rect2(shape.to_global(bounds.position), bounds.size)

	min_extent = Vector2(bounds.position.x, bounds.size.y)
	max_extent = Vector2(bounds.position.x + bounds.size.x, bounds.size.y)

func _physics_process(_delta: float) -> void:
	if !tracked_projectiles:
		return
	for projectile in tracked_projectiles:
		check_projectile_wall_interaction(projectile)
		
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
	var pos: Vector2 = projectile.global_position

	if(pos.x <= bounds.position.x):
		pos.x = bounds.position.x + bounds.size.x - warp_offset
		print_debug("Warp to right side %s -> %s" % [str(projectile.global_position), str(pos)])
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + warp_offset
		print_debug("Warp to left side %s -> %s" % [str(projectile.global_position), str(pos)])

	if pos.y >= bounds.position.y + bounds.size.y:
		print_debug("Hit bottom %s - destroying" % [str(pos)])
		#Delete projectile
		projectile.destroy()
	
	projectile.global_position = pos

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	print_debug("Wind(%s) - Tracking projectile fired - %s - %s" % [name, projectile.name, str(projectile.global_position)])
	tracked_projectiles.append(projectile)

	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind([projectile]))

# Bind arguments are passed as an array
func _on_projectile_destroyed(args: Array) -> void:
	var projectile: WeaponProjectile = args[0]

	print_debug("Wind(%s): Projectile Destroyed=%s" % [name, projectile.name])

	tracked_projectiles.erase(projectile)
