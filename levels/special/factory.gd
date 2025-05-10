extends Node2D

## Spawn artillery units to start the match, then every so frequently during match
## maybe with a curve or an array of turn count targets.
## When artillery is spawned, it joins a queue.
## This queue is moved by the "conveyor" once length per turn.
## Once an artillery meets the end, it takes turns.
## If there is already an artillery at the end, artillery can queue behind it
## and will immediately deploy when the end artillery dies, effectively replacing it.

@export var schedule:Dictionary[int,int] ## Turn Count, Number to Spawn
@export var damageable_components:Array[DestructibleObject] # Maybe?
@export var conveyor_length:int = 4
var conveyor_slot_x_offset:float = 50.0
var conveyor_move_duration:float = 1.0
var conveyor_slots:Array[ConveyorSlot]

var turn_counter:int = 0

@onready var spawnpoint: Marker2D = %Spawnpoint
var game_level:GameLevel:
	get: return get_parent() # GameLevel


func _ready() -> void:
	GameEvents.turn_ended.connect(_on_turn_ended) # For turn based logic
	
	for component in damageable_components: # Observe the components that the player must destroy to kill the factory.
		component.destroyed.connect(_on_component_destroyed)
		
	for iterator in conveyor_length:
		var new_slot = ConveyorSlot.new()
		new_slot.number = iterator
		new_slot.global_position = (
			spawnpoint.global_position - Vector2(conveyor_slot_x_offset * new_slot.number, 0.0) # Leftward
			)
		conveyor_slots.append(new_slot)
		
	check_turn()

func spawn_new_artillery() -> void:
	var artillery:TankController
	# TODO Make the artillery
	
func check_turn() -> void:
	if turn_counter in schedule:
		for to_spawn in schedule[turn_counter]:
			spawn_new_artillery()
			
func advance_conveyor() -> void:
	for slot in conveyor_slots.size():
		if conveyor_slots[slot].is_occupied:
			var move_tween = create_tween()
			if conveyor_slots[slot+1] != null:
				var next_position:Vector2 = conveyor_slots[slot+1].global_position
				move_tween.tween_property(conveyor_slots[slot].occupant, "global_position", next_position, conveyor_move_duration).set_trans(Tween.TRANS_SINE)
				move_tween.tween_callback(_reassign_slots.bind(conveyor_slots[slot], conveyor_slots[slot+1]))
			else:
				#End of the line
				activate_artillery(conveyor_slots[slot].occupant)
				
func _reassign_slots(from:ConveyorSlot, to:ConveyorSlot) -> void:
	to.occupant = from.occupant
	from.occupant = null
	
func activate_artillery(artillery:TankController) -> void:
	game_level.setup_new_unit(artillery) # Gives it turns
	
func defeated() -> void:
	#End the round
	pass

func _on_turn_ended() -> void:
	turn_counter += 1
	advance_conveyor()
	check_turn()

func _on_component_destroyed(component) -> void:
	damageable_components.erase(component)
	if damageable_components.is_empty():
		defeated()

class ConveyorSlot:
	var number:int
	var occupant:TankController
	var is_occupied:bool:
		get: return true if occupant else false
	var global_position:Vector2
