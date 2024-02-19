shader_type canvas_item;

uniform bool debug;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 rgba = texture(TEXTURE, UV);
	if (!debug && rgba.x == 1. && rgba.y == 0. && rgba.z == 0.)
		COLOR = vec4(0, 0, 0, 0);
	else
		COLOR = rgba;
}

void light() {
	// Called for every pixel for every light affecting the CanvasItem.
}
