class_name ShopItemResource extends Resource

enum CostType
{
	Scrap,
	Personnel
}

## Weapon or tank unit scene
@export var item_scene:PackedScene

## Cost to initially unlock the item
## This always costs scrap
@export var unlock_cost:int

## Cost to refill per unit health or in case of weapons per ammo shot
## Fractional amounts will be always rounded up (ceili) when determining cost
@export var refill_cost:float

@export var refill_cost_type:CostType = CostType.Scrap
