class_name Player extends TankController

@warning_ignore("unused_signal")
signal player_killed(player: Player)

@onready var _tank = $Tank

@export var aim_speed_degs_per_sec = 45
@export var power_pct_per_sec = 30
var input_modifier:float = 1.0

@export var debug_controls:bool = false

var can_shoot: bool = false
var can_aim: bool = false

func _ready() -> void:
	super._ready()

	PlayerUpgrades.acquired_upgrade.connect(_on_acquired_upgrade)

func on_tank_added() -> void:
	super.on_tank_added()
	
	tank.tank_killed.connect(_on_tank_tank_killed)
	
func begin_round() -> void:
	super.begin_round()
	
	# Make sure weapon states are up to date before applying upgrades
	# Weapon applies any mods on it when it is added to the tree but we are adding the mods and applying after
	# so there is no "double application" of weapon mods
	load_and_apply_upgrades()
	
# Called at the start of a turn
# This will be a method available on all "tank controller" classes
# like the player or the AI
func begin_turn():
	super.begin_turn()
	
	popup_message("Your Turn", PopupNotification.PulsePresets.Three, 4.5)
	
	can_shoot = true
	can_aim = true

func _get_tank():
	return _tank
	
func _do_replace_tank(new_tank:Tank) -> void:
	_tank = new_tank
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		shoot()
	if event.is_action_pressed("cycle_prev_weapon"):
		if can_shoot: tank.equip_prev_weapon()
	if event.is_action_pressed("cycle_next_weapon"):
		if can_shoot: tank.equip_next_weapon()
	if event.is_action_pressed("cycle_weapon_mode"):
		if can_shoot: tank.next_weapon_mode()
	if event.is_action_pressed("fine_control"):
		input_modifier = 0.15
	elif event.is_action_released("fine_control"):
		input_modifier = 1.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("aim_left"):
		aim(-delta*input_modifier)
	if Input.is_action_pressed("aim_right"):
		aim(delta*input_modifier)
	#if Input.is_action_just_pressed("shoot"):
		#shoot()
	if Input.is_action_pressed("power_increase"):
		set_power(delta*input_modifier * power_pct_per_sec)
	if Input.is_action_pressed("power_decrease"):
		set_power(-delta*input_modifier * power_pct_per_sec)
	#if Input.is_action_just_pressed("cycle_next_weapon"):
		#if can_shoot: tank.equip_next_weapon()
	#if Input.is_action_just_pressed("cycle_weapon_mode"):
		#if can_shoot: tank.next_weapon_mode()
		
func aim(delta: float) -> void:
	if !can_aim : return
	
	tank.aim_delta(deg_to_rad(delta * aim_speed_degs_per_sec))
	
func set_power(delta: float) -> void:
	if !can_aim: return
	tank.set_power_delta(delta)
	
func shoot() -> void:
	if !can_shoot: return
	
	var did_shoot = tank.shoot()
	if did_shoot and not debug_controls:
		can_shoot = false
		can_aim = false
	else:
		# Didn't shoot.
		# Should be safe to assume you're out of ammo.
		popup_message("Out of ammo!", PopupNotification.PulsePresets.Two, 1.75)
		pass
	
func load_and_apply_upgrades() -> void:
	PlayerUpgrades.apply_all_upgrades(get_weapons())
		
func load_new_upgrade(upgrade:ModBundle) -> void:
	upgrade.apply_all_mods(get_weapons())

@warning_ignore("unused_parameter")
func _on_tank_tank_killed(tank_unit: Tank, instigatorController: Node2D, instigator: Node2D) -> void:
	# player tank killed
	tank_unit.kill()
	player_killed.emit(self)

func _on_acquired_upgrade(bundle: ModBundle) -> void:
	load_new_upgrade(bundle)

func _on_trajectory_previewer_timeout() -> void:
	if UserOptions.show_assist_trajectory_preview and can_shoot:
		tank.visualize_trajectory()
