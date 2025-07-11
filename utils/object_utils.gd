extends Node

## Await result to wait for object to be destroyed
func wait_free(node: Node) -> void:
	# queue_free is scheduled at the end of the current frame
	# if that call is itself deferred we may need to wait multiple frames
	while is_instance_valid(node):
		await get_tree().process_frame

## Computes effective modulate value that will be applied to this node at rendering time
## Multiplies all the self_modulate and modulate values up to its top-most canvas item parent
func get_effective_modulate(node: CanvasItem) -> Color:
	var result: Color = Color.WHITE
	while node:
		result *= node.self_modulate * node.modulate
		node = node.get_parent() as CanvasItem
	return result
