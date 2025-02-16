extends Node

const default_collision_margin: float = 0.001

class Layers:
	const tank: int = 1
	const projectile: int = 1 << 1
	const wall:int = 1 << 2
	const terrain: int = 1 << 3
	
class CompositeMasks:
	const damageable: int = Layers.tank | Layers.terrain
