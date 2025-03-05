extends StaticBody2D

@onready var _floorCollision: CollisionShape2D = $FloorCollision
@onready var _overlapCollision: CollisionShape2D = $FloorOverlap/FloorCollisionOverlap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_overlapCollision.set_deferred("shape", _floorCollision.shape)
