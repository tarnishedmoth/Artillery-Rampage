class_name AITankWindwunder extends AITank

@export var direct_fire_wind_threshold:float = 20.0
@export var preferred_ai_priority:int = 20

func before_state_selection():
	var game_level: GameLevel = SceneManager.get_current_level_root()
	var wind: Wind = game_level.wind
	
	if wind and wind.wind.length() >= direct_fire_wind_threshold:
		ai_decision_state_machine.change_default_priority(Enums.AIBehaviorType.Brute, preferred_ai_priority)
	else:
		ai_decision_state_machine.change_default_priority(Enums.AIBehaviorType.Lobber, preferred_ai_priority)
