// Recolours a creature's sprite sheet (CreatureArtDef.recolor): each opaque,
// low-saturation pixel is replaced by a three-colour gradient picked by its
// brightness (dark -> mid -> light). Saturated pixels (flames, eyes) and
// semi-transparent ones (the drawn-in shadow, soft edges) keep their colour.
// Rendered once into an off-screen viewport per sheet (see WorldView), so it
// writes straight alpha without blending.
shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 dark_color : source_color = vec4(0.22, 0.03, 0.06, 1.0);
uniform vec4 mid_color : source_color = vec4(0.72, 0.13, 0.10, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.80, 0.32, 1.0);
// 0 = the original colours, 1 = fully recoloured.
uniform float strength = 1.0;
// Pixels at least this saturated keep their colour (fading out over 0.15).
uniform float keep_saturation_above = 0.45;
// Brightness that maps to mid_color, and how hard the gradient is stretched.
uniform float center = 0.4;
uniform float contrast = 1.8;
// Pixels less opaque than this keep their colour.
uniform float min_alpha = 0.8;

float saturation(vec3 c) {
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	return hi > 0.0 ? (hi - lo) / hi : 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < min_alpha) {
		COLOR = c;
	} else {
		float w = strength * (1.0 - smoothstep(keep_saturation_above, keep_saturation_above + 0.15, saturation(c.rgb)));
		float l = clamp((dot(c.rgb, vec3(0.299, 0.587, 0.114)) - center) * contrast + 0.5, 0.0, 1.0);
		vec3 g = l < 0.5 ? mix(dark_color.rgb, mid_color.rgb, l * 2.0) : mix(mid_color.rgb, light_color.rgb, (l - 0.5) * 2.0);
		COLOR = vec4(mix(c.rgb, g, w), c.a);
	}
}
