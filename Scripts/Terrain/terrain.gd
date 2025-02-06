class_name Terrain extends Node2D

@onready var overlap = $StaticBody2D/Overlap
@onready var terrainMesh = $StaticBody2D/Polygon2D
@onready var collisionMesh = $StaticBody2D/CollisionPolygon2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	overlap.connect("area_entered", on_area_entered)
	# Make sure the collision and visual polygon the same
	collisionMesh.polygon = terrainMesh.polygon
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_area_entered(area: Area2D):
	if area.owner is WeaponProjectile:
		# Destroy
		area.owner.destroy()

# Based on https://www.youtube.com/watch?v=FiKsyOLacwA
func clip(poly):
	# FIXME: Don't have to create a new polygon each time
	var offset_poly = Polygon2D.new()
	offset_poly.global_position = Vector2.ZERO
	## offset the polygon points to take into account the transformation
	var new_values = []
	for point in poly.polygon:
		new_values.append(point + poly.global_position)
	offset_poly.polygon = PackedVector2Array(new_values)
#	get_parent().add_child(offset_poly)
	var res = Geometry2D.clip_polygons(terrainMesh.polygon, offset_poly.polygon)

	terrainMesh.polygon = res[0]
	collisionMesh.set_deferred("polygon", res[0])
