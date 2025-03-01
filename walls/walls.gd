extends Node2D

@onready var playableArea = $PlayableArea
@onready var shape = $PlayableArea/CollisionShape2D
@export var warp_offset: float = 10

var bounds: Rect2;

var tracked_projectile: WeaponProjectile

func _ready() -> void:
	playableArea.connect("body_exited", on_body_exited)
	playableArea.connect("area_exited",on_area_exited)
	
	bounds = shape.shape.get_rect()
	bounds = Rect2(shape.to_global(bounds.position), bounds.size)
		
func on_body_exited(_body : Node2D):	
	pass

func _physics_process(_delta: float) -> void:
	if !tracked_projectile:
		return
	projectile_warp(tracked_projectile)
	
func on_area_exited(area: Node2D):
	if area.owner is WeaponProjectile:
		handle_projectile_wall_collision(area.owner)
		
		
#TODO: Implement Warp, elastic, accelerate, sticky, and none behaviors
func handle_projectile_wall_collision(projectile: WeaponProjectile):
	projectile_warp(projectile)
	
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
