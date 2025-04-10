extends Node

const Collectible:StringName = &"Collectible"
const Destructible:StringName = &"Destructible"
const Damageable:StringName = &"Damageable"
const Unit:StringName = &"Unit"

@warning_ignore("shadowed_global_identifier")
const Player:StringName = &"Player"

const Bot:StringName = &"Bot"

const Savable:StringName = &"Savable"

func get_parent_in_group(node: Node, group: StringName) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)
