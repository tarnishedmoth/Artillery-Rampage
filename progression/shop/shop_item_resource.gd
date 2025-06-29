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

## Set to true to disable this shop item from appearing
@export var disable:bool = false

var apply_refill_discount:bool = false

## Set to value > 1 when using magazines
var ammo_purchase_increment:int = 1
var uses_magazines:bool = false

func get_refill_cost(count: int) -> int:
	# HACK: for ammo_purchase since displaying the magazine total ammo
	if count > 1 and ammo_purchase_increment > 1:
		count = floori(float(count) / ammo_purchase_increment)
	return ceili(count * get_adjusted_refill_cost())

## Gets the refill multiplier that will keep the cost <= 1
## If > 1 just return 1
func get_increment_for_fractional_cost() -> int:
	var cost:float = get_adjusted_refill_cost()
	var increment:int = floori(1.0 / cost) if cost < 1.0 and cost > 0.0 else 1
	return increment * ammo_purchase_increment
	
func get_adjusted_refill_cost() -> float:
	var base_cost:float = refill_cost * ammo_purchase_increment
	return base_cost * retain_empty_refill_discount if apply_refill_discount else base_cost
