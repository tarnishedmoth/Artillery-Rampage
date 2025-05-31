class_name ShopUtils

static func format_cost(cost:int, units: ShopItemResource.CostType) -> String:
	return "%d %s" % [cost, ShopItemResource.CostType.keys()[units]]
