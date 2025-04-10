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
	if graph_container.get_child_count() == 0:
		_create_graph()

#region Savable

const _save_state_key:StringName = &"StoryMap"
var _save_state:SaveState

func update_save_state(save:SaveState) -> void:
	save.state[_save_state_key] = _create_save_state()

func restore_from_save_state(save: SaveState) -> void:
	_save_state = save
	_create_graph()
	_save_state = null
	
func _create_save_state() -> StoryMapSaveState:
	# Save node positions
	var state := StoryMapSaveState.new()
	for child in graph_container.get_children():
		if child is StoryLevelNode:
			state.nodes.push_back(child.position)
		
	return state
func _get_save_state() -> StoryMapSaveState:
	return _save_state.state.get(_save_state_key) as StoryMapSaveState if _save_state else null
	
func _create_nodes_from_save_state(saved_state: StoryMapSaveState) -> Array[StoryLevelNode]:
	var levels:Array[StoryLevel] = _story_levels_resource.levels
	var nodes:Array[StoryLevelNode]
	nodes.resize(_story_levels_resource.levels.size())
	
	if nodes.size() != saved_state.nodes.size():
		push_warning("%s: Invalid save state - expected size=%d but node size was %d" % [name, nodes.size(), saved_state.nodes.size()])
		return []
	
	#region Populate Nodes
			
	for i in range(levels.size()):
		var level:StoryLevel = levels[i]
		var node:StoryLevelNode = _create_story_level_node(i, level)
		if not node:
			push_warning("%s: Unable to create story node for %d:%s" % [name, i, level.name])
			continue
		nodes[i] = node
		node.position = saved_state.nodes[i]
	return nodes
#endregion

func _on_next_button_pressed() -> void:
	SceneManager.next_level()

func _create_graph() -> void:
	_clear_graph()
	
	_current_level_index = SceneManager._current_level_index
	if _current_level_index < 0:
		push_error("%s: Current story level index is invalid. Map will be empty!" % [name])
		return
		
	_story_levels_resource = SceneManager.story_levels
	if not _story_levels_resource or not _story_levels_resource.levels:
		push_error("%s: No story levels defined. Map will be empty!" % [name])
		return
		
	var nodes:Array[StoryLevelNode] =_generate_or_load_nodes()
	
	#region Populate Edges
	for i in range(1, nodes.size()):
		var prev_node:StoryLevelNode = nodes[i - 1]
		var next_node:StoryLevelNode = nodes[i]
		
		if prev_node and next_node:
			graph_container.add_child(_edge_from_to(prev_node, next_node))
	#endregion		

func _generate_or_load_nodes() -> Array[StoryLevelNode]:
	var saved_state: StoryMapSaveState = _get_save_state()
	var nodes:Array[StoryLevelNode] = []
	
	if saved_state:
		nodes = _create_nodes_from_save_state(saved_state)
		# Save state could be invalid so it will return empty in that case
	if not nodes:
		nodes = _generate_nodes()
	return nodes
	
func _generate_nodes() -> Array[StoryLevelNode]:
	var levels:Array[StoryLevel] = _story_levels_resource.levels
	
	var bounds:Rect2 = get_viewport().get_visible_rect()
	bounds.size -= 2 * margins
	bounds.position.x += margins.x
	
	# Start in the middle in y
	var pos:Vector2 = Vector2(bounds.position.x, bounds.size.y / 2.0)
	var nodes:Array[StoryLevelNode] = []
	nodes.resize(_story_levels_resource.levels.size())
	
	var prototype_node:StoryLevelNode = _new_story_level_node(default_node_prototype)
	var avg_node_width:float = _get_node_width(prototype_node)	
	var ideal_edge_length:float = maxf((bounds.size.x - nodes.size() * avg_node_width) / (nodes.size() - 1), min_edge_length)
	var edge_range:Vector2 = Vector2(min_edge_length, max_edge_length)
	
	prototype_node.queue_free()
	
	#region Populate Nodes
	
	var edge_length_diff:float = 0.0
		
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
		pos.x += _get_node_width(node)
		
		var edge_length:float = randf_range(edge_range.x, edge_range.y)
		if edge_length_diff < 0 and -edge_length_diff > ideal_edge_length * (levels.size() - i) / float(levels.size()):
			print_debug("%s: Edges are too long - reducing current edge(%d) length from %f by %f" % [name, i, edge_length, -edge_length_diff])
			edge_length = maxf(ideal_edge_length + edge_length_diff, edge_range.x)
		var edge:Vector2 = Vector2(1.0,0.0).rotated(deg_to_rad(randf_range(node.min_edge_angle, node.max_edge_angle))).normalized() * edge_length
		
		if(pos.y + edge.y > bounds.position.y + bounds.size.y or 
			pos.y + edge.y < bounds.position.y):
			print_debug("%s: Edge(%d) hit y bounds - flipping y direction" % [name, i])
			edge.y = -edge.y
		edge_length_diff += ideal_edge_length - edge.x
		pos += edge
		
		nodes[i] = node
				
	#endregion
	
	return nodes
	
func _get_node_width(node: StoryLevelNode) -> float:
	return node.right_edge.position.x - node.left_edge.position.x
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
	
func _edge_from_to(from: StoryLevelNode, to: StoryLevelNode) -> StoryLevelEdge:
	var edge:StoryLevelEdge = edge_node_prototype.instantiate() as StoryLevelEdge
	
	edge.position = Vector2.ZERO
	edge.from = from.position + from.right_edge.position
	edge.to = to.position + to.left_edge.position
	
	print_debug("%s: Add edge(%s->%s) - [%s, %s]" % [name, from.label.text, to.label.text, edge.from, edge.to])
	
	#TODO: Change color?
	return edge
