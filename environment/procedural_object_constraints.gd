class_name ProceduralObjectContraints extends Resource

@export var scene:PackedScene

## Default spacing to other objects
@export_range(0, 1e9, 0.1, "or_greater") var min_spacing:float

## Min and max count of objects to spawn
@export var count:Vector2i

## max slant that this object can spawn on
@export_range(0, 90, 1.0) var max_slant_angle_deg: float = 10.0

## Min spacing to other objects
@export var adjacent_constraints: Dictionary[PackedScene, float] = {}
