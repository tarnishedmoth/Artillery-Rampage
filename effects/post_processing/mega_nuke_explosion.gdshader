shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float start_time;
uniform float lifetime;
uniform float intensity : hint_range(0, 10) = 1.0;

uniform float flash_lifetime_frac = 0.1;

uniform vec4 flash_color: source_color = vec4(1.0);
uniform vec4 radiation_color: source_color;

float get_abberation_alpha(float elapsed_time) {
	// Period is the lifetime and phase shift by PI / 2 so that clamped value goes 0 to 1 and back to 0 over interval
	return (sin((TAU * elapsed_time / lifetime) - PI * 0.5) * 0.5) + 0.5;
}

float get_radiation_alpha(float elapsed_time) {
	// Period is the lifetime and phase shift by PI / 2 so that clamped value goes 0 to 1 and back to 0 over interval
	return (sin((TAU * elapsed_time / (lifetime * (1.0 - flash_lifetime_frac))) - PI * 0.5) * 0.5) + 0.5;
}

vec4 chromatic_abberation(vec2 screen_uv, float alpha) {
	float effective_intensity = alpha * intensity;
	
	// Offsets for RGB channels
    vec2 red_offset = vec2(effective_intensity * 0.001, 0.0);
    vec2 green_offset = vec2(0.0, -effective_intensity * 0.001);
    vec2 blue_offset = vec2(-effective_intensity * 0.001, effective_intensity * 0.001);

    // Sample the screen texture for each channel
    float r = texture(screen_texture, screen_uv + red_offset).r;
    float g = texture(screen_texture, screen_uv + green_offset).g;
    float b = texture(screen_texture, screen_uv + blue_offset).b;

    // Combine channels
    return vec4(r, g, b, 1.0);
}

void fragment() {
	float elapsed_time = TIME - start_time;
	float flash_time = lifetime * flash_lifetime_frac;
	float lifetime_frac = elapsed_time / lifetime;
	
	vec4 initial_color = texture(screen_texture, SCREEN_UV);
	vec4 final_color;
	
	if(elapsed_time <= flash_time) {
		final_color = mix(flash_color, initial_color, elapsed_time / flash_time);
	}
	else {
		final_color = mix(initial_color, radiation_color, get_radiation_alpha(elapsed_time - flash_time));
	}
	
	float abberation_alpha = get_abberation_alpha(elapsed_time);
    vec4 abberation_color = chromatic_abberation(SCREEN_UV, abberation_alpha);
	vec4 color = mix(final_color, abberation_color, abberation_alpha);
	
	COLOR = color;
}
