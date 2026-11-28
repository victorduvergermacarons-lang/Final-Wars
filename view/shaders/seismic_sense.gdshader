// Seismic Sense (stance rework phase 4): the screen turns greyscale and white rings
// of light expand from the hero; colour comes back as it ends.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 0 = normal colours, 1 = fully greyscale.
uniform float grey = 0.0;
// The hero on screen (pixels) and the rings' radii so far (pixels; 0 = none).
uniform vec2 center = vec2(0.0);
uniform vec3 radii = vec3(0.0);
uniform float ring_width = 10.0;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l * 0.9), grey);
	float d = distance(FRAGCOORD.xy, center);
	float glow = 0.0;
	for (int i = 0; i < 3; i++) {
		float r = radii[i];
		if (r > 0.0) {
			glow = max(glow, 1.0 - smoothstep(0.0, ring_width, abs(d - r)));
		}
	}
	COLOR = vec4(mix(g, vec3(1.0), glow * 0.7 * grey), 1.0);
}
