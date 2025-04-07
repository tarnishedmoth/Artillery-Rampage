class_name StoryLevelNode extends Control

@onready var icon: Sprite2D = $Icon
@onready var label:Label = $Label

@onready var left_edge:Marker2D = $LeftEdge
@onready var right_edge:Marker2D = $RightEdge

func set_label(name: StringName) -> void:
	label.text = name
	
func set_icon_texture(texture: Texture2D) -> void:
	icon.texture = texture

func set_icon_material(material: Material) -> void:
	icon.material = material
