class_name Circle

# Surpisingly, Godot has Rect2 with bounding utilities but not Sphere/Circle
var radius: float
var center: Vector2

func _init(in_radius: float = 0.0, in_center: Vector2 = Vector2()) -> void:
	self.radius = in_radius
	self.center = in_center
	
func scale(in_scale: float = 1.0) -> Circle:
	radius *= in_scale
	return self

static func create_from_points(points: PackedVector2Array) -> Circle:
	if points.is_empty():
		return Circle.new()
		
	 # Calculate the centroid
	var centroid := Vector2()
	for point in points:
		centroid += point
	centroid /= points.size()

	# Find the maximum distance from the centroid to the points
	var max_distance_sq = 0.0
	for point in points:
		var distance_sq := centroid.distance_squared_to(point)
		if distance_sq > max_distance_sq:
			max_distance_sq = distance_sq

	return Circle.new(sqrt(max_distance_sq), centroid)

func contains(point: Vector2) -> bool:
	return center.distance_squared_to(point) <= radius * radius
