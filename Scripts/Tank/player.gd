class_name Player extends Node2D

@onready var tank = $Tank

@export var aim_speed_degs_per_sec = 45

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("aim_left"):
		aim(-delta)
	if Input.is_action_pressed("aim_right"):
		aim(delta)
		
func aim(delta: float) -> void:
	tank.aim_delta(deg_to_rad(delta * aim_speed_degs_per_sec))
