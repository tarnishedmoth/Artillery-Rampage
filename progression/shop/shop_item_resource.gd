class_name ShopItemResource extends Resource

enum CostType
{
	Scrap,
	Personnel
}

enum ItemType
{
	Weapon,
	Upgrade #Buy an additional procedurally generated upgrade for an existing item
}

## Weapon or tank unit scene
@export var item_scene:PackedScene

## Type of the item
@export var item_type:ItemType = ItemType.Weapon

## Cost to initially unlock the item
@export var unlock_cost:int

@export var unlock_cost_type:CostType = CostType.Scrap

## Cost to refill per unit health or in case of weapons per ammo shot
## Fractional amounts will be always rounded up (ceili) when determining cost
@export var refill_cost:float

@export var refill_cost_type:CostType = CostType.Scrap
