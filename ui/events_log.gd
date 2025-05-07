## This guy is for helping everybody when they need it.
## Log important round events for the player to recall or learn if they missed them.
#class_name PauseMenuLogUI
extends PanelContainer

@onready var rich: RichTextLabel = $VBoxContainer/EventsLogRichText

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
	
func record(text:String) -> void:
	var entry:String
	# Get game time
	entry = bold("["+Time.get_time_string_from_system()+"]")
	entry = entry + ": " + text
	rich.text = rich.text + "\n" + entry
	
func ital(text) -> String: return "[i]" + str(text) + "[/i]"
func bold(text) -> String: return "[b]" + str(text) + "[/b]"
func underl(text) -> String: return "[u]" + str(text) + "[/u]"

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
	record(underl(player_name) + " fired their " + ital(weapon.display_name))

func _on_collectible_collected(collected: CollectibleItem): pass
func _on_personnel_requested_pickup(unit: PersonnelUnit): pass
func _on_personnel_requested_delivery(unit: PersonnelUnit): pass
func _on_copter_arrived_for_pickups(copter): pass
func _on_copter_left_airspace(copter): pass

func _on_wall_interaction(walls: Walls, projectile: WeaponProjectile, interaction_location: Walls.WallInteractionLocation): pass

func _on_took_damage(object: Node, instigatorController: Node2D, instigator: Node2D, contact_point: Vector2):
	var player_name = instigatorController.name
	record(underl(player_name) + " damaged something.")
	# TODO I don't know at this moment if we can get the damage dealt from this setup.
#endregion
