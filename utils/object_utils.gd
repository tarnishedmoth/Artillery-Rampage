extends Node

## Await result to wait for object to be destroyed
func wait_free_free(node: Node) -> void:
	# queue_free is scheduled at the end of the current frame
	# if that call is itself deferred we may need to wait multiple frames
	while is_instance_valid(node):
		await get_tree().process_frame
