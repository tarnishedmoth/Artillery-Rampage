## Wrapper around callable to only execute it once
## Subsequent executions are ignored
extends Node

var _run_record:Dictionary[int, Array] = {}

func execute(context:Object, callable:Callable, additional_context:String="")->bool:
	var record:Array = _run_record.get_or_add(context.get_instance_id(), [])
	if additional_context in record:
		print("%s: Already executed callable for %s%s" % [name, context, " -> %s" % additional_context if additional_context else ""])
		return false
	
	callable.call()
	record.push_back(additional_context)
	
	if OS.is_debug_build():
		print("%s: Recorded run record for %s -> %s - total size is %d" % [name, context, ",".join(record), _run_record.size()])
	_prune()
	
	return true

func _prune() -> void:
	for key in _run_record.keys():
		if not instance_from_id(key):
			_run_record.erase(key)
			if OS.is_debug_build():
				print("%s: Pruned object with key %d - size is now %d" % [name, key, _run_record.size()])
	
