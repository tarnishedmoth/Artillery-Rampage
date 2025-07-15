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

@warning_ignore("shadowed_global_identifier")
const TerrainChunk:StringName = &"TerrainChunk"

@warning_ignore("shadowed_global_identifier")
const GameLevel:StringName = &"GameLevel"

const WobbleActivator:StringName = &"WobbleActivator"

const StoryLevelState:StringName = &"StoryLevelState"

## Rewardable is used for objects that can be rewarded at the end of a round
## This is used by the RoundStatTracker to determine what to reward
## Implicit contract is to define two metadata keys
## 1) RewardType "Scrap" or "Personnel"
## 2) RewardAmount - int indicating how much of 1 to reward
const RewardableOnDestroy:StringName = &"RewardableOnDestroy"

const SimultaneousFire:StringName = &"SimultaneousFire"

class RewardOnDestroyDetails:
	const Scrap:StringName = &"Scrap"
	const Personnel:StringName = &"Personnel"
	const RewardTypeKey:StringName = &"RewardType"
	const RewardAmountKey:StringName = &"RewardAmount"

const InWaterTag:StringName = &"in_water"
	
func get_parent_in_group(node: Node, group: StringName) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)
