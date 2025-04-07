class_name StoryMapScene extends Control

@export var unknown_level_texture: Texture2D
@export var incomplete_level_material: Material

func _ready() -> void:
	# TODO: Update based on story state
	$Container/LevelNodesContainer/Level3.set_icon_texture(unknown_level_texture)
	$Container/LevelNodesContainer/Level2.set_icon_material(incomplete_level_material)


func _on_next_button_pressed() -> void:
	SceneManager.next_level()
