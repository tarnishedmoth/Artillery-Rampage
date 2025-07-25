extends XRToolsViewport2DIn3D

func _ready() -> void:
	viewport = InternalSceneRoot
	$StaticBody3D.viewport = viewport
	super()
