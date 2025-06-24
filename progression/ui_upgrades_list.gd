extends HFlowContainer

@export var scene:PackedScene ## Must Be PanelContainer!

func _ready() -> void:
	PlayerUpgrades.upgrades_changed.connect(_on_upgrades_changed)
	
	
func create_mod_display_panel(mod) -> ModDisplayPanel:
	if not scene:
		push_error("ModDisplayPanel scene not configured in export property.")
		return
	var display:ModDisplayPanel = scene.instantiate()
	display.mods.append(mod)
	return display


func update() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	
	var upgrades: Array[ModBundle] = PlayerUpgrades.get_current_upgrades()
	
	#var bundle_strings: PackedStringArray = []
	#for mod in upgrades:
		#bundle_strings.push_back(mod.to_string())
	#text = "\n".join(bundle_strings)
	
	for mod in upgrades:
		var display:ModDisplayPanel = create_mod_display_panel(mod)
		add_child(display)
		Juice.fade_in(display)
	
func _on_upgrades_changed() -> void:
	update()
