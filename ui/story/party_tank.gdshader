shader_type canvas_item;

uniform vec4 modulate: source_color = vec4(1.0,1.0,1.0,1.0);
uniform float speed: hint_range(0.1, 10.0, 0.01) = 1.0;

uniform vec2 jiggle_amount = vec2(5.0, 5.0);
uniform vec2 jiggle_speed = vec2(10.0, 10.0);

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
    // Horizontal jiggle (left-right)
    VERTEX.x += cos(TIME * jiggle_speed.x + VERTEX.y * 10.0) * jiggle_amount.x;

    // Vertical jiggle (up-down)
    VERTEX.y += sin(TIME * jiggle_speed.y + VERTEX.x * 10.0) * jiggle_amount.y;
}

void fragment() {
    // Time-based hue shift
    float hue = mod(TIME * speed, 1.0);

    vec4 base_color = texture(TEXTURE, UV) * modulate;

    // Convert hue to RGB
    vec4 party_color = vec4(hsv2rgb(vec3(hue, 1.0, 1.0)), 1.0);

    COLOR = base_color * party_color;
}
