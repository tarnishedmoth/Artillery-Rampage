class_name MathUtils

## Returns a random sign (-1.0 or 1.0)
static func randf_sgn() -> float:
	return signf(randf() - 0.5)

## Returns a random float in the range [min_value, max_value] and then multiplies it by a random sign (-1.0 or 1.0)
static func randf_range_signed(min_value: float, max_value: float) -> float:
	return randf_range(min_value, max_value) * randf_sgn()
