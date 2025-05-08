shader_type canvas_item;

uniform vec3 amount = vec3(1.0, 1.0, 1.0);
uniform float multiply = 1.25;
uniform float minimum = 0.0;
uniform float maximum = 1.15;

void fragment() {
	vec4 c = vec4(UV.y-1.0, UV.y-1.0, UV.y-1.0, -1.0)*-multiply;

	COLOR *= vec4(
		clamp(c.x*amount.r, minimum, maximum),
		clamp(c.y*amount.g, minimum, maximum),
		clamp(c.z*amount.b, minimum, maximum),
		1.0);
}