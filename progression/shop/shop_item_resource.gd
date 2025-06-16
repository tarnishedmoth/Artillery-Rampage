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

## Discount applied to refills when the retain when empty flag is set on the item
@export var retain_empty_refill_discount:float = 0.5

@export var refill_cost_type:CostType = CostType.Scrap

var apply_refill_discount:bool = false

func get_refill_cost(count: float) -> int:
	return ceili(count * get_adjusted_refill_cost())

## Gets the refill multiplier that will keep the cost <= 1
## If > 1 just return 1
func get_increment_for_fractional_cost() -> int:
	var cost:float = get_adjusted_refill_cost()
	return floori(1.0 / cost) if cost < 1.0 and cost > 0.0 else 1
	
func get_adjusted_refill_cost() -> float:
	return refill_cost * retain_empty_refill_discount if apply_refill_discount else refill_cost
