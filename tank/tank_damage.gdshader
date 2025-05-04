shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float flash_cycle_time = 1.0;
uniform float brightness_boost_factor: hint_range(1.0, 10.0) = 5.0;

uniform float glow_radius : hint_range(0.0, 1.0) = 0.1;
uniform float max_glow_strength : hint_range(0.0, 1.0) = 0.5;

global uniform float game_time;

// Could use instance uniform but these aren't supported by compatibility webgl mode
// See https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shading_language.html#per-instance-uniforms
// So instead we will duplicate the instance uniform on ready
uniform float start_time;

vec4 glow(vec2 screen_uv, float alpha) {

    // Sample neighboring pixels to create a "glow" effect
    vec4 color = texture(screen_texture, screen_uv);
    vec4 glow = vec4(0.0);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x) * glow_radius, float(y) * glow_radius);
            glow += texture(screen_texture, screen_uv + offset);
        }
    }

    glow /= 9.0; // Average the sampled pixels

    return mix(vec4(0.0), glow, max_glow_strength * alpha); // Adjust glow intensity
}

float brightness_alpha(float elapsed_time) {
	// Period is the lifetime and phase shift by PI / 2 so that clamped value goes 0 to 1 and back to 0 over interval
	return (sin((TAU * elapsed_time / flash_cycle_time) - PI * 0.5) * 0.5) + 0.5;
}

void fragment() {
	float elapsed_time = game_time - start_time;
	vec4 color = COLOR;
	//vec4 color = texture(screen_texture, UV);

	float brightness_alpha = brightness_alpha(elapsed_time);
	color.rgb *= brightness_alpha * brightness_boost_factor;
	//color += glow(UV, brightness_alpha);

	// color.rgb = clamp(color.rgb, 0.0, 1.0);
	// color.a = 1.0;
	COLOR = color;
}
