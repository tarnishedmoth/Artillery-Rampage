extends Node

var save_file:String = "game_state.%s" % ["tres" if OS.is_debug_build() else "res" ]
var save_path:String = "user://%s" % [save_file]

func _ready() -> void:
	print_debug("save_path=%s/%s" % [OS.get_user_data_dir(), save_file])
	save_state = _load()
	if not save_state:
		save_state = SaveState.new()

var save_state:SaveState

func reset_save() -> void:
	save_state = SaveState.new()
	_save()

func restore_tree_state(force_file_reload:bool = false) -> void:
	if force_file_reload and ResourceLoader.exists(save_path):
		save_state = _load()
	if not save_state.state:
		print_debug("No save state is available")
		return
		
	for node in get_tree().get_nodes_in_group(Groups.Savable):
		node.restore_from_save_state(save_state)
	
	
func save_tree_state() -> void:
	
	var nodes:Array[Node] = get_tree().get_nodes_in_group(Groups.Savable)
	if not nodes:
		return
		
	for node in nodes:
		node.update_save_state(save_state)
		
	_save()

func _save() -> void:
	ResourceSaver.save(save_state, save_path)

func _load() -> SaveState:
	return load(save_path) as SaveState if ResourceLoader.exists(save_path) else null
