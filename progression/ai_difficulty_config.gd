class_name AIDifficultyConfig extends Resource

## Maps original tank to a replacement appropriate for this story level
## Cannot use PackedScene as a dictionary key so use the resource_path of the original PackedScene instead
@export var ai_type_mappings: Dictionary[String, PackedScene] = {}
