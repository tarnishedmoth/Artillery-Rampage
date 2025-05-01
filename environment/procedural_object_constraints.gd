class_name ProceduralObjectContraints extends Resource

@export var scene:PackedScene

@export_range(0, 1e9, 1, "or_greater") var min_spacing:float
@export var count:Vector2i

@export_range(0, 90, 1.0) var max_slant_angle_deg: float = 10.0
@export_range(-100, 100) var spawn_y_offset: float = -10.0

# Min spacing between other objects
@export var adjacent_constraints: Dictionary[PackedScene, float] = {}
