class_name Walls extends Node2D

@onready var playableArea = $PlayableArea
@onready var shape = $PlayableArea/CollisionShape2D
@export var warp_offset: float = 10
@export var elastic_min_velocity_threshold:float = 100

enum WallType {
	WARP, 
	ELASTIC
}

enum WallInteractionLocation {
	Top,
	Bottom,
	Right,
	Left
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
			GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Left)
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + bounds.size.x
		if(movement_dir.x > 0):
			movement_dir.x = -movement_dir.x
			projectile.linear_velocity = movement_dir
			GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Right)
			
	#Top
	if pos.y <= bounds.position.y:
		pos.y = bounds.position.y
		if movement_dir.y < 0:
			movement_dir.y = -movement_dir.y
			projectile.linear_velocity = movement_dir
			GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Top)
	#Bottom
	elif pos.y >= bounds.position.y + bounds.size.y:
		pos.y = bounds.position.y + bounds.size.y
		if movement_dir.y > 0:
			movement_dir.y = -movement_dir.y
			projectile.linear_velocity = movement_dir
			GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Bottom)
			
		# if velocity small on bottom then we should delete
		var speed:float = projectile.linear_velocity.length_squared()
		if speed <= elastic_min_velocity_threshold * elastic_min_velocity_threshold:
			print_debug("Hit bottom %s with small velocity=%s - destroying" % [str(pos), projectile.linear_velocity])
			#Delete projectile
			projectile.destroy()
		else:
			print_debug("Hit bottom %s with velocity=%s; speed=%f above threshold" % [str(pos), projectile.linear_velocity, sqrt(speed)])
		
func projectile_warp(projectile: WeaponProjectile):
	var pos: Vector2 = projectile.global_position

	if(pos.x <= bounds.position.x):
		pos.x = bounds.position.x + bounds.size.x - warp_offset
		print_debug("Warp to right side %s -> %s" % [str(projectile.global_position), str(pos)])
		GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Left)
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + warp_offset
		print_debug("Warp to left side %s -> %s" % [str(projectile.global_position), str(pos)])
		GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Right)

	if pos.y >= bounds.position.y + bounds.size.y:
		print_debug("Hit bottom %s - destroying" % [str(pos)])
		GameEvents.wall_interaction.emit(self, projectile, WallInteractionLocation.Bottom)
		#Delete projectile
		projectile.destroy()
	
	projectile.global_position = pos

func _on_projectile_fired(projectile: WeaponProjectile) -> void:
	print_debug("Wind(%s) - Tracking projectile fired - %s - %s" % [name, projectile.name, str(projectile.global_position)])
	tracked_projectiles.append(projectile)

	# Need to bind the extra projectile argument to connect
	projectile.completed_lifespan.connect(_on_projectile_destroyed.bind(projectile))

# Bind arguments are passed as an array
func _on_projectile_destroyed(projectile: WeaponProjectile) -> void:
	print_debug("Wind(%s): Projectile Destroyed=%s" % [name, projectile.name])

	tracked_projectiles.erase(projectile)
