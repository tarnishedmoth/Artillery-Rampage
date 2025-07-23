class_name ProgramEntryXR extends Node3D

## Some parts adapted from XRTools Start XR Class
##
## This class supports both the OpenXR and WebXR interfaces, and handles
## the initialization of the interface as well as reporting when the user
## starts and ends the VR session.
##
## For OpenXR this class also supports passthrough on compatible devices such
## as the Meta Quest 1 and 2.


## This signal is emitted when XR becomes active. For OpenXR this corresponds
## with the 'openxr_focused_state' signal which occurs when the application
## starts receiving XR input, and for WebXR this corresponds with the
## 'session_started' signal.
signal xr_started

## This signal is emitted when XR ends. For OpenXR this corresponds with the
## 'openxr_visible_state' state which occurs when the application has lost
## XR input focus, and for WebXR this corresponds with the 'session_ended'
## signal.
signal xr_ended

var xr_interface: XRInterface

@export var program_entry_2d: PackedScene

# Input property group
@export_group("Input")
## Allow physical keyboard input to viewport
@export var input_keyboard : bool = true
## Allow gamepad input to viewport
@export var input_gamepad : bool = false

func _ready():
	#xr_interface = XRServer.find_interface("OpenXR")
	#if xr_interface and xr_interface.is_initialized():
		#print("OpenXR initialized successfully")
#
		## Turn off v-sync!
		#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
#
		## Change our main viewport to output to the HMD
		#get_viewport().use_xr = true
	#else:
		#print("OpenXR not initialized, please check if your headset is connected")
		#
	SceneManager.switch_scene(program_entry_2d)
	
func _input(event):
	# Map keyboard events to the viewport if enabled
	if input_keyboard and (event is InputEventKey or event is InputEventShortcut):
		InternalSceneRoot.push_input(event)
		return

	# Map gamepad events to the viewport if enable
	if input_gamepad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		InternalSceneRoot.push_input(event)
		return

func set_viewport(viewport: SubViewport) -> void:
	var nodepath: NodePath = get_path_to(viewport)
	#screen_material_texture.viewport_path = nodepath
	#screen_mesh.material_overlay = screen_material
