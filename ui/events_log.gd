## This guy is for helping everybody when they need it.
## Log important round events for the player to recall or learn if they missed them.
class_name PauseMenuLogUI extends PanelContainer
@warning_ignore_start("unused_parameter")

@onready var rich: RichTextLabel = $VBoxContainer/EventsLogRichText

var _last_record_input:String

var _damage_last_player:String
var _damage_recipients:Dictionary[String,float] = {}

func _ready() -> void:
	# Hook into the func _on_bus
	GameEvents.user_options_changed.connect(_on_user_options_changed)
	GameEvents.all_players_added.connect(_on_all_players_added)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.level_loaded.connect(_on_level_loaded)
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)
	GameEvents.player_added.connect(_on_player_added)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.wind_updated.connect(_on_wind_updated)
	GameEvents.weapon_fired.connect(_on_weapon_fired)
	GameEvents.took_damage.connect(_on_took_damage)
	
## Takes an input and formats it with the time, and multiplier counter if identical to previous, then adds it to the UI.
func record(text:String) -> void:
	var entry:String # This will hold our output.
	
	if text == _last_record_input: # Needs a multiplier:
		if rich.text.ends_with("]."): # More than 2x:
			var parts:PackedStringArray = rich.text.rsplit("[", false, 1) # Delimiter split into exactly two pieces.
			var count:int = parts[1].to_int() + 1 # to_int() strips any non-numbers conveniently.
			rich.text = parts[0]+brac(str(count)+"x")+"." # i.e., [6x]. We can't (could) use BBCode formatting because it greatly affects our delimiter parsing.
		else:
			rich.text = rich.text + " [2x]."
	else:
		entry = bold(brac(Time.get_time_string_from_system())) # Get HH:MM:SS
		entry = entry + ": " + text # Formatting
		
		rich.text = rich.text + "\n" + entry # New line and append
	_last_record_input = text # Cache
	
func ital(v) -> String: return "[i]" + str(v) + "[/i]"
func bold(v) -> String: return "[b]" + str(v) + "[/b]"
func underl(v) -> String: return "[u]" + str(v) + "[/u]"
func brac(v) -> String: return "[" + str(v) + "]"

# Signal reacts
#region
func _on_user_options_changed(): record("Player changed their options.")
	
func _on_all_players_added(level: GameLevel): record("All players are ready to play.")

func _on_round_started(): record("Round started.")
func _on_round_ended(): record("Round ended.")

func _on_level_loaded(level: GameLevel): record("Level loaded.")

func _on_turn_started(player: TankController):
	#TODO conditional for simultaneous fire
	record(underl(player.name) + " started their turn.")
func _on_turn_ended(player: TankController):
	#TODO conditional for simultaneous fire
	_accumulate_and_record_tank_damage(player)
	record(underl(player.name) + " ended their turn.")

func _on_player_added(player: TankController): record(underl(player.name) + " joined the fray.")
func _on_player_died(player: TankController): record(underl(player.name) + " died.")

func _on_wind_updated(wind: Wind):
	var windspeed = wind.wind.x
	var direction:String = "."
	if windspeed > 0:
		direction = " east."
	elif windspeed < 0:
		direction = " west."
	record("The windspeed is now " + bold(absi(windspeed)) + direction)
#func _on_aim_updated(player: TankController): pass
#func _on_power_updated(player: TankController): pass
#func _on_weapon_updated(weapon: Weapon): pass
func _on_projectile_fired(projectile : WeaponProjectile): pass
func _on_weapon_fired(weapon : Weapon):
	var player_name = weapon.parent_tank.controller.name
	record(underl(player_name) + " used " + ital(weapon.display_name) +".")

func _on_collectible_collected(collected: CollectibleItem): pass
func _on_personnel_requested_pickup(unit: PersonnelUnit): pass
func _on_personnel_requested_delivery(unit: PersonnelUnit): pass
func _on_copter_arrived_for_pickups(copter): pass
func _on_copter_left_airspace(copter): pass

func _on_wall_interaction(walls: Walls, projectile: WeaponProjectile, interaction_location: Walls.WallInteractionLocation): pass

func _on_took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, contact_point: Vector2, damage: float):
	var player_name
	if not is_instance_valid(instigatorController):
		player_name = "Natural phenomena"
	else:
		player_name = instigatorController.name
	
	var taker_name:String = ""
	if object is Tank:
		taker_name = object.controller.name as String
	elif "display_name" in object:
		# DestructibleObject
		taker_name = object.display_name as String
	elif is_zero_approx(damage):
		# Terrain.
		return
	if taker_name.is_empty(): taker_name = "something"
	
	if "health" in object:
		if object.health <= 0.0:
			# TODO random words that mean "destroyed" for funsies
			record(underl(player_name) + " destroyed " + underl(taker_name) + ".")
			return
	
	if player_name != _damage_last_player: _damage_recipients.clear() # Empty the damaged cache
	# Check if this thing has been damaged this turn.
	if taker_name in _damage_recipients:
		_damage_recipients[taker_name] += damage # Add to previous
	else:
		_damage_recipients[taker_name] = damage # First instance
	_damage_last_player = player_name
		
func _accumulate_and_record_tank_damage(_player: TankController) -> void:
	# TODO per player to support simultaneous mode
	for damaged in _damage_recipients:
		record(underl(_damage_last_player) + " damaged " + underl(damaged) + " for " + bold(int(_damage_recipients[damaged]))+".")
#endregion
