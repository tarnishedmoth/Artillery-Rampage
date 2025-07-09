## Singleton used by nodes wishing to limit their total counts by registering themselves
## when adding to the tree with a common key to group them
## A limiter instance exists for each key and is present somewhere else in the tree
## Limiters are expected to self-register on ready and self-unregister when exiting the tree
extends Node

var _limiters: Dictionary[StringName, SpawnLimiter] = {}

func register(spawn_type:StringName, limiter: SpawnLimiter) -> void:
	if _limiters.has(spawn_type):
		push_warning("%s: Register - existing limiter already exists for %s and will be overwritten" % [name, str(spawn_type)])
	_limiters[spawn_type] = limiter
	print_debug("%s: Registered %s -> %s" % [name, str(spawn_type), limiter.name])

func unregister(spawn_type:StringName) -> void:
	print_debug("%s: Unregister %s" % [name, str(spawn_type)])
	_limiters.erase(spawn_type)

func track(spawn_type: StringName, node: Node, deleter: Callable = Callable(node, "queue_free")) -> void:
	var limiter: SpawnLimiter = _limiters.get(spawn_type)
	if not limiter:
		push_error("%s: Limiter not found for spawn_type=%s" % [name, str(spawn_type)])
		return
	limiter.track(node, deleter)
