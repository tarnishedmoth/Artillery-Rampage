class_name ShatterPrototypePieces extends ShatterStrategy

var _prototype_pieces:Array[Polygon2D] = []

@export
var rigid_body_mesh_scene: PackedScene

func _ready() -> void:
	for child in get_children():
		if child is Polygon2D:
			_prototype_pieces.push_back(child)
	print_debug("%s: Found %d prototype Polygon2D pieces" % [name, _prototype_pieces.size()])

func shatter(poly: PackedVector2Array, min_area: float, max_area: float) -> Array[PackedVector2Array]:
	# TODO: This should be the minimum poly piece in the prototype list
	if poly.size() < 3:
		return []
		
	var poly_area:float = TerrainUtils.calculate_polygon_area(poly)
	
	# TODO: Need to determine how to offset the prototype pieces to correct position per poly array
	# Instantiate the rigid body mesh scene for each selected prototype piece and copy over the init poly 
	return []
