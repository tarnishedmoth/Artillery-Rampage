class_name RubbleChunksSpawner extends Node

@export var max_lifetime: float = 30.0

@onready var rubble_container:Node = $RubbleSpawnContainer
@onready var rubble_prototypes_container = $RubblePrototypes

var rubble_prototypes:Array[RigidMeshBody] = []

func _ready() -> void:
	_extract_rubble_prototypes()
	
func _exit_tree():
	for prototype in rubble_prototypes:
		if is_instance_valid(prototype):
			prototype.queue_free()
	
func _extract_rubble_prototypes() -> void:
	for child in rubble_prototypes_container.get_children():
		if child is RigidMeshBody:
			rubble_prototypes.append(child)
			rubble_prototypes_container.remove_child(child)
		else:
			push_warning("%s - RubblePrototypes contains a non-RigidMeshBody node %s" % [name, child.name])
			child.queue_free()
			
	print_debug("%s - Found %d rubble prototypes" % [name, rubble_prototypes.size()])
