extends ScrollContainer
## Dynamically resize up to a max height.
## Watches a target container (which can be self), and resizes based on its children,
## automatically resizing when children are added or removed.

@export var max_size_y:float = 720.0
@export var extra_margin:float = 6.0 ## Extra padding added to the height of this node.
@export var target_container:Container = self

func _enter_tree() -> void:
	target_container.child_order_changed.connect(_on_child_order_changed)

func _ready() -> void:
	resize_to_fit()
	
func _on_child_order_changed() -> void:
	resize_to_fit()

func resize_to_fit() -> void:
	var summed_heights:float = get_summed_height_of_children(target_container)
	var req_height:float
	
	if summed_heights < target_container.size.y:
		req_height = target_container.size.y
	else:
		req_height = summed_heights
			
	custom_minimum_size.y = minf(req_height, max_size_y)

func get_summed_height_of_children(node:Node) -> float:
	var children:Array
	for child in target_container.get_children():
		if child is Control:
			children.append(child)
			
	var summed_heights:float = 0.0
	if not children.is_empty():
		for child:Control in children:
			summed_heights += child.size.y + extra_margin
			# For whatever reason, I get a scroll bar when it should fit all items
			# on-screen, so this is a buffer.
	return summed_heights
