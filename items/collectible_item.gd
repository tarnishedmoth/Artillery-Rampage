class_name CollectibleItem extends Area2D

#region-- signals
signal collected()
#endregion

#region--Variables
# statics
# Enums
# constants
# @exports
@export var sfx_collected:AudioStreamPlayer2D
@export var sfx_glint:AudioStreamPlayer2D
# public
# _private
# @onready
#endregion


#region--Virtuals
#func _init() -> void: pass
#func _enter_tree() -> void: pass
#func _ready() -> void: pass
#func _input(event: InputEvent) -> void: pass
#func _unhandled_input(event: InputEvent) -> void: pass
#func _physics_process(delta: float) -> void: pass
#func _process(delta: float) -> void: pass
#endregion

#region--Public Methods
func collect() -> void:
	collected.emit()

func die() -> void:
	# Do Foo
	queue_free()
#endregion

#region--Private Methods
func _on_collected() -> void:
	GameEvents.collectible_collected.emit(self)
	if sfx_collected:
		sfx_collected.play()
	else:
		_on_sfx_collected_finished()
		
func _on_body_entered(body: Node2D) -> void:
	if body is PersonnelUnit:
		body._on_collectible_touched(self) # Codependence, refactor later

func _on_glint_sfx_timeout() -> void:
	if sfx_glint: sfx_glint.play()

func _on_sfx_collected_finished() -> void:
	die()
#endregion
