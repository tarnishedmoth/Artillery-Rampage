class_name Juice

const SNAP = 0.2
const SNAPPY = 0.3
const FAST = 0.45
const SMOOTH = 0.65
const PATIENT = 0.9
const SLOW = 1.5
const LONG = 3.5
const VERYLONG = 7.0

static func fade_in(node, speed:float = SNAPPY, from:Color = Color.TRANSPARENT) -> Tween:
	var tween = node.create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, speed).from(from)
	return tween
