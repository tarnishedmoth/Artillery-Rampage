class_name RigidBodyFracturedMesh extends Node2D

var pieces: Array[RigidMeshBody] = []

func _ready() -> void:
	for child in get_children():
		if child is RigidMeshBody:
			pieces.push_back(child)
	print_debug("%s: Found %d prototype RigidBody2D pieces" % [name, pieces.size()])
