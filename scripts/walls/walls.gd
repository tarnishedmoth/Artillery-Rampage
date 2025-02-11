extends Node2D

@onready var playableArea = $PlayableArea
@onready var shape = $PlayableArea/CollisionShape2D
@export var warp_offset: float = 10

var bounds: Rect2;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	playableArea.connect("body_exited", on_body_exited)
	playableArea.connect("area_exited",on_area_exited)
	
	bounds = shape.shape.get_rect()
	bounds = Rect2(shape.to_global(bounds.position), bounds.size)
	# print(bounds)
		
func on_body_exited(body : Node2D):	
	pass
	
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
	elif pos.x >= bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x + warp_offset
	
	#if(pos.y <= bounds.position.y):
		# Do nothing - let it come back down
		#pos.y = bounds.position.y + bounds.size.y - warp_offset
	if pos.y >= bounds.position.y + bounds.size.y:
		#Delete projectile
		projectile.destroy()
		#pos.y = bounds.position.y + warp_offset
	
	projectile.global_position = pos
