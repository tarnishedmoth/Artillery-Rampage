extends Node

const default_collision_margin: float = 0.001

class Layers:
	const tank: int = 1
	const projectile: int = 1 << 1
	const wall:int = 1 << 2
	const terrain: int = 1 << 3
	const world_body: int = 1 << 4
	
	# This is the world bottom
	const floor:int = 1 << 5
	
class CompositeMasks:
	const damageable: int = Layers.tank | Layers.terrain | Layers.world_body
	
	const obstacle: int = Layers.terrain | Layers.world_body
	# Tanks are staggered so shouldn't need to snap down on top of other tanks
	const tank_snap: int = obstacle
	const visibility: int = Layers.tank | Layers.terrain | Layers.world_body
