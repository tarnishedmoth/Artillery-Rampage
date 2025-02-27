class_name Weapon extends Node2D
## To use: attach script to a Node2D and configure in the Inspector panel.
## Contains functionality for ammo based weapons, magazines, fire rate (cycling), and reloading.
## Also TODO provide support for continuous fire weapons like a laser beam etc.
## If provided Marker2D nodes in the barrels array, shots will spawn from each point, in order.
## Otherwise the self forward vector is used.

#enum WeaponType{}
@export var scene_to_spawn: PackedScene ## This is the projectile or shoot effect.
@export var parent_tank: Tank ## Right now, the tank script has methods we need.
@export var display_name: String ## Not implemented

@export_category("Behavior")
@export var fires_continuously: bool = false ## Continuous-fire weapons don't use fire rate.
@export var fire_rate: float = 1.0 ## Rate of fire per second. 4.0 would fire once every quarter-second.
@export var fire_velocity: float = 10.0 ## Initial speed of the projectile.

@export_category("Ammo")
@export var use_ammo: bool = false ## Whether to check and track ammo.
@export var current_ammo: int = 16 ## Starting ammo.
@export var ammo_used_per_shot: int = 1.0
@export var use_magazines: bool = false
@export var magazines: int = 3
@export var magazine_capacity: int = 16
@export var reload_delay_time: float = 2.0 ## Seconds it takes to reload a mag.

## Sound Effects
@export_category("Sounds")
@export var sfx_fire: AudioStreamPlayer2D
@export var sfx_dry_fire: AudioStreamPlayer2D
@export var sfx_reload: AudioStreamPlayer2D
@export var sfx_equip: AudioStreamPlayer2D
@export var sfx_unequip: AudioStreamPlayer2D
@export var sfx_idle: AudioStreamPlayer2D

var is_reloading: bool = false
var is_cycling: bool = false
var is_equipped: bool = false

@export var barrels: Array[Marker2D] = []
var barrels_sfx_fire: Array[AudioStreamPlayer2D] = []
var current_barrel: int = 0

@onready var parent = get_parent()
@onready var sounds = [
		sfx_fire,
		sfx_dry_fire,
		sfx_reload,
		sfx_equip,
		sfx_unequip,
		sfx_idle
	]

func _ready() -> void:
	configure_barrels()
	reload()
	
func equip() -> void:
	if not is_equipped:
		is_equipped = true
		if sfx_equip: sfx_equip.play()
		if sfx_idle: sfx_idle.play()
	#else: print("Tried to equip already equipped!")
	
func unequip() -> void:
	if is_equipped:
		is_equipped = false
		if sfx_unequip: sfx_unequip.play()
		if sfx_idle: sfx_idle.stop()
	#else: print("Tried to unequip already unequipped!")

func shoot(power:float = fire_velocity) -> void:
	if not is_equipped: return
	if is_cycling:
		return
	if is_reloading:
		if sfx_dry_fire: sfx_dry_fire.play()
		cycle() ## To PUNISH them...
		return
	if use_magazines == true && current_ammo <= 0:
		if sfx_dry_fire: sfx_dry_fire.play()
		#EventBus.weapon_failed_fired.emit()
		cycle()
		return ## We can't shoot.
		
	if not fires_continuously:
		if not barrels_sfx_fire.is_empty: barrels_sfx_fire[current_barrel].play()
		spawn_projectile(power)
		cycle()
		#GameEvents.weapon_fired.emit(self) ## TODO This signal wants a WeaponProjectile. Could integrate this later.
	else:
		## Alternative handling for continuous weapons
		pass
		
	if use_magazines: current_ammo -= 1
	
func reload(immediate: bool = false) -> void:
	if not is_equipped: return
	if is_reloading: return
	if use_magazines:
		is_reloading = true
		if not immediate: ## Instant reloading
			await get_tree().create_timer(reload_delay_time).timeout ## Reload Timer
		current_ammo = magazine_capacity ## Reset ammo
	else:
		pass
	is_reloading = false ## Finished reloading.
	if sfx_reload: sfx_reload.play() ## Trigger the SFX to play
		
func cycle() -> void:
	is_cycling = true
	await get_tree().create_timer(1.0/fire_rate).timeout
	current_barrel += 1
	if current_barrel+1 > barrels.size():
		current_barrel = 0
	is_cycling = false
	
func spawn_projectile(power: float = fire_velocity) -> void:
	var barrel = barrels[current_barrel]
	if scene_to_spawn:
		var new_shot = scene_to_spawn.instantiate() as Node2D
		var container = parent_tank.get_fired_weapon_container() ## TODO Refactor
		
		if new_shot is WeaponProjectile: new_shot.owner_tank = parent_tank
		new_shot.global_transform = barrel.global_transform
		var direction = barrel.global_rotation - PI/2
		var velocity = Vector2(power, 0.0)
		new_shot.linear_velocity = velocity.rotated(direction)
		container.add_child(new_shot)
		print("Shot fired with ", velocity, " at ", direction)

func configure_barrels() -> void:
	current_barrel = 0
	barrels_sfx_fire.clear()
	#print_debug(display_name," found ", barrels.size()," barrels.")
	if barrels.size() == 0:
		var new_marker_2d = Marker2D.new()
		add_child(new_marker_2d)
		barrels.append(new_marker_2d) ## So we can access our own basis data.
		## Typically if you're shooting from this spot you're inside of your own tank, and it will just instantly collide.
	
	for i in barrels:
		if sfx_fire: ## Set up audio stream players at the barrel points.
			var new_fire_sfx = sfx_fire.duplicate()
			add_child(new_fire_sfx)
			barrels_sfx_fire.append(new_fire_sfx)

func stop_all_sounds(only_looping: bool = true) -> void:
	for s: AudioStreamPlayer2D in sounds:
		#if it's a looping sound...
		if s.playing: s.stop()
