extends Label

func _ready() -> void:
	PlayerUpgrades.acquired_upgrade.connect(_on_acquired_upgrade.unbind(1))
	

func update() -> void:
	var upgrades = PlayerUpgrades.get_current_upgrades()
	var master_string:String = text
	
	for mod:ModBundle in upgrades:
		var new_txt:String
		for mod_weapon:ModWeapon in mod.components_weapon_mods:
			new_txt += mod_weapon.target_weapon_name
			new_txt += "\n"
			for mod_projectile:ModProjectile in mod_weapon.projectile_mods:
				new_txt += String(mod_projectile.get_property_key())
		master_string += new_txt
	
	text = master_string

func get_current_upgrades() -> String:
	return String()
	
func _on_acquired_upgrade() -> void:
	update()
