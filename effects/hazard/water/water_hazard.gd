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

func _on_overlap_begin(body: PhysicsBody2D) -> void:
	print_debug("%s: body=%s entered" % [name, body.name])
	var damageable:Node = Groups.get_parent_in_group(body, Groups.Damageable)
	if not damageable:
		print_debug("%s - Ignoring non-damageable body=%s" % [name, body.name])
		return
		
	print_debug("%s: Adding damageable=" % [name, damageable.name])
	_damageables.push_back(damageable)
	
	print_debug("%s: Damageables(%d)=[%s]" % [name, _damageables.size(), ",".join(_damageables.map(func(x): return x.name))])
	
	if immediate_damage:
		_damage(damageable)
	
func _on_overlap_ended(body: PhysicsBody2D) -> void:
	print_debug("%s: body=%s exited" % [name, body.name])
	var damageable:Node = Groups.get_parent_in_group(body, Groups.Damageable)
	if not damageable:
		print_debug("%s - Ignoring non-damageable body=%s" % [name, body.name])
		return
		
	print_debug("%s: Removing damageable=" % [name, damageable.name])
	_damageables.erase(damageable)
	
	print_debug("%s: Damageables(%d)=[%s]" % [name, _damageables.size(), ",".join(_damageables.map(func(x): return x.name))])

func _damage(damageable: Node) -> void:
	if !is_instance_valid(damageable):
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
	_damage_if_in_set(controller.tank)
