class_name TypewriterEffect

const DEFAULT_SPEED:float = 0.15
const MAX_SPEED:float = 1.6
const MIN_SPEED:float = 0.016
const ACCELERATION:float = 0.88

## A timer that applies the TypewriterEffect and either loops or deletes itself when complete.
class TypewriterTextRevealer extends Timer:
	var speed: float = TypewriterEffect.DEFAULT_SPEED
	var repeat_after_fully_revealed:bool = false
	
	var node:
		set(value): return
		get: return get_parent()
	var visible_ratio:
		set(value): return
		get: return get_parent().visible_ratio
	var visible_characters:
		set(value): node.set_visible_characters(value)
		get: return node.visible_characters
		
	func _ready() -> void:
		if not "set_visible_characters" in get_parent():
			push_error("RevealTimer can only be used with valid TypewriterTextReveal node types.")
			queue_free()
		else:
			one_shot = true
			timeout.connect(cycle)
	func cycle() -> void:
		TypewriterEffect.on_reveal_timeout(self)

#region--Public Methods
func _init() -> void: push_error("Abstract class")

## Use this to apply the effect to a node.
static func apply_to(node:Control, speed:float = DEFAULT_SPEED) -> void:
	clear(node)
	if "set_visible_characters" in node:
		var new_timer = TypewriterTextRevealer.new()
		node.add_child(new_timer)
		new_timer.speed = speed
		new_timer.start(new_timer.speed)
	
static func clear(node:Control) -> void:
	node.set_visible_characters(0)
	
static func on_reveal_timeout(emitter:TypewriterTextRevealer) -> void:
	# Reveal one more character
	emitter.visible_characters = emitter.visible_characters + 1
	
	# Repeat or delete instance of revealer
	if emitter.visible_ratio >= 1.00:
		if emitter.repeat_after_fully_revealed:
			clear(emitter.node)
		else:
			emitter.queue_free()
			return
	# Accelerate
	emitter.start(clampf(emitter.wait_time * ACCELERATION, MIN_SPEED, MAX_SPEED))
#endregion
