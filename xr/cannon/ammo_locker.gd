class_name AmmoLocker extends Node3D

@export var ammo_scene: PackedScene
@export var dispense_marker: Node3D

func _on_interactable_area_button_button_pressed(button: Variant) -> void:
	if not ammo_scene:
		push_error("No ammo scene specified.")
		return
		
	var new_scene:PickableAmmo = ammo_scene.instantiate()
	add_child(new_scene)
	
	if dispense_marker:
		new_scene.global_transform = dispense_marker.global_transform
