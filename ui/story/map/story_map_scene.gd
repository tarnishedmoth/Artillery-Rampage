class_name StoryMapScene extends Control

#region Prototypes
@export_group("Prototypes")
@export var edge_node_prototype:PackedScene
@export var default_node_prototype:PackedScene
@export var unknown_node_prototype:PackedScene
@export var incomplete_level_material:Material
#endregion

@export var margins:Vector2 = Vector2(20.0,20.0)
@export var min_edge_length:float = 25.0
@export var max_edge_length:float = 150.0

@export_group("")

@onready var graph_container: Node = $Container/LevelNodesContainer

var _story_levels_resource:StoryLevelsResource
var _current_level_index:int

func _ready() -> void:
	_create_graph()

func _on_next_button_pressed() -> void:
	SceneManager.next_level()

func _create_graph() -> void:
	_clear_graph()
	
	#region Graph Setup
	_current_level_index = SceneManager._current_level_index
	if _current_level_index < 0:
		push_error("%s: Current story level index is invalid. Map will be empty!" % [name])
		return
		
	_story_levels_resource = SceneManager.story_levels
	if not _story_levels_resource or not _story_levels_resource.levels:
		push_error("%s: No story levels defined. Map will be empty!" % [name])
		return
		
	var levels:Array[StoryLevel] = _story_levels_resource.levels
	
	var bounds:Rect2 = get_viewport().get_visible_rect()
	bounds.size -= 2 * margins
	bounds.position.x += margins.x
	
	# Start in the middle in y
	var pos:Vector2 = Vector2(bounds.position.x, bounds.size.y / 2.0)
	var nodes:Array[StoryLevelNode] = []
	nodes.resize(_story_levels_resource.levels.size())
	
	var ideal_edge_length:float = bounds.size.x / nodes.size()
	var edge_range:Vector2 = Vector2(minf(min_edge_length, ideal_edge_length), 0.0)
	edge_range.y = maxf(edge_range.x, max_edge_length)
	
	#endregion
	
	#region Populate Nodes
		
	for i in range(levels.size()):
		var level:StoryLevel = levels[i]
		var node:StoryLevelNode = _create_story_level_node(i, level)
		if not node:
			push_warning("%s: Unable to create story node for %d:%s" % [name, i, level.name])
			continue
		
		# Position so that left edge attachment is where we want to add the node
		pos.x += node.right_edge.position.x
		
		print_debug("%s: Add node(%s) at position=%s" % [name, level.name, pos])
		node.position = pos
		
		# Offset by right edge position for edge attachment
		pos.x += node.right_edge.position.x - node.left_edge.position.x
		
		var edge:Vector2 = Vector2(1.0,0.0).rotated(deg_to_rad(randf_range(node.min_edge_angle, node.max_edge_angle))).normalized() * randf_range(edge_range.x, edge_range.y)
		if(pos.y + edge.y > bounds.position.y + bounds.size.y or 
			pos.y + edge.y < bounds.position.y):
			print_debug("%s: Edge hit bounds - flipping y direction" % [name, node.name])
			edge.y = -edge.y
		pos += edge
		
		nodes[i] = node
				
	#endregion
	
	#region Populate Edges
	for i in range(1, nodes.size()):
		var prev_node:StoryLevelNode = nodes[i - 1]
		var next_node:StoryLevelNode = nodes[i]
		
		if prev_node and next_node:
			graph_container.add_child(_edge_from_to(prev_node, next_node))
	#endregion		

func _clear_graph() -> void:
	for i in range(graph_container.get_child_count() - 1, -1, -1):
		var child:Node = graph_container.get_child(i)
		graph_container.remove_child(child)
		child.queue_free()
	
func _create_story_level_node(index:int, metadata:StoryLevel) -> StoryLevelNode:
	# TODO: Maybe knowing about future node is an unlockable or a more complex strategy is adopted
	# If it is unlockable then the story sequence would need to be more procedural 
	# which wasn't planned other than individual procedural nature within a given level
	if index < _current_level_index:
		return _new_explored_node(metadata)
	elif index == _current_level_index:
		return _new_discovered_node(metadata)
	return _new_unknown_node(metadata)
	
func _new_explored_node(metadata: StoryLevel) -> StoryLevelNode:
	return _new_story_level_node_from_metadata(metadata)

func _new_unknown_node(metadata: StoryLevel) -> StoryLevelNode:
	return _new_story_level_node(unknown_node_prototype)
	
func _new_discovered_node(metadata: StoryLevel) -> StoryLevelNode:
	var node:StoryLevelNode = _new_story_level_node_from_metadata(metadata)
	node.set_icon_material(incomplete_level_material)
	
	return node

func _new_story_level_node_from_metadata(metadata: StoryLevel) -> StoryLevelNode:
	var prototype:PackedScene = metadata.ui_map_node
	if not prototype:
		push_warning("%s: Level %s has no UI map node defined! Defaulting to default prototype" % [name, metadata.name])
		prototype = default_node_prototype
	
	var node:StoryLevelNode = _new_story_level_node(prototype)
	node.set_label(metadata.name)
	
	return node

func _new_story_level_node(prototype: PackedScene) -> StoryLevelNode:
	var node:StoryLevelNode = prototype.instantiate() as StoryLevelNode
	graph_container.add_child(node)
	return node
	
func _edge_from_to(from: StoryLevelNode, to: StoryLevelNode) -> Line2D:
	var edge:Line2D = edge_node_prototype.instantiate() as Line2D
	
	edge.position = Vector2.ZERO

	var from_pos:Vector2 = 	from.position + from.right_edge.position
	var to_pos:Vector2 = to.position + to.left_edge.position
	print_debug("%s: Add edge(%s->%s) - [%s, %s]" % [name, from.label.text, to.label.text, from_pos, to_pos])

	edge.set_points([from_pos, to_pos])
	
	#TODO: Change color?
	return edge
