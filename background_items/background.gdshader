shader_type canvas_item;

uniform float speed: hint_range(-1000, 1000) = 0;

void vertex() {
	UV.x += TIME * speed;
}
