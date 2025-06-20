shader_type canvas_item;

const int discard_array_size = 1024;
// Packed index flags - 1 bit per vertex - if 1 then vertex is discarded and 0 otherwise
uniform vec2 discarded_vertices[discard_array_size];

varying float should_discard;

uniform int discarded_count;

uniform float discard_threshold = 0.5;
uniform float discard_match_distance = 32;

bool is_discarded(vec2 vertex) {
	// TODO: This implementation is not great but binary search would be more complex and with hundreds of points or less it is not worth it
	float match_distance_squared = discard_match_distance * discard_match_distance;
	for(int i = 0, len = min(discarded_count, discard_array_size); i < len; i++) {
		vec2 discarded_vertex = discarded_vertices[i];
		float dx = discarded_vertex.x - vertex.x;
		float dy = discarded_vertex.y - vertex.y;
		float distance_squared = dx * dx + dy * dy;
		if(distance_squared <= match_distance_squared) {
			return true;
		}
	}
	return false;
}

void vertex() {
	should_discard = is_discarded(VERTEX) ? 1.0 : 0.0;
}

void fragment() {
	if(should_discard >= discard_threshold) {
		discard;
	}
}