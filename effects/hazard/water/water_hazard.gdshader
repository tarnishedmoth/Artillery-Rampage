shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float wave_speed = 2.0;   // Speed of wave movement
uniform float wave_frequency = 20.0; // Frequency of waves
uniform float wave_amplitude = 5.0; // Height of waves
uniform float wave_top = 0.05; // Top area of the rectangle to apply the wave effect

void fragment() {
    vec2 uv = UV;
    vec4 color = texture(TEXTURE, uv);

    // Create the wave effect at the top of the rectangle
    if (uv.y <= wave_top) {
		 // Ensure alpha is between 0 (fully transparent) and 1
        float wave = (sin(uv.x * wave_frequency + TIME * wave_speed) + 1.0) * 0.5; // Normalize to 0-1 range
        float wave_clamped = min(wave, color.a);
		float topness = (wave_top - uv.y) / wave_top;
		float wave_height = mix(color.a, wave_clamped, topness);
		color.a = wave_height;
	}
	
    COLOR = color;
}
