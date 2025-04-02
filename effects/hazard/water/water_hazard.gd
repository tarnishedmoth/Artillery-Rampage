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

func _ready() -> void:
	_init_collision()
	
	overlap.body_entered.connect(_on_overlap_begin)
	overlap.body_exited.connect(_on_overlap_ended)
	GameEvents.turn_started.connect(_on_turn_started)

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
		
	print_debug("%s: Removing damageable=" % [name, damageable.name])
	_damageables.erase(damageable)
	_immediate_damage_queue.erase(damageable)
	
	print_debug("%s: Damageables(%d)=[%s]" % [name, _damageables.size(), ",".join(_damageables.map(func(x): return x.name))])

func _damage(damageable: Node) -> void:
	if !is_instance_valid(damageable):
		return

	# Only actually damage if center of damageable is inside the hazard
	var damage_bounds:Rect2 = _get_collision_rect_global()
	if !damage_bounds.has_point(damageable.global_position):
		print_debug("%s: center of %s is not inside the hazard, ignoring damage" % [name, damageable.name])
		return
	
	damageable.take_damage(damageable.owner, self, damage_per_turn)
	
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
	
