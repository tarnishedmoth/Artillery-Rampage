class_name WobbleDifficultyModifierResource extends Resource

## Enable or disable the behavior
@export var enabled:bool = true
## Deviation range vs damage pct
@export var aim_deviation_v_damage:Curve

## Speed of the deviation vs damage, in general period should decrease with more damage
@export var aim_deviation_period_v_damage:Curve
