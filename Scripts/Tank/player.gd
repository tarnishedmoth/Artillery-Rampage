class_name Player extends Node2D

signal player_killed(player: Player)

@onready var tank = $Tank

@export var aim_speed_degs_per_sec = 45
@export var power_pct_per_sec = 30

@export var debug_controls:bool = false

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		
	if Input.is_action_pressed("aim_left"):
		aim(-delta)
	if Input.is_action_pressed("aim_right"):
		aim(delta)
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_pressed("power_increase"):
		set_power(delta * power_pct_per_sec)
	if Input.is_action_pressed("power_decrease"):
		set_power(-delta * power_pct_per_sec)
		
func aim(delta: float) -> void:
	if !can_aim : return
	
	tank.aim_delta(deg_to_rad(delta * aim_speed_degs_per_sec))
	
func set_power(delta: float) -> void:
	if !can_aim: return
	tank.set_power_delta(delta)
	
func shoot() -> void:
	if !can_shoot: return
	
	tank.shoot()
	
	if(!debug_controls):
		can_shoot = false
		can_aim = false


func _on_tank_tank_killed(tank: Tank, instigatorController: Node2D, weapon: WeaponProjectile) -> void:
	# player tank killed
	tank.kill()
	emit_signal("player_killed", self)
