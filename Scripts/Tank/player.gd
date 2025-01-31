class_name Player extends Node2D

@onready var tank = $Tank

@export var aim_speed_degs_per_sec = 45

var can_shoot: bool = false
var can_aim: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called at the start of a turn
# This will be a method available on all "tank controller" classes
# like the player or the AI
func begin_turn():
	can_shoot = true
	can_aim = true

# TODO: handle power set input

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("aim_left"):
		aim(-delta)
	if Input.is_action_pressed("aim_right"):
		aim(delta)
	if Input.is_action_pressed("shoot"):
		shoot()
		
func aim(delta: float) -> void:
	if !can_aim : return
	
	tank.aim_delta(deg_to_rad(delta * aim_speed_degs_per_sec))
	
func shoot() -> void:
	if !can_shoot: return
	
	can_aim = false
	tank.shoot()
	can_shoot = false
