extends Node2D

@export var starting_difficulty:Difficulty.DifficultyLevel = Difficulty.DifficultyLevel.HARD

func _enter_tree() -> void:
	Difficulty.current_difficulty = starting_difficulty
