extends Node2D

@export var rotors_rotate_speed:float = TAU ## Radians per second
@export var move_speed:float = 100.0
@export var hover_altitude:float = 140.0
@export var wait_range:float = 5.0 ## Copter will wait at landing sites for personnel within this radius.

@onready var copter = $PickupCopter
@onready var rotors = $PickupCopter/Rotors
@onready var sfx: AudioStreamPlayer2D = $PickupCopter/SFX
@onready var animation_tree: AnimationTree = $PickupCopter/AnimationTree
@onready var state_machine:AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]

var target:Vector2
var current_pickup:PersonnelUnit = null
var pickup_queue:Array

var _is_operating:bool = false
var _is_landed:bool = false

func _ready() -> void:
	GameEvents.personnel_requested_pickup.connect(_on_personnel_requested_pickup)
	hide()

func _process(delta: float) -> void:
	rotors.rotate(delta*rotors_rotate_speed)
	
func arrive() -> void:
	_is_operating = true
	global_position.y = hover_altitude
	state_machine.travel("Arriving")
	var animation_length = 6.0
	show()
	sfx.play(12.0)
	await get_tree().create_timer(animation_length).timeout
	check_queue()

func leave() -> void:
	_is_operating = false
	state_machine.travel("Leaving")
	var animation_length = 10.0
	await get_tree().create_timer(animation_length).timeout
	sfx.stop()
	hide()
	
func reposition() -> void: # Always in the air
	if current_pickup != null:
		var tween = create_tween()
		var distance = (current_pickup.global_position - global_position).length()
		var speed = move_speed
		tween.tween_property(self, "global_position:x", current_pickup.global_position.x, distance/speed)
		tween.tween_callback(_on_repositioned)
		print_debug("Repositioning")
	else: check_queue()
		
func land() -> void:
	print_debug("Landing")
	var tween = create_tween()
	var distance = (current_pickup.global_position - global_position).length()
	var speed = move_speed
	tween.tween_property(self, "global_position:y", current_pickup.global_position.y, distance/speed)
	tween.tween_callback(_on_landed)

func hover() -> void:
	print_debug("Hovering")
	var tween = create_tween()
	var distance = (current_pickup.global_position - global_position).length()
	var speed = move_speed
	tween.tween_property(self, "global_position:y", hover_altitude, distance/speed)
	tween.tween_callback(reposition)
	_is_landed = false
	
func wait() ->  void:
	print_debug("Waiting")
	await get_tree().create_timer(3.0).timeout
	check_queue()
	
func travel_to_pickup() -> void:
	if _is_landed:
		hover()
	else:
		reposition()
		
func check_queue() -> void:
	print_debug("Pickup Copter checking pickup queue")
	if current_pickup != null:
		print_debug("Pickup already on order for ",current_pickup)
		return
	else:
		var nearby:int
		for queued:Node2D in pickup_queue:
			var distance = (queued.global_position - global_position).length()
			if distance < wait_range:
				nearby += 1
				
		current_pickup = pickup_queue.pop_front()
		if current_pickup != null:
			if nearby > 0:
				wait()
				return
			else:
				travel_to_pickup()
		else:
			leave()
			
#region Private Methods
func _on_repositioned() -> void:
	if current_pickup != null:
		land()
	else:
		check_queue()
	
func _on_landed() -> void:
	_is_landed = true
	wait()

func _on_personnel_requested_pickup(unit: PersonnelUnit) -> void:
	pickup_queue.append(unit)
	if not _is_operating: arrive()

func _on_pickup_completed() -> void:
	check_queue()
#endregion
