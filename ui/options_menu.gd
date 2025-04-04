extends Control

signal closed

@onready var configure_keybinds_button: Button = %ConfigureKeybindsButton
@onready var show_tooltips_toggle: CheckButton = %ShowTooltipsToggle
@onready var show_hud_toggle: CheckButton = %ShowHUDToggle
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider

func _ready() -> void:
	set_initial_states()

func set_initial_states() -> void:
	# Each option
	show_tooltips_toggle.set_pressed_no_signal(UserOptions.show_tooltips)
	show_hud_toggle.set_pressed_no_signal(UserOptions.show_hud)
	music_volume_slider.set_value_no_signal(UserOptions.volume_music)
	sfx_volume_slider.set_value_no_signal(UserOptions.volume_sfx)
	
func apply_changes() -> void:
	# Apply all options
	UserOptions.show_tooltips = show_tooltips_toggle.is_pressed()
	UserOptions.show_hud = show_hud_toggle.is_pressed()
	UserOptions.volume_music = music_volume_slider.value
	UserOptions.volume_sfx = sfx_volume_slider.value
	apply_volume_settings_to_audio_bus()
	
	# Emit signal
	GameEvents.user_options_changed.emit()
	
func apply_volume_settings_to_audio_bus() -> void:
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(UserOptions.volume_music))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(UserOptions.volume_sfx))
	
func close_options_menu() -> void:
	closed.emit()

func _on_apply_pressed() -> void:
	apply_changes()
	close_options_menu()

func _on_cancel_pressed() -> void:
	close_options_menu()
