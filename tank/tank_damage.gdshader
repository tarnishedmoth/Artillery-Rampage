shader_type canvas_item;

uniform float flash_cycle_time = 1.0;
uniform float brightness_boost_factor: hint_range(1.0, 10.0) = 5.0;

global uniform float game_time;

// Could use instance uniform but these aren't supported by compatibility webgl mode
// See https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shading_language.html#per-instance-uniforms
// So instead we will duplicate the instance uniform on ready
uniform float start_time;

float brightness_alpha(float elapsed_time) {
	// Period is the lifetime and phase shift by PI / 2 so that clamped value goes 0 to 1 and back to 0 over interval
	return (sin((TAU * elapsed_time / flash_cycle_time) - PI * 0.5) * 0.5) + 0.5;
}

void fragment() {
	float elapsed_time = game_time - start_time;
	vec4 color = COLOR;

	float brightness_alpha = brightness_alpha(elapsed_time);
	color.rgb *= brightness_alpha * brightness_boost_factor;
	
	COLOR = color;
}
