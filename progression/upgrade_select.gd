extends Control

@onready var receive_upgrade_button: ButtonUpgradeSelection = %ReceiveUpgradeButton
@onready var continue_button:Button = %ContinueButton
@onready var current_upgrades_panel: PanelContainer = %CurrentUpgradesPanel
@onready var everything: MarginContainer = %Everything

func _ready() -> void:
	modulate = Color.BLACK
	#current_upgrades_panel.modulate = Color.TRANSPARENT
	current_upgrades_panel.hide()
	everything.modulate = Color.BLACK
	
	await Juice.fade_in(self, Juice.SMOOTH, Color.BLACK).finished
	Juice.fade_in(everything, Juice.PATIENT)
	
func _acquire_mod(button: ButtonUpgradeSelection) -> void:
	
	PlayerUpgrades.acquire_upgrade(button.get_mod_bundle())
	current_upgrades_panel.show()
	Juice.fade_out(receive_upgrade_button)
	Juice.fade_in(current_upgrades_panel)
	
	continue_button.disabled = false
	continue_button.grab_focus()


func _on_button_upgrade_random_selected(button: ButtonUpgradeSelection) -> void:
	_acquire_mod(button)
	
func _on_continue_button_pressed() -> void:
	Juice.fade_out(everything)
	if not SceneManager.deque_transition():
		SceneManager.switch_scene_keyed(SceneManager.SceneKeys.StoryShop)
