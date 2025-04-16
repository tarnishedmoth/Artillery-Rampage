class_name WaterHazard extends Node2D

@onready var overlap:Area2D = $WaterOverlap
@onready var collision:CollisionShape2D = $WaterOverlap/CollisionShape2D
@onready var sprite: Sprite2D = $Water

@export_group("Damage")
@export_range(0, 1e9, 1, "or_greater")
var damage_per_turn:float = 10

@export_group("Damage")
@export
var immediate_damage:bool = true

var _damageables:Array[Node] = []

var _immediate_damage_queue:Array[Node] = []

## Frequencies for water shader - using prime numbers to lessen chance of wave cancellations
@export var wave_frequencies:PackedInt32Array = [11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59]
@export var wave_agitations:PackedInt32Array = [1, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67]
## Affects the amplitude of the waves as a fraction of the total height
## Min value is x and max value is y
@export var wave_pct_range:Vector2 = Vector2(0.01, 0.04)

## Affects how fast the waves move
## min value is x and max value is y
@export var wave_speed_range:Vector2 = Vector2(0.1, 0.3)

## Affects how choppy the waves appear
## min value is x and max value is y
@export var wave_choppiness_range:Vector2 = Vector2(0.0, 4.0)

var wind_updated:bool = false

func _ready() -> void:
	_init_collision()
	
	overlap.body_entered.connect(_on_overlap_begin)
	overlap.body_exited.connect(_on_overlap_ended)
	GameEvents.turn_started.connect(_on_turn_started)
	
	GameEvents.wind_updated.connect(_on_update_wind)
	
	# WaterHazard is higher sibling in GameLevel tree than Wind so our _ready will execute first
	if not wind_updated:
		for i in range(10):
			await get_tree().create_timer(0.1).timeout
			if wind_updated:
				break
			# TODO: Hack to get around error if access too soon
			if not SceneManager._current_level_root_node:
				continue
			var wind: Wind = SceneManager.get_current_level_root().wind
			if wind:
				_on_update_wind(wind)
				break

func _init_collision() -> void:
	var sprite_size: Vector2 = _get_sprite_size()
		
	collision.shape.size = sprite_size
	overlap.global_rotation = sprite.global_rotation
	overlap.global_position = sprite.global_position

func _get_sprite_size() -> Vector2:
	var sprite_bounds:Rect2 = sprite.get_rect()
	return sprite_bounds.size * sprite.scale

func _get_collision_rect_global() -> Rect2:
	var size: Vector2 = _get_sprite_size()
	var bounds:Rect2 = Rect2(-size * 0.5, size)
	return collision.global_transform * bounds

func _on_overlap_begin(body: PhysicsBody2D) -> void:
	print_debug("%s: body=%s entered" % [name, body.name])
	var damageable:Node = Groups.get_parent_in_group(body, Groups.Damageable)
	if not damageable:
		print_debug("%s - Ignoring non-damageable body=%s" % [name, body.name])
		return
	if damageable in _damageables:
		print_debug("%s - damageable=%s already in the damage set" % [name, damageable.name])
		return
		
	print_debug("%s: Adding damageable=%s" % [name, damageable.name])
	_damageables.push_back(damageable)
	
	print_debug("%s: Damageables(%d)=[%s]" % [name, _damageables.size(), ",".join(_damageables.map(func(x): return x.name))])
	
	if immediate_damage:
		_immediate_damage_queue.push_back(damageable)
	
func _on_overlap_ended(body: PhysicsBody2D) -> void:
	print_debug("%s: body=%s exited" % [name, body.name])
	var damageable:Node = Groups.get_parent_in_group(body, Groups.Damageable)
	if not damageable:
		print_debug("%s - Ignoring non-damageable body=%s" % [name, body.name])
		return
		
	print_debug("%s: Removing damageable=%s" % [name, damageable.name])
	_damageables.erase(damageable)
	_immediate_damage_queue.erase(damageable)
	
	print_debug("%s: Damageables(%d)=[%s]" % [name, _damageables.size(), ",".join(_damageables.map(func(x): return x.name))])

func _damage(damageable: Node) -> void:
	if !is_instance_valid(damageable):
		return

	# Only actually damage if center of damageable is inside the hazard
	var damage_bounds:Rect2 = _get_collision_rect_global()
	var damageable_pos:Vector2 = _get_damageable_position(damageable)
	if !damage_bounds.has_point(damageable_pos):
		print_debug("%s: center of %s is not inside the hazard, ignoring damage" % [name, damageable.name])
		return
	
	damageable.take_damage(damageable.owner, self, damage_per_turn)
	
func _get_damageable_position(damageable: Node) -> Vector2:
	# Need to get the position of the rigid body as that moves independently of its parent 
	# and so need to the correct position to apply damage
	for child in damageable.get_children():
		var rigid_body_child:RigidBody2D = child as RigidBody2D
		if rigid_body_child:
			return rigid_body_child.global_position
	return damageable.global_position
func _damage_all() -> void:
	for damageable in _damageables:
		_damage(damageable)

func _damage_if_in_set(node: Node) -> void:
	if node in _damageables:
		_damage(node)
		
func _on_turn_started(controller: TankController) -> void:
	print_debug("%s: TurnStarted - controller=%s" % [name, controller.name])
	
	# Damage any unit in immediate damage queue
	for damageable in _immediate_damage_queue:
		_damage(damageable)
		
	_immediate_damage_queue.clear()
	
	# Will damage again if just was damaged as we are starting a new turn
	_damage_if_in_set(controller.tank)
	
func _on_update_wind(wind_node: Wind) -> void:
	wind_updated = true
	
	var water_material:ShaderMaterial = sprite.material as ShaderMaterial
	
	if not water_material:
		push_warning("%s: _on_update_wind(%s) - No material on node, will not change parameters" % [name, wind_node.name])
		return
	
	var wind_range:float = maxf(wind_node.wind_max, 1.0)
	
	var speed:float = wind_node.wind.x
	var speed_sgn:float = signf(speed)
	var speed_abs:float = speed_sgn * speed
	var speed_alpha: float = speed_abs / wind_range
	
	var wave_pct:float = lerpf(wave_pct_range.x, wave_pct_range.y, speed_alpha)
	var wave_speed = -speed_sgn * lerpf(wave_speed_range.x, wave_speed_range.y, speed_alpha)
	
	var wave_frequency:float = _alpha_to_value(speed_alpha, wave_frequencies)
	var wave_agitation:float = _alpha_to_value(speed_alpha, wave_agitations)
	var wave_choppiness:float = lerpf(wave_choppiness_range.x, wave_choppiness_range.y, speed_alpha)
	
	water_material.set_shader_parameter(&"wave_speed", wave_speed)
	water_material.set_shader_parameter(&"wave_frequency", wave_frequency)
	water_material.set_shader_parameter(&"wave_pct", wave_pct)
	water_material.set_shader_parameter(&"wave_agitation", wave_agitation)
	water_material.set_shader_parameter(&"wave_choppiness", wave_choppiness)

func _alpha_to_value(alpha: float, array: PackedInt32Array) -> float:
	var index: int = clampi(roundi(alpha * (array.size() - 1)), 0, array.size() - 1)
	var value:float = float(array[index])
	return value
