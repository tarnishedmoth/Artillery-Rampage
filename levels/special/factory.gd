extends Node2D

## Spawn artillery units to start the match, then every so frequently during match
## maybe with a curve or an array of turn count targets.
## When artillery is spawned, it joins a queue.
## This queue is moved by the "conveyor" once length per turn.
## Once an artillery meets the end, it takes turns.
## If there is already an artillery at the end, artillery can queue behind it
## and will immediately deploy when the end artillery dies, effectively replacing it.

signal conveyor_advanced
signal artillery_spawned

@export var schedule:Dictionary[int,int] ## Turn Count, Number to Spawn
@export var damageable_components:Array[DestructibleObject] # Maybe?
@export var conveyor_length:int = 4
var conveyor_slot_x_offset:float = 50.0
var conveyor_move_duration:float = 1.0
var conveyor_slots:Array[ConveyorSlot]

var turn_counter:int = 0

@onready var spawnpoint: Marker2D = %Spawnpoint
@onready var game_level:GameLevel = get_parent()


func _ready() -> void:
	%RoundDirector.directed_by_external_script = true
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
		
	call_deferred("check_turn")

func try_spawn_new_artillery() -> bool:
	var slot = conveyor_slots[0]
	if slot.is_occupied:
		print_debug("Force advancing conveyor.")
		advance_conveyor()
		await conveyor_advanced
		if slot.is_occupied:
			print_debug("Slot ", slot.number, " still occupied. (Belt is full?) Cancelling spawn.")
			return false # Belt is full
		
	## Something with how the decoupled tankBody physics object results in
	## strange positional offsets so we have to set it after we spawn...
	slot.occupant = game_level.spawner.spawn_unit(Vector2(0,0), true, self)
	slot.occupant.global_position = slot.global_position
	slot.physics_body.freeze = true
	
	artillery_spawned.emit()
	return true
	
func check_turn() -> void:
	#if turn_counter in schedule:
	if schedule.has(turn_counter):
		for to_spawn in schedule[turn_counter]:
			print_debug("Trying spawn ", to_spawn+1, " of ", schedule[turn_counter])
			var did_spawn = await try_spawn_new_artillery()
			
func advance_conveyor() -> void:
	var slot = conveyor_slots.back().number
	while slot >= 0:
		print_debug("Advancing slot ", slot)
		if conveyor_slots[slot].is_occupied:
			if slot+1 < conveyor_slots.size():
				if conveyor_slots[slot+1].is_occupied:
					print_debug("Next slot is full, cancelling advance.")
					return
				var move_tween = create_tween()
				var next_position:Vector2 = conveyor_slots[slot+1].global_position
				#conveyor_slots[slot].occupant.global_position = next_position
				move_tween.tween_property(conveyor_slots[slot].occupant, "global_position", next_position, conveyor_move_duration).set_trans(Tween.TRANS_SPRING)
				#move_tween.tween_callback(_reassign_slots.bind(conveyor_slots[slot], conveyor_slots[slot+1]))
				move_tween.tween_callback(conveyor_advanced.emit)
				_reassign_slots(conveyor_slots[slot], conveyor_slots[slot+1])
			else:
				#End of the line
				activate_artillery(conveyor_slots[slot].occupant)
				conveyor_advanced.emit()
		else:
			# Empty slot
			pass
		slot -= 1
		continue
		
func activate_artillery(artillery:TankController) -> void:
	print_debug("Activating artillery ", artillery.name)
	game_level.activate_tank_controller(artillery) # Gives it turns
	set_deferred("artillery.tank.tankBody:freeze", false)
	
func _reassign_slots(from:ConveyorSlot, to:ConveyorSlot) -> void:
	if to.is_occupied:
		print_debug("Reassigning to full slot!")
	to.occupant = from.occupant
	from.occupant = null
	
func defeated() -> void:
	#End the round
	#TODO would be cool if the factory exploded first
	%RoundDirector.end_round()

func _on_turn_ended(_tank:TankController) -> void:
	#turn_counter += 1
	set_deferred("turn_counter", turn_counter+1) # Maybe bugfix
	advance_conveyor()
	check_turn()

func _on_component_destroyed(component) -> void:
	damageable_components.erase(component)
	if damageable_components.is_empty():
		defeated()

class ConveyorSlot:
	var number:int
	var occupant:TankController
	var physics_body:TankBody:
		get:
			if is_occupied:
				return occupant.tank.tankBody
			else:
				return null
	var is_occupied:bool:
		get: return true if occupant else false
	var global_position:Vector2
