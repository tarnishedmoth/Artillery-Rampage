class_name UIComponentHealthbar extends Node2D

@export var node_with_health:Node ## Must have a [b]health_changed[/b] signal to connect to.
@export_range(0.1, 4.0) var progress_bar_tween_speed:float = Juice.SNAPPY

@onready var progress_bar: ProgressBar = $ProgressBar

var tween:Tween

func _ready() -> void:
	if not node_with_health:
		# Check parent for convenience
		var parent = get_parent()
		if "health_changed" in parent:
			connect_signal(parent)
		else:
			push_warning("No Node configured for UIComponentHealthbar to observe.")
	elif not "health_changed" in node_with_health:
		push_error("Node configured for UIComponentHealthbar does not have a Health property.")
	else:
		connect_signal(node_with_health)
	hide()
	
func connect_signal(node:Node) -> void:
	#if node is DamageableDestructibleObject:
	node.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health:int) -> void:
	if tween:
		if tween.is_running():
			tween.kill()
	tween = create_tween()
	tween.tween_property(progress_bar, "value", new_health, progress_bar_tween_speed)
	
	if not visible && new_health < 100.0:
		show()
	elif visible && new_health == 100.0:
		tween.tween_callback(hide)
