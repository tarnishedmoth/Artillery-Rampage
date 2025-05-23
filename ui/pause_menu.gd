extends Control

var paused = false;

@onready var options_menu: PanelContainer = %OptionsMenu
@onready var pause_menu: Control = %PauseMenu

@onready var exit_to_desktop_button: Button = %QuitToDesktop

## Super secret cheat codes (shh!)
enum Keys{UP,DOWN,LEFT,RIGHT,SHOOT}
enum Cheats{
	FULL_HEALTH,
	FULL_AMMO,
	RELOCATE,
	LIGHTNING,
	GROW,
	SHRINK,
	INSTAKILL,
	}
var CheatCodes:Dictionary[Array, Cheats] = {
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.LEFT,Keys.RIGHT,Keys.LEFT,Keys.RIGHT]: Cheats.FULL_HEALTH,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.RIGHT,Keys.LEFT,Keys.RIGHT,Keys.LEFT]: Cheats.FULL_AMMO,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.LEFT,Keys.UP,Keys.RIGHT,Keys.DOWN]: Cheats.RELOCATE,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.UP,Keys.UP,Keys.UP,Keys.DOWN]: Cheats.LIGHTNING,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.RIGHT,Keys.RIGHT,Keys.RIGHT,Keys.DOWN]: Cheats.SHRINK,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.RIGHT,Keys.RIGHT,Keys.RIGHT,Keys.UP]: Cheats.GROW,
	[Keys.UP,Keys.UP,Keys.DOWN,Keys.DOWN,Keys.RIGHT,Keys.RIGHT,Keys.LEFT,Keys.UP]: Cheats.INSTAKILL,
}
var input_buffer:Array[Keys]

func _ready():
	if OS.get_name() == "Web":
		exit_to_desktop_button.hide()
		
	if not SceneManager.play_mode == SceneManager.PlayMode.PLAY_NOW:
		%PauseMenu.get_node("%NewGame").hide()
	hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_visibility()
		
func _input(event: InputEvent) -> void:
	if paused:
		var buffer_action:Keys
		if event.is_action_pressed("aim_left"): buffer_action = Keys.LEFT
		elif event.is_action_pressed("aim_right"): buffer_action = Keys.RIGHT
		elif event.is_action_pressed("power_increase"): buffer_action = Keys.UP
		elif event.is_action_pressed("power_decrease"): buffer_action = Keys.DOWN
		elif event.is_action_pressed("shoot"): buffer_action = Keys.SHOOT
		else:
			return
		input_buffer.append(buffer_action)
		while input_buffer.size() > 8:
			input_buffer.remove_at(0)
			continue
		_check_cheat_code_entered(input_buffer)

func toggle_visibility():
	paused = !paused
	
	if paused:
		self.show()
		get_tree().paused = paused
	else:
		self.hide()
		get_tree().paused = paused	
	

func _on_resume_pressed():
	toggle_visibility()

func _on_main_menu_pressed() -> void:
	SceneManager.switch_scene_keyed(SceneManager.SceneKeys.MainMenu, 0.0)

func _on_quit_to_desktop_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	pause_menu.hide()
	options_menu.show()

func _on_options_menu_closed() -> void:
	pause_menu.show()
	options_menu.hide()


func _on_new_game_pressed() -> void:
	# Start a new quick match
	
	#PlayerStateManager.enable = false
	#SceneManager.play_mode = SceneManager.PlayMode.PLAY_NOW
	
	var level: StoryLevel = SceneManager.levels_always_selectable.levels.pick_random()
	if level:
		SceneManager.switch_scene_file(level.scene_res_path)

func _check_cheat_code_entered(code:Array[Keys]) -> void:
	if input_buffer in CheatCodes:
		var cheat_name:String
		
		match CheatCodes[input_buffer]:
			Cheats.FULL_HEALTH:
				cheat_name = "FULL HEALTH"
				# Give the player's Tank max health
				var tank = _get_player_controller().tank
				tank.health = tank.max_health
				
			Cheats.FULL_AMMO:
				cheat_name = "FULL AMMO"
				var current_weapon = _get_player_controller().tank.get_equipped_weapon()
				current_weapon.restock_ammo(99)
				
			Cheats.INSTAKILL:
				cheat_name = "INSTAKILL"
				var current_weapon = _get_player_controller().tank.get_equipped_weapon()
				current_weapon.enforce_projectile_property("damage_multiplier", 9999.9)
				
			Cheats.RELOCATE:
				cheat_name = "RELOCATE"
				# TODO ;)
				
			Cheats.LIGHTNING:
				cheat_name = "LIGHTNING"
				var level_root = SceneManager.get_current_level_root()
				if level_root is GameLevel:
					level_root.round_director.trigger_lightning()
					
			Cheats.GROW:
				cheat_name = "GROW"
				var tank = _get_player_controller().tank
				tank.apply_scale(Vector2(1.5,1.5))
				
			Cheats.SHRINK:
				cheat_name = "SHRINK"
				var tank = _get_player_controller().tank
				tank.apply_scale(Vector2(0.75,0.75))
				
		print_debug("-- CHEAT: ", cheat_name) # TODO log in pause menu events log

func _get_player_controller() -> Player:
	var player = null
	for unit in get_tree().get_nodes_in_group(Groups.Unit):
		if unit is Tank:
			if unit.controller is Player:
				player = unit.controller
				break
	return player
