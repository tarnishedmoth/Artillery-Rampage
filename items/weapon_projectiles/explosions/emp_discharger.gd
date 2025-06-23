class_name EMPDischarger extends Node
## This thing detects if its target has a charge above the threshold, and if so,
## spawns an effect spreading charge over a wide area like an electric explosion.

@export var target:Node2D ## Checks this node for emp charge level.
@export var activation_threshold:float = 60.0 ## Triggers only when above this charge threshold.
@export var activation_turn_cycle:int = 1 ## Triggers every this many turns, if above activation threshold.
@export var consume_charge:float = 60.0
@export var scene_to_spawn:PackedScene

var turn_counter:int = 0

func _ready() -> void:
	if not target or not "emp_charge" in target:
		push_error("Invalid configuration of EMP Discharger")
		queue_free()

	GameEvents.turn_started.connect(_on_turn_started)

func trigger() -> void:
	if scene_to_spawn:
		if scene_to_spawn.can_instantiate():
			var instance:Node2D = scene_to_spawn.instantiate()
			instance.global_position = target.global_position
			var container = SceneManager.get_current_level_root()
			if container is GameLevel:
				container = container.get_container()
			else:
				container = self

			container.add_child(instance)

			if instance is WeaponProjectile:
				instance.explode(null, true)

func _on_turn_started(player: TankController) -> void:
	turn_counter += 1
	if turn_counter % activation_turn_cycle != 0:
		return

	if target is Tank:
		if not target.controller == player:
			return

	if target.emp_charge > activation_threshold:
		trigger()
		if consume_charge != 0.0:
			target.emp_charge -= consume_charge
