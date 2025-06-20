shader_type canvas_item;

const int discard_array_size = 8192 / 32;
// Packed index flags - 1 bit per vertex - if 1 then vertex is discarded and 0 otherwise
uniform int discarded_vertex_flags[discard_array_size]; // 256 * 32 vertices = 8192

varying float should_discard;

uniform float discard_threshold = 0.5;

bool is_discarded(int id) {
    int word = min(id / 32, discard_array_size - 1);
    int bit = id % 32;
    return (discarded_vertex_flags[word] & (1 << bit)) != 0;
}

void vertex() {
	// Doesn't work
	//if(is_discarded(VERTEX_ID)) {
		//// move out of clip space so it isn't rendered
		//VERTEX = vec2(1e12);
	//}
	should_discard = is_discarded(VERTEX_ID) ? 1.0 : 0.0;
}

void fragment() {
	if(should_discard >= discard_threshold) {
		discard;
	}
}