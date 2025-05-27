extends Node2D

@export var starting_difficulty:Difficulty.DifficultyLevel = Difficulty.DifficultyLevel.HARD

func _enter_tree() -> void:
	# Need to do this early so that artillery spawner events don't happen first
	_update_difficulty()

func _ready() -> void:
	# Override save state set in SaveManager ready
	_update_difficulty()
	
func _update_difficulty() -> void:
	Difficulty.current_difficulty = starting_difficulty
