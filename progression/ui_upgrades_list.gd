extends Label

func _ready() -> void:
	PlayerUpgrades.acquired_upgrade.connect(_on_acquired_upgrade.unbind(1))
	

func update() -> void:
	var upgrades: Array[ModBundle] = PlayerUpgrades.get_current_upgrades()
	var bundle_strings: PackedStringArray = []
	
	for mod in upgrades:
		bundle_strings.push_back(mod.to_string())
	
	text = "\n".join(bundle_strings)

func get_current_upgrades() -> String:
	return String()
	
func _on_acquired_upgrade() -> void:
	update()
