## Object manager that limits the total objects of a given spawn type category
## by deleting the oldest nodes first when the limit is reached
## The limiter automatically untracks nodes that delete themselves
class_name SpawnLimiter extends Node

@export var spawn_type:StringName
@export_range(1, 1000, 1, "or_greater") var max_objects:int = 20

class TrackedNode:
	var node:Node
	var node_id: int
	var spawn_time: int
	var deleter:Callable
	
var _objects: Dictionary[int, TrackedNode] = {}

func _ready() -> void:
	SpawnLimiterManager.register(spawn_type, self)
	clear()

func _exit_tree() -> void:
	SpawnLimiterManager.unregister(spawn_type)

func clear() -> void:
	_objects.clear()
		
func track(node: Node, deleter: Callable) -> void:
	if _objects.size() == max_objects:
		_remove_eldest_entry()
	
	print_debug("%s(%s): Tracking %s : size=%d " % [name, str(spawn_type), node.name, _objects.size() + 1])
	_add_to_objects(node, deleter)

func _add_to_objects(node: Node, deleter:Callable) -> void:
	var tracked_node:TrackedNode = TrackedNode.new()
	tracked_node.node = node
	tracked_node.node_id = node.get_instance_id()
	tracked_node.spawn_time = Time.get_ticks_usec()
	tracked_node.deleter = deleter
	node.tree_exiting.connect(_delete.bind(node))
	
	_objects[tracked_node.node_id] = tracked_node
	
func _delete(node: Node) -> void:	
	var node_id:int = node.get_instance_id()
	var tracked_node:TrackedNode = _objects.get(node_id)
	
	if not tracked_node:
		print_debug("%s(%s) - Node %s was no longer tracked: size=%d" % [name, str(spawn_type), node.name, _objects.size()])
		return
	
	print_debug("%s(%s) - Node %s is being deleted: size=%d" % [name, str(spawn_type), node.name, _objects.size() - 1])

	tracked_node.deleter.call()
	_objects.erase(node_id)
	
func _get_eldest_entry() -> TrackedNode:
	if _objects.is_empty():
		return null

	return _objects.values().reduce(func(min_entry, entry): return entry if entry.spawn_time < min_entry.spawn_time else min_entry)

func _remove_eldest_entry() -> void:
	var oldest:TrackedNode = _get_eldest_entry()
	if not oldest:
		return
		
	print_debug("%s(%s): Evicting eldest entry=%s - size=%d"\
		% [name, str(spawn_type), str(oldest.node.name) if is_instance_valid(oldest.node) else str(oldest.node.id), _objects.size()])
	
	if is_instance_id_valid(oldest.node_id):
		oldest.deleter.call()
	_objects.erase(oldest.node_id)
	
