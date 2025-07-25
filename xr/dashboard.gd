extends Node3D

@export_group("SFX", "sfx_")
@export var sfx_turn_start:AudioStreamPlayer3D

@export var shoot_button:XRToolsInteractableAreaButton
@export var angle_right_button:XRToolsInteractableAreaButton
@export var angle_left_button:XRToolsInteractableAreaButton
@export var power_up_button:XRToolsInteractableAreaButton
@export var power_down_button:XRToolsInteractableAreaButton
@export var weapon_cycle_button:XRToolsInteractableAreaButton

@export var angle_label:Label3D
@export var power_label:Label3D
@export var weapon_label:Label3D

@export var aim_speed_degs_per_sec = 32.0
@export var power_pct_per_sec = 20.0
var fine_control_modifier:float = 1.0

var power: float
var angle: float

var power_increase_pressed: bool = false
var power_decrease_pressed: bool = false
var angle_right_pressed: bool = false
var angle_left_pressed: bool = false

var player: Player

func _ready() -> void:
	connect_signals()
	
func connect_signals() -> void:
	GlobalXR.round_ready.connect(_on_round_ready)
	GameEvents.turn_started.connect(_on_turn_started)
	
	GameEvents.aim_updated.connect(_on_aim_updated)
	GameEvents.power_updated.connect(_on_power_updated)
	GameEvents.weapon_updated.connect(_on_weapon_updated)

func _process(delta: float) -> void:
	if player:
		if player.can_aim:
			if power_increase_pressed:
				player.set_power(delta * power_pct_per_sec * fine_control_modifier)
			elif power_decrease_pressed:
				player.set_power(-delta * power_pct_per_sec * fine_control_modifier)
			
			if angle_right_pressed:
				player.aim(delta * aim_speed_degs_per_sec * fine_control_modifier)
			elif angle_left_pressed:
				player.aim(-delta * aim_speed_degs_per_sec * fine_control_modifier)
			
		angle_label.text = str(player.tank.get_turret_rotation())
		power_label.text = str(player.tank.power)

#region Global Events
func _on_round_ready() -> void:
	# Set initial states
	player = GlobalXR.player_controller
	power = player.tank.power
	#angle = GlobalXR.player_controller.tank.angle_deviation
	
func _on_turn_started(controller: TankController) -> void:
	if controller == player:
		if sfx_turn_start: sfx_turn_start.play()
	

func _on_aim_updated(controller: TankController) -> void:
	if controller != player:
		return
	var angleRads = controller.tank.get_turret_rotation()

	#angle_ui_hudelement.set_value(str(int(abs(rad_to_deg(angleRads))))+"°")
	angle_label.text = str(int(abs(rad_to_deg(angleRads))))+"°"


func _on_power_updated(controller: TankController) -> void:
	if controller != player:
		return
	power_label.text = str(int(controller.tank.power))

func _on_weapon_updated(weapon: Weapon) -> void:
	if weapon.parent_tank.controller != player:
		return
	
	weapon_label.text = weapon.display_name + " | " + _get_ammo_text(weapon)
	
	#if weapon.parent_tank.controller != _active_player:
		#return
	#weapon_ui_hudelement.set_label(weapon.display_name)
	#weapon_ui_hudelement.set_value(_get_ammo_text(weapon))
	#
	### Weapon Name & Ammo
	#if not _is_new_turn:
		#if weapon_ui_hudelement.label_changed:
			#Juice.flash_using(_weapon_tween, weapon_ui_hudelement.label, [Juice.SNAP, Juice.SNAP, Juice.SNAP], Color.WHITE)
		#else:
			#if weapon_ui_hudelement.value_changed:
				#Juice.flash_using(_ammo_tween, weapon_ui_hudelement.value, [Juice.SMOOTH], Color.WHITE, color_flash)
				#
	### Magazines & Out Of Ammo
	#var container_modulate:Color = Color.WHITE
	#if not weapon.use_ammo:
		#weapon_magazines_hud_element.hide()
	#elif weapon.use_magazines:
		#weapon_magazines_hud_element.show()
		#weapon_magazines_hud_element.set_value(str(weapon.magazines))
		#
		#if not _is_new_turn && weapon_magazines_hud_element.value_changed:
			#Juice.flash_using(_mags_tween, weapon_magazines_hud_element.label, [Juice.SMOOTH, Juice.SMOOTH, Juice.SMOOTH], Color.WHITE, color_flash)
		#
		#if weapon.current_ammo < 1 and weapon.magazines < 1:
			#container_modulate = color_disabled
			#
	#else:
		#weapon_magazines_hud_element.hide()
		#
		#if weapon.current_ammo < 1:
			#container_modulate = color_disabled
	#weapon_ui_hudelement.modulate = container_modulate
	
	### Weapon Modes
	#if not weapon.mode_node:
		#weapon_mode_hud_element.hide()
	#else:
		### Necessary await because the WeaponMode component reacts to the same signal
		### that triggers this update.
		#await get_tree().process_frame
		#weapon_mode_hud_element.show()
		#var display:WeaponModes.LabelValue = weapon.mode_node.get_display_text()
		#weapon_mode_hud_element.set_label(display.label)
		#weapon_mode_hud_element.set_value(display.value)

func _get_ammo_text(weapon: Weapon) -> String:
	if not weapon.use_ammo:
		return char(9854)
		
	else:
		var tokens:Array[String] = []
		tokens.push_back(str(weapon.current_ammo))
		
		if weapon.use_magazines:
			tokens.push_back(" (%d x %d)" % [weapon.magazine_capacity, weapon.magazines])
		
		return "".join(tokens)
		#return str(weapon.current_ammo)

#func _on_wind_updated(wind: Wind) -> void:
	#var vector := wind.wind
	#var value := vector.length()
#
	#var direction := vector.x
	#wind_ui_hudelement.set_value("%d %s" % [_fmt_wind_value(value), _get_direction_string(direction)])
	#
	#if wind_ui_hudelement.value_changed:
		#await Juice.fade_in(wind_ui_hudelement, Juice.PATIENT).finished
		##await get_tree().create_timer(1.0).timeout # Too much happening at once on turn change
		#Juice.flash_using(_wind_tween, wind_ui_hudelement.value, [Juice.SNAP, Juice.SNAP], Color.WHITE, MathUtils.semitransparent(color_flash_2, 0.7))
		
#endregion
#region Local Events

func _on_shoot_button_button_pressed(button: Variant) -> void:
	if player:
		if not player.can_shoot:
			# Foo
			return
		player.shoot()

func _on_angle_left_button_button_pressed(button: Variant) -> void:
	angle_left_pressed = true

func _on_angle_left_button_button_released(button: Variant) -> void:
	angle_left_pressed = false

func _on_angle_right_button_button_pressed(button: Variant) -> void:
	angle_right_pressed = true

func _on_angle_right_button_button_released(button: Variant) -> void:
	angle_right_pressed = false

func _on_power_down_button_button_pressed(button: Variant) -> void:
	power_decrease_pressed = true
	
func _on_power_down_button_button_released(button: Variant) -> void:
	power_decrease_pressed = false

func _on_power_up_button_button_pressed(button: Variant) -> void:
	power_increase_pressed = true
	
func _on_power_up_button_button_released(button: Variant) -> void:
	power_increase_pressed = false
