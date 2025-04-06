shader_type canvas_item;

uniform float distortion_strength: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float noise_strength: hint_range(0.0, 1.0, 0.01) = 0.4;

uniform float wave_speed = 0.2;   // Speed of wave movement
uniform float wave_frequency = 41.0; // Frequency of waves
uniform float wave_pct = 0.025; // Top area of the rectangle to apply the wave effect
uniform float wave_agitation = 11.0;
uniform float wave_choppiness = 1.1;

// Make sure to use hint - "repeat_enable"
// so that noise texture repeats with scrolling
uniform bool enable_noise = true;
uniform sampler2D noise_tex1: repeat_enable;
uniform sampler2D noise_tex2: repeat_enable;
uniform vec2 offset1 = vec2(0.1);
uniform vec2 offset2 = vec2(0.04);

float wave_func_1(vec2 uv) {
	// Normalize to 0-1 range
	return (sin(uv.x * wave_frequency + TIME * wave_speed) + 1.0) * 0.5;
}

float wave_func_2(vec2 uv) {
	return (sin(uv.x * wave_frequency * PI + TIME * wave_speed * wave_agitation) + 1.0) * 0.5;
}

float wave_func_3(vec2 uv) {
	return (sin(uv.x * wave_frequency * wave_choppiness * PI/6.0 + TIME * wave_speed * PI/4.0) + 1.0) * 0.5;
}

void fragment() {
    vec2 uv = UV;
    vec4 color = texture(TEXTURE, uv);

	float wave_modifier = noise_strength;
    // Create the wave effect at the top of the rectangle
    if (uv.y <= wave_pct) {
        float wave_cutoff = (wave_func_1(uv) + wave_func_2(uv) + wave_func_3(uv)) / 3.0;
		float topness = (wave_pct - uv.y) / wave_pct;
		// Make transparent if above the cutoff
		if(topness > wave_cutoff) {
			color.a = wave_modifier = 0.0;
		}
	}

	if(enable_noise) {
		vec2 uv1 = uv + offset1 * TIME;
		vec2 uv2 = uv + offset2 * TIME;

		vec4 noise_color1 = texture(noise_tex1, uv1);
		vec4 noise_color2 = texture(noise_tex2, uv2);

		vec2 noise = vec2(noise_color1.r, noise_color2.r);
		float avg_noise = mix(noise.x, noise.y, 0.5);
		float color_noise = avg_noise * distortion_strength;

		color.rgb = mix(color.rgb, color.rgb * color_noise, noise_strength);
		color.a += avg_noise * wave_modifier;
	}

    COLOR = color;
}
