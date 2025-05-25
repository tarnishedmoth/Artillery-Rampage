extends Node

var save_file:String
var save_path:String

var _save_ext:StringName
var _save_strategy: Callable
var _load_strategy: Callable

func _ready() -> void:

	# TODO: If save performance becomes an issue can switch to binary for release builds, but 
	# it will be easier to debug issues and less frustrating to end users if we just use text always
	if true: #OS.is_debug_build():
		_save_ext = &"json"
		_save_strategy = func() -> void: _save_as_text()
		_load_strategy = func() -> SaveState: return _load_as_text()
	else:
		_save_ext = &"bin"
		_save_strategy = func() -> void: _save_as_binary()
		_load_strategy = func() -> SaveState: return _load_as_binary()

	save_file = "game_state.%s" % [_save_ext]
	save_path = "user://%s" % [save_file]

	print_debug("save_path=%s/%s" % [OS.get_user_data_dir(), save_file])

	save_state = _load()
	if not save_state:
		save_state = SaveState.new()

var save_state:SaveState

var _flag_consumers:Dictionary[StringName, Dictionary] = {}


## Adds a flag that can be read in deserializers that need to ignore state in a certain context
# such as a new story mode
func add_state_flag(flag:StringName) -> void:
	_flag_consumers[flag] = {}

## Check if state flag currently set and schedule to remove it if found
func consume_state_flag(flag:StringName, consumer_key:StringName) -> bool:
	if flag in _flag_consumers:
		var flag_consumers: Dictionary = _flag_consumers[flag]
		if not consumer_key in flag_consumers:
			flag_consumers[consumer_key] = true
			return true
	return false
	
func reset_save() -> void:
	save_state = SaveState.new()
	_save()

func restore_node_state(node:Node, force_file_reload:bool = false) -> void:
	if not node or not node.is_in_group(Groups.Savable):
		push_error("%s: node=%s is not Savable" % [name, node])
		return
	
	_restore_state(func() -> Array[Node]:
		return [node],
	 SaveState.SaveContext.Node,
	 force_file_reload)

func restore_tree_state(force_file_reload:bool = false) -> void:
	_restore_state(func() -> Array[Node]:
		return get_tree().get_nodes_in_group(Groups.Savable),
	 SaveState.SaveContext.Tree,
	 force_file_reload)

func _restore_state(nodes_getter:Callable, context:SaveState.SaveContext, force_file_reload:bool = false) -> void:
	if force_file_reload and FileAccess.file_exists(save_path):
		save_state = _load()
	if not save_state.state:
		print_debug("No save state is available")
		return

	save_state.context = context

	for node in nodes_getter.call():
		node.restore_from_save_state(save_state)

	GameEvents.save_state_restored.emit()
	
func save_node_state(node:Node) -> void:
	if not node or not node.is_in_group(Groups.Savable):
		push_error("%s: node=%s is not Savable" % [name, node])
		return
	
	_save_state(func() -> Array[Node]: return [node], SaveState.SaveContext.Node)

func save_tree_state() -> void:
	_save_state(func() -> Array[Node]:
		return get_tree().get_nodes_in_group(Groups.Savable),
	SaveState.SaveContext.Tree)

func _save_state(nodes_getter:Callable, context:SaveState.SaveContext,) -> void:
	var nodes:Array[Node] = nodes_getter.call()
	if not nodes:
		return

	save_state.context = context	
	for node in nodes:
		node.update_save_state(save_state)
		
	_save()

	GameEvents.save_state_persisted.emit()

func clear_save_state_by_key(key:StringName) -> void:
	if not save_state or not save_state.state:
		print_debug("No save state is available")
		return
	
	if save_state.state.has(key):
		save_state.state.erase(key)
	_save()

func _save() -> void:
	_save_strategy.call()

func _load() -> SaveState:
	return _load_strategy.call()

#region Binary

func _save_as_binary() -> void:
	var bin_data:PackedByteArray = var_to_bytes(save_state.state)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(bin_data)
		file.flush()
		file.close()
	else:
		push_error("%s: Failed to open file %s for writing" % [name, save_path])

func _load_as_binary() -> SaveState:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_state_bytes:PackedByteArray = file.get_buffer(file.get_length())
		file.close()

		return _to_save_state(bytes_to_var(save_state_bytes) as Dictionary[StringName, Dictionary])
	else:
		push_error("%s: Failed to open file %s for reading" % [name, save_path])
		return null

#endregion


#region Text

func _save_as_text() -> void:
	var json:String = JSON.stringify(JSON.from_native(save_state.state, false))

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.flush()
		file.close()
	else:
		push_error("%s: Failed to open file %s for writing" % [name, save_path])

func _load_as_text() -> SaveState:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_state_str:String = file.get_as_text()
		file.close()

		var raw_json:Variant = JSON.parse_string(save_state_str)
		if not raw_json:
			push_error("%s: Failed to parse JSON from file %s" % [name, save_path])
			return null
		
		var data:Dictionary[StringName, Dictionary] = JSON.to_native(raw_json, false)
		
		return _to_save_state(data)
	else:
		push_error("%s: Failed to open file %s for reading" % [name, save_path])
		return null

#endregion

func _to_save_state(data: Dictionary[StringName, Dictionary]) -> SaveState:
	var save:SaveState = SaveState.new()
	save.state = data
	return save
