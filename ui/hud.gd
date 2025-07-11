extends Control

const color_flash:Color = Color.RED
const color_flash_2:Color = Color.BLUE_VIOLET

@onready var angle_ui_hudelement:HUDElement = %Angle
@onready var power_ui_hudelement:HUDElement = %Power
@onready var health_ui_hudelement:HUDElement = %Health
@onready var walls_ui_hudelement:HUDElement = %WallsHudElement

@onready var center_container: TextureRect = %CenterContainer

@onready var active_player_ui_label:Label = %ActivePlayerText
@onready var wind_ui_hudelement:HUDElement = %WindHudElement
@onready var weapon_ui_hudelement:HUDElement = %WeaponHudElement

@onready var debug_level_name: Label = %DebugLevelName
@onready var tooltipper: Control = %Tooltipper

var _active_player:TankController = null

var _center_tween:Tween
var _player_tween:Tween
var _health_tween:Tween
var _power_tween:Tween
var _aim_tween:Tween

var _wind_tween:Tween

var _weapon_tween:Tween
var _ammo_tween:Tween

var _is_new_turn:bool = false


func _ready() -> void:
	init_signals()
	_on_user_options_changed() # Apply user options
	
	modulate = Color.TRANSPARENT
	
	await GameEvents.round_started
	Juice.fade_in(self, Juice.PATIENT)

func init_signals():
	GameEvents.turn_started.connect(_on_turn_started);
	GameEvents.turn_ended.connect(_on_turn_ended);
	GameEvents.aim_updated.connect(_on_aim_updated);
	GameEvents.power_updated.connect(_on_power_updated)
	GameEvents.wind_updated.connect(_on_wind_updated)
	GameEvents.weapon_updated.connect(_on_weapon_updated)
	GameEvents.level_loaded.connect(_on_level_changed)
	GameEvents.user_options_changed.connect(_on_user_options_changed)

	if OS.is_debug_build():
		debug_level_name.show()

func _on_turn_started(player: TankController) -> void:
	_is_new_turn = true
	
	_active_player = player
	# Update health dynamically as player takes damage during turn
	if not player.tank.tank_took_damage.is_connected(_on_took_damage):
		player.tank.tank_took_damage.connect(_on_took_damage)

	active_player_ui_label.text = player.name
	
	Juice.flash_using(_player_tween, active_player_ui_label, [Juice.FAST], Color.WHITE, MathUtils.semitransparent(color_flash_2, 0.65))
	
	_update_health(player)
	_on_aim_updated(player)
	_on_power_updated(player)
	_on_weapon_updated(player.tank.get_equipped_weapon())
	
	await get_tree().process_frame
	_is_new_turn = false

func _on_took_damage(tank: Tank, _instigatorController: Node2D, _instigator: Node2D, _amount: float):
	if tank.owner == _active_player:
		_update_health(_active_player)

func _update_health(player: TankController) -> void:
	var tank:Tank = player.tank
	health_ui_hudelement.set_value(UIUtils.get_health_pct_display(tank.health, tank.max_health))
	
	if not _is_new_turn:
		if health_ui_hudelement.value_changed:
			Juice.flash_using(_health_tween, health_ui_hudelement.value, [Juice.SLOW], Color.WHITE, color_flash)

func _on_turn_ended(player: TankController) -> void:
	# Disconnect when no longer the active player
	if player.tank.tank_took_damage.is_connected(_on_took_damage):
		player.tank.tank_took_damage.disconnect(_on_took_damage)

func _on_aim_updated(player: TankController) -> void:
	if player != _active_player:
		return
	var angleRads = player.tank.get_turret_rotation()

	angle_ui_hudelement.set_value(str(int(abs(rad_to_deg(angleRads))))+"°")
	
	if not _is_new_turn:
		if angle_ui_hudelement.value_changed:
			Juice.flash_using(_aim_tween, angle_ui_hudelement.value, [Juice.SNAP], Color.WHITE, color_flash)


func _on_power_updated(player: TankController) -> void:
	if player != _active_player:
		return
	power_ui_hudelement.set_value(int(player.tank.power))
	
	if not _is_new_turn:
		if power_ui_hudelement.value_changed:
			Juice.flash_using(_power_tween, power_ui_hudelement.value, [Juice.SNAP], Color.WHITE, color_flash)


func _on_wind_updated(wind: Wind) -> void:
	var vector := wind.wind
	var value := vector.length()

	var direction := vector.x
	wind_ui_hudelement.set_value("%d %s" % [_fmt_wind_value(value), _get_direction_string(direction)])
	
	if wind_ui_hudelement.value_changed:
		await Juice.fade_in(wind_ui_hudelement, Juice.PATIENT).finished
		#await get_tree().create_timer(1.0).timeout # Too much happening at once on turn change
		Juice.flash_using(_wind_tween, wind_ui_hudelement.value, [Juice.SNAP, Juice.SNAP], Color.WHITE, MathUtils.semitransparent(color_flash_2, 0.7))

func _fmt_wind_value(value: float) -> int:
	return int(abs(value))

func _get_direction_string(value: float) -> String:
	return "▶" if value >= 0 else "◀"


func _on_weapon_updated(weapon: Weapon) -> void:
	if weapon.parent_tank.controller != _active_player:
		return
	weapon_ui_hudelement.set_label(weapon.display_name)
	weapon_ui_hudelement.set_value(_get_ammo_text(weapon))
	
	if not _is_new_turn:
		if weapon_ui_hudelement.label_changed:
			Juice.flash_using(_weapon_tween, weapon_ui_hudelement.label, [Juice.SNAP, Juice.SNAP, Juice.SNAP], Color.WHITE)
		else:
			if weapon_ui_hudelement.value_changed:
				Juice.flash_using(_ammo_tween, weapon_ui_hudelement.value, [Juice.SMOOTH], Color.WHITE, color_flash)

func _get_ammo_text(weapon: Weapon) -> String:
	if not weapon.use_ammo:
		return char(9854)
	var tokens:Array[String] = []
	tokens.push_back(str(weapon.current_ammo))
	if weapon.use_magazines:
		tokens.push_back(" (%d x %d)" % [weapon.magazine_capacity, weapon.magazines])
	
	return "".join(tokens)
	
func _on_level_changed(level: GameLevel) -> void:
	if OS.is_debug_build():
		var file_name = SceneManager.current_scene.scene_file_path
		debug_level_name.text = file_name
	walls_ui_hudelement.value.text =_fmt_walls_value(level.walls)

func _on_user_options_changed() -> void:
	if UserOptions.show_hud:
		if not visible: show()
	else:
		if visible: hide()

func _fmt_walls_value(walls:Walls) -> String:
	match walls.wall_mode:
		Walls.WallType.NONE: return "None"
		Walls.WallType.WARP: return "Warp"
		Walls.WallType.ELASTIC: return "Elastic"
		Walls.WallType.ACCELERATE: return "Accelerate"
		Walls.WallType.STICKY: return "Sticky"
		_: return "<!ERROR>"
