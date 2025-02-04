class_name Terrain extends Node2D

@onready var overlap = $StaticBody2D/Overlap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	overlap.connect("area_entered", on_area_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_area_entered(area: Area2D):
	if area.owner is WeaponProjectile:
		# Destroy
		area.owner.destroy()
