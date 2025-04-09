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
	#_create_graph()
	pass

func _on_next_button_pressed() -> void:
	SceneManager.next_level()

func _create_graph() -> void:
	_clear_graph()
	
	_current_level_index = SceneManager._current_level_index
	if _current_level_index < 0:
		push_error("Current story level index is invalid. Map will be empty!")
		return
		
	_story_levels_resource = SceneManager.story_levels
	if not _story_levels_resource or not _story_levels_resource.levels:
		push_error("No story levels defined. Map will be empty!")
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
	
	#region Populate nodes
		
	for i in range(levels.size()):
		var level:StoryLevel = levels[i]
		var node:StoryLevelNode = _create_story_level_node(i, level)
		if not node:
			push_warning("Unable to create story node for %d:%s" % [i, level.name])
			continue
		var node_bounds:Rect2 = node.icon.get_rect()
		
		# Position so that left edge attachment is where we want to add the node
		pos.x -= node.right_edge.position.x
		node.position = pos
		
		# Offset by right edge position for edge attachment
		pos.x += node.left_edge.position.x - node.right_edge.position.x
		nodes[i] = node
		
		graph_container.add_child(node)
		
	#endregion
	
	#region Populate edges
	
	#endregion		

func _clear_graph() -> void:
	for i in range(graph_container.get_child_count() - 1, -1, -1):
		var child:Node = graph_container.get_child(i)
		graph_container.remove_child(child)
		child.queue_free()
	
	
func _update_active_level() -> void:
	pass
	
	
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
		push_warning("Level %s has no UI map node defined! Defaulting to default prototype" % [metadata.name])
		prototype = default_node_prototype
	
	var node:StoryLevelNode = _new_story_level_node(prototype)
	return node

func _new_story_level_node(prototype: PackedScene) -> StoryLevelNode:
	var node:StoryLevelNode = prototype.instantiate() as StoryLevelNode
	return node
	
func _edge_from_to(from: StoryLevelNode, to: StoryLevelNode, bounds:Rect2) -> Line2D:
	var edge:Line2D = edge_node_prototype.instantiate() as Line2D
	edge.points.clear()
	
	edge.position = Vector2.ZERO
	edge.points.append(from.right_edge.position)
	edge.points.append(to.left_edge.position)
	
	#TODO: Change color?
	return edge
