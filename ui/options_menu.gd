extends Control

signal closed

@onready var configure_keybinds_button: Button = %ConfigureKeybindsButton
@onready var show_tooltips_toggle: CheckButton = %ShowTooltipsToggle
@onready var show_hud_toggle: CheckButton = %ShowHUDToggle
@onready var show_trajectory_toggle: CheckButton = %ShowTrajectoryToggle

@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider

@onready var options: VBoxContainer = $Options
@onready var keybinds: PanelContainer = $Keybinds
@onready var keybind_labels: VBoxContainer = %KeybindLabels
@onready var keybind_glyphs: VBoxContainer = %KeybindGlyphs

var cached_music_volume: float
var cached_sfx_volume: float

func _ready() -> void:
	set_initial_states()
	options.show()
	keybinds.hide()

func set_initial_states() -> void:
	# Each option
	show_tooltips_toggle.set_pressed_no_signal(UserOptions.show_tooltips)
	show_hud_toggle.set_pressed_no_signal(UserOptions.show_hud)
	show_trajectory_toggle.set_pressed_no_signal(UserOptions.show_assist_trajectory_preview)
	
	music_volume_slider.set_value_no_signal(UserOptions.volume_music)
	sfx_volume_slider.set_value_no_signal(UserOptions.volume_sfx)
	
	cached_music_volume = music_volume_slider.value
	cached_sfx_volume = sfx_volume_slider.value
	
func apply_changes() -> void:
	# Apply all options
	UserOptions.show_tooltips = show_tooltips_toggle.is_pressed()
	UserOptions.show_hud = show_hud_toggle.is_pressed()
	UserOptions.show_assist_trajectory_preview = show_trajectory_toggle.is_pressed()
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
	
func reset_changed_cached_settings() -> void:
	apply_volume_settings_to_audio_bus()
	
func close_options_menu() -> void:
	closed.emit()

func _on_apply_pressed() -> void:
	apply_changes()
	close_options_menu()

func _on_cancel_pressed() -> void:
	reset_changed_cached_settings()
	close_options_menu()

func populate_keybinds_ui() -> void:
	## Clear old data
	for child in keybind_labels.get_children() + keybind_glyphs.get_children(): # Didn't know i could do this, cool
		child.queue_free()
	
	## Get all keybinds and display them
	var map: Array[StringName] = UserOptions.get_all_keybinds() # InputMap.get_actions()
	#print_debug(map)
	
	for action in map:
		# We're doing Glyph (right column) first in order to get its minimum size, to scale
		# the Label properly. Kind of a workaround, there's probably a way to set fixed size.
		
		## Glyph
		var inputs: Array[InputEvent] = InputMap.action_get_events(action)
		var text: String
		for input: InputEvent in inputs:
			if not text.is_empty(): text += ", " # Add a separator
			text += input.as_text()
			
		var glyph = Button.new()
		glyph.text = text
		glyph.pressed.connect(_on_keybinds_changing)
		keybind_glyphs.add_child(glyph)
		
		## Label
		var label = Label.new()
		label.text = action
		label.custom_minimum_size.y = glyph.get_combined_minimum_size().y
		keybind_labels.add_child(label)

func _on_configure_keybinds_button_pressed() -> void:
	populate_keybinds_ui()
	keybinds.show()
	
func _on_keybinds_changing(action: StringName) -> void:
	# TODO Show popup menu
	# Use value to set event
	# Pass a value from the button, not sure how at the moment
	print_debug(action)

func _on_keybinds_confirm_changes_pressed() -> void:
	# TODO apply changes
	keybinds.hide()

func _on_keybinds_cancel_pressed() -> void:
	keybinds.hide()

func _on_keybinds_reset_all_pressed() -> void:
	UserOptions.reset_all_keybinds_to_default()
	keybinds.hide()
	_on_configure_keybinds_button_pressed() # Reload


func _on_music_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var music_bus = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume_slider.value))


func _on_sfx_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var sfx_bus = AudioServer.get_bus_index("SFX")
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume_slider.value))
