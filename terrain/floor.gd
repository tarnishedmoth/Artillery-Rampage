class_name WorldFloor extends StaticBody2D

@onready var _floorCollision: CollisionShape2D = $FloorCollision
@onready var _overlapCollision: CollisionShape2D = $FloorOverlap/FloorCollisionOverlap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_overlapCollision.set_deferred("shape", _floorCollision.shape)
	_overlapCollision.global_position = _floorCollision.global_position
