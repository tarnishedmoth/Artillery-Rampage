extends Control

@onready var angle_text = $VBoxContainer/Angle
@onready var power_text = $VBoxContainer/Power
@onready var active_player_text = $VBoxContainer3/ActivePlayer
@onready var wind_text = $VBoxContainer3/Wind
@onready var health_text = $VBoxContainer2/Health
@onready var aim_direction_text = $VBoxContainer2/AimDirection

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init_signals()

	
func init_signals():
	GameEvents.connect("turn_started", _on_turn_started);
	GameEvents.connect("aim_updated", _on_aim_updated);
	GameEvents.connect("power_updated", _on_power_updated)

func _on_turn_started(player: TankController) -> void:
	active_player_text.text = player.name
	_on_aim_updated(player)
	_on_power_updated(player)

func _on_aim_updated(player: TankController) -> void:
	var angleRads = player.tank.get_turret_rotation()
	
	angle_text.set_value(int(abs(rad_to_deg(angleRads))))
	aim_direction_text.set_value("->" if angleRads >= 0 else "<-")

func _on_power_updated(player: TankController) -> void:
	power_text.set_value(int(player.tank.power))
