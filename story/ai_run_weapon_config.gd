class_name AIRunWeaponConfig extends Resource

@export var weapon:PackedScene

## Minimum run that this weapon will additionally appear on AI if not already present
@export var min_run_count:int = 2

## How much this weapon gets weighted for each additional run with 0 being at minimum run count
## E.g. if min_run_count is 0 then the entries might be something like  {0:1.0, 1:1.5, 2:2.0 }
## The entry "2" in this case would actually be run 4 since we count from the minimum 
@export var weight_by_run:Dictionary[int, float] = {}
