shader_type spatial;

uniform vec4 rubber : source_color = vec4(0.13, 0.18, 0.21, 1.0);
uniform vec4 enamel : source_color = vec4(0.89, 0.68, 0.31, 1.0);
varying vec2 deck;

void vertex() {
	deck = VERTEX.xz;
}

void fragment() {
	float r = length(deck);
	vec3 paint = mix(rubber.rgb, rubber.rgb * 1.45, smoothstep(1.0, 3.2, r));
	float track = 1.0 - smoothstep(0.21, 0.24, abs(abs(deck.y) - 0.88));
	paint *= 1.0 - track * (1.0 - smoothstep(2.5, 2.6, abs(deck.x))) * 0.38;
	float scale = atan(deck.y, deck.x + 0.0001);
	float ticks = smoothstep(0.72, 0.9, cos(scale * 48.0)) * smoothstep(3.27, 3.31, r);
	float major = smoothstep(0.94, 0.98, cos(scale * 12.0)) * smoothstep(3.06, 3.10, r);
	float rim = 1.0 - smoothstep(0.01, 0.027, abs(r - 3.48));
	float ink = max(rim, max(ticks, major) * (1.0 - smoothstep(3.45, 3.48, r)));
	ALBEDO = mix(paint, enamel.rgb, ink * 0.88);
	ROUGHNESS = 0.7;
}
