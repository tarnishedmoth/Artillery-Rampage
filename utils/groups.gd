extends Node

const Collectible:StringName = &"Collectible"
const Destructible:StringName = &"Destructible"
const Damageable:StringName = &"Damageable"

## Root node in the damageable tree
const DamageableRoot:StringName = &"DamageableRoot"

const Unit:StringName = &"Unit"

@warning_ignore("shadowed_global_identifier")
const Player:StringName = &"Player"

const Bot:StringName = &"Bot"

const Savable:StringName = &"Savable"

const TerrainChunk:StringName = &"TerrainChunk"

const GameLevel:StringName = &"GameLevel"

const WobbleActivator:StringName = &"WobbleActivator"

const StoryLevelState:StringName = &"StoryLevelState"

func get_parent_in_group(node: Node, group: StringName) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)
